#!/usr/bin/env bash
# End to end on kind: installs the nochaos chart (the whole community
# edition), signs in as the admin made by the first run, sends traffic with
# the services image's load generator through the ingest edge and reads every
# signal back through the API.
#
#   scripts/e2e.sh                # cluster nochaos-e2e, images from GHCR
#   IMAGES=local scripts/e2e.sh   # images built by make dev in a nochaos clone (oop/*:dev)
#   STREAM=1 scripts/e2e.sh       # also Kafka + Flink
#   KEEP=1 scripts/e2e.sh         # leave the cluster running
#   CHART=nochaos/nochaos scripts/e2e.sh  # a published chart (helm repo add nochaos first)
#   VERSION=0.1.0                 # with CHART: the chart version
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cluster=${CLUSTER:-nochaos-e2e} ns=${NAMESPACE:-nochaos} rel=${RELEASE:-nochaos}
app_port=${APP_PORT:-18180} ingest_port=${INGEST_PORT:-18318}
A="http://127.0.0.1:$app_port" C="$(mktemp)"
user=owner pass="e2e-$(openssl rand -hex 8)"
helm=${HELM:-helm}
fails=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
check() { local what=$1; shift; if "$@"; then pass "$what"; else fail "$what"; fi; }
eventually() { local what=$1 i; shift; for i in $(seq 1 "${TRIES:-120}"); do "$@" && { pass "$what"; return; }; sleep 5; done; fail "$what"; }
cleanup() {
  [ -n "${pf:-}" ] && kill "$pf" 2>/dev/null || true
  rm -f "$C"
  [ "${KEEP:-0}" = 1 ] || kind delete cluster --name "$cluster" >/dev/null 2>&1 || true
}
trap cleanup EXIT

kind get clusters | grep -qx "$cluster" || kind create cluster --name "$cluster" --wait 120s
kubectl config use-context "kind-$cluster" >/dev/null

sets=(--set "global.publicURL=$A" --set "global.ingestURL=http://127.0.0.1:$ingest_port"
  --set platform.admin.organization=E2E --set platform.admin.email=admin@example.com
  --set "platform.admin.username=$user" --set "platform.admin.password=$pass"
  --set platform.prober.allowPrivateTargets=true)
if [ "${IMAGES:-}" = local ]; then
  for i in services portal flink-jobs; do
    docker image inspect "oop/$i:dev" >/dev/null 2>&1 || { [ "$i" = flink-jobs ] && [ "${STREAM:-0}" != 1 ]; } || { echo "e2e: oop/$i:dev missing (make dev in nochaos builds it)" >&2; exit 1; }
    if docker image inspect "oop/$i:dev" >/dev/null 2>&1; then
      docker tag "oop/$i:dev" "nochaos-e2e/$i:local"
      kind load docker-image --name "$cluster" "nochaos-e2e/$i:local" >/dev/null
    fi
  done
  sets+=(--set platform.image.services.repository=nochaos-e2e/services --set platform.image.services.tag=local
    --set platform.image.portal.repository=nochaos-e2e/portal --set platform.image.portal.tag=local
    --set platform.image.pullPolicy=Never
    --set stream.flink.image.repository=nochaos-e2e/flink-jobs --set stream.flink.image.tag=local --set stream.flink.pullPolicy=Never)
fi
[ "${STREAM:-0}" = 1 ] && sets+=(--set global.stream.enabled=true)

echo "== install"
chart=${CHART:-$root/charts/nochaos}
if [ -z "${CHART:-}" ]; then $helm dependency build "$chart" >/dev/null; else $helm repo update >/dev/null; fi
echo "   chart: $chart${VERSION:+ $VERSION}"
start=$SECONDS
$helm upgrade --install "$rel" "$chart" ${VERSION:+--version "$VERSION"} -n "$ns" --create-namespace --wait --timeout 20m "${sets[@]}"
echo "   installed in $((SECONDS - start))s"
kubectl -n "$ns" get pods

kubectl -n "$ns" port-forward "svc/$rel-edge" "$app_port:8080" "$ingest_port:4318" >/dev/null 2>&1 &
pf=$!
for _ in $(seq 1 30); do curl -fs "$A/healthz" >/dev/null 2>&1 && break; sleep 1; done

api() { curl -fsS -b "$C" -c "$C" -H 'Content-Type: application/json' "$@"; }
code() { curl -s -o /dev/null -w '%{http_code}' -b "$C" "$A$1"; }

echo "== first run and sign-in"
check "community edition" [ "$(curl -fsS "$A/api/setup" | jq -r .edition)" = community ]
check "first run done by ADMIN_* (no setup screen)" [ "$(curl -fsS "$A/api/setup" | jq -r .required)" = false ]
check "admin signs in" api -X POST -d "{\"login\":\"$user\",\"password\":\"$pass\"}" "$A/api/auth/login" -o /dev/null
eventually "organization active (every store answers)" [ "$(api "$A/api/me" | jq -r .tenant.status)" = active ]
check "portal served" [ "$(code /)" = 200 ]
check "Grafana and Jaeger through the API proxy" [ "$(code /grafana/api/health)$(code /jaeger/)" = 200200 ]
key=$(api -X POST -d '{"environment":"production"}' "$A/api/tokens" | jq -r .plain)
check "API key created" [ -n "$key" ]

echo "== ingest"
I="http://127.0.0.1:$ingest_port"
check "ingest without a key -> 401" [ "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d '{}' "$I/v1/traces")" = 401 ]
check "ingest with the key -> 200" [ "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "Authorization: Bearer $key" -H 'Content-Type: application/json' -d '{"resourceSpans":[]}' "$I/v1/traces")" = 200 ]
kubectl -n "$ns" delete job e2e-loadgen --ignore-not-found >/dev/null
img=$(kubectl -n "$ns" get deploy "$rel-api" -o jsonpath='{.spec.template.spec.containers[0].image}')
kubectl -n "$ns" create job e2e-loadgen --image="$img" -- /usr/local/bin/loadgen \
  "-endpoint=http://$rel-edge:4318" "-tokens=$key" -rps=2 -traces=6 -duration=4m -incidents -infra -events=true -rum=2 >/dev/null

echo "== read back"
eventually "traces searchable" [ "$(api "$A/api/traces/services" | jq 'length')" -gt 0 ]
eventually "RED metrics from spans (spanmetrics, 60 s flush)" [ "$(api "$A/api/red/services?range=15m" | jq '[.services[]?] | length')" -gt 0 ]
eventually "hosts (infrastructure metrics)" [ "$(api "$A/api/infra/hosts" | jq 'length')" -gt 0 ]
eventually "events in ClickHouse" [ "$(api "$A/api/events/search?range=15m" | jq 'length')" -gt 0 ]
eventually "browser sessions (rum-collector, Garage)" [ "$(api "$A/api/sessions?range=15m" | jq '.total')" -gt 0 ]
check "log patterns answer" [ "$(code /api/logs/patterns)" = 200 ]
for p in /api/red/overview /api/servicegraph /api/alerts /api/slos /api/rum/overview /api/environments /api/tokens; do
  c=$(code "$p"); [ "$c" = 200 ] && pass "$p 200" || fail "$p $c"
done
health=$(api "$A/api/health" | jq -c '[.components[] | select(.status != "ok" and .status != "up") | .component]')
check "every component up ($health)" [ "$health" = "[]" ]
if [ "${STREAM:-0}" = 1 ]; then
  echo "== stream"
  eventually "Flink runs the community jobs" [ "$(kubectl -n "$ns" exec "$rel-flink-0" -c jobmanager -- curl -fs localhost:8081/jobs/overview | jq '[.jobs[] | select(.state == "RUNNING")] | length')" -ge 5 ]
fi

echo
[ "$fails" = 0 ] && echo "e2e: every check passed" || { echo "e2e: $fails check(s) failed"; exit 1; }
