# nochaos-deploy

How to run **nochaos**: the Helm charts of the community edition, the
installation profiles, and the catalog of the open-source tools it is built on.

## Software on one side, machines on the other

nochaos keeps a strict line:

- **The software** (the platform and its plugins) does not know where it
  runs. It is the same code on a laptop and on a large cluster. It lives in
  `nochaos` (plugins included, in `apps/services/plugins`).
- **The topology** (how many machines, which tools, how they are wired) lives
  here. This repository holds recipes and no product code: it only consumes
  released versions of the software.

So improving the product and scaling an installation are separate jobs that
do not block each other.

## Profiles

| Profile | For | How it runs | Status |
|---|---|---|---|
| [`single`](profiles/single) | One person or a small team, low volume | One machine, Docker Compose, few tools | planned |
| [`ha`](profiles/ha) | A company self-hosting at volume | Kubernetes, the [Helm charts](#helm-charts) below | charts published, e2e pending |
| cloud | The managed service | Operated by the nochaos team | not in this repository |

## Helm charts

The **community edition** on Kubernetes: one installation serves one
organization, with the admin made on the first run, and one fixed set of
stores. No sign-up, plans or billing: those belong to the managed service and
are not in these charts. [Helm](https://helm.sh) 3.8 or newer.

```sh
helm repo add nochaos https://nochaosio.github.io/nochaos-deploy
helm repo update
helm search repo nochaos
```

The whole community edition in one release:

```sh
helm install nochaos nochaos/nochaos -n nochaos --create-namespace
kubectl -n nochaos port-forward svc/nochaos-edge 8080:8080 4318:4318
```

Open http://localhost:8080. The first visit asks for the organization and its
admin. Then create an API key in Settings and send OTLP to
`http://localhost:4318` with `Authorization: Bearer <key>`.

| Chart | What it runs |
|---|---|
| [nochaos](charts/nochaos) | Everything below in one release |
| [nochaos-platform](charts/nochaos-platform) | API, portal, ingestion edge (Envoy + authz), telemetry pipeline (OpenTelemetry Collector), events gateway (Vector), tenant-router, alerter, prober, MCP server, RUM collector, flagd, PostgreSQL, Redis, Garage, Mailpit |
| [nochaos-stores](charts/nochaos-stores) | VictoriaMetrics, VictoriaLogs, VictoriaTraces, ClickHouse, Grafana, Jaeger UI |
| [nochaos-stream](charts/nochaos-stream) | Kafka and a Flink session cluster with the nochaos jobs (optional) |

The charts find each other by name: every object is `<prefix>-<component>`,
where the prefix is the release name (or `global.prefix`). Installing them
separately works the same way when the releases share the prefix and the
namespace:

```sh
helm install nochaos nochaos/nochaos-stores -n nochaos
helm install nochaos-app nochaos/nochaos-platform -n nochaos --set global.prefix=nochaos
```

### What runs

```
             :8080 portal + API             :4318 OTLP HTTP/gRPC, events, RUM
                    |                                  |
                    +------------- edge (Envoy) -------+---- authz (API keys, rate limit)
                    |                                  |
          portal, api, mcp            pipeline (OTel Collector, RED metrics), events-gw, rum-collector
                    |                                  |
     PostgreSQL, Redis, flagd, Garage           tenant-router
                    |                                  |
                    +---- metrics, logs, traces, events (ClickHouse), Grafana, Jaeger UI
                                               |
                          optional: Kafka -> Flink (usage, trace analytics, log patterns, schema drift)
```

### Modules

Every product module can be switched off with `platform.modules.<name>=false`:
the portal hides it (flagd) and its workload is not started. `alerts` runs
the alerter, `synthetics` the prober, `mcp` the MCP server, `rum`/`replay`
the RUM collector and Garage, `events` the events gateway.

### Production notes

- Set `global.publicURL` and `global.ingestURL` to the URLs people use, and
  `platform.ingress.enabled=true` with two hosts (portal and ingest). Behind
  an ingress controller set `platform.edge.trustedHops=1`.
- Point `platform.smtp.*` at a real relay; without it e-mails stay in Mailpit.
- Secrets (database, Redis, notification key, S3 keys) are generated on
  install and kept on upgrades, in `<prefix>-secrets` (kept on uninstall).
- External PostgreSQL, Redis and S3: `platform.postgresql.enabled=false` with
  `platform.externalDatabase.url`, and the same for `redis` and `garage`.
- Grafana installs its datasource plugins and the Jaeger UI downloads its
  assets on start: both need egress to grafana.com and github.com.

## Capabilities

A profile does not run every tool, so it does not offer everything. Each
installation tells the platform which **capabilities** it has, and each plugin
declares the ones it needs. A plugin whose capabilities are missing shows as
unavailable in that installation, with the reason, instead of failing.

| Capability | Provided by | single | ha | cloud |
|---|---|---|---|---|
| `metrics-store` | VictoriaMetrics, or ClickHouse in `single` | yes | yes | yes |
| `logs-store` | VictoriaLogs, or ClickHouse in `single` | yes | yes | yes |
| `traces-store` | VictoriaTraces, or ClickHouse in `single` | yes | yes | yes |
| `events-store` | ClickHouse | yes | yes | yes |
| `object-store` | Garage or any S3, or local disk in `single` | yes | yes | yes |
| `stream-aggregation` | Apache Flink, or in-process aggregation in `single` | partial | optional | yes |
| `internet-egress` | The network (the platform can reach the internet) | operator's choice | operator's choice | yes |

"partial" is the honest word for `single`: aggregations that need Flink today
(usage, quotas, SLOs, log patterns, the service graph) need an in-process
version before they work there.

## Tools

nochaos is a layer above open-source tools, and says which. The full list,
with licenses, versions and which plugins use each one: **[TOOLS.md](TOOLS.md)**
(generated from [tools/catalog.yaml](tools/catalog.yaml)).

## Development

```sh
pip install pyyaml
scripts/check.py                 # the tool catalog is valid and TOOLS.md is up to date
scripts/check.py --write         # regenerate TOOLS.md after editing tools/catalog.yaml
scripts/check.sh                 # lint and render every chart with its ci/ values
IMAGES=local scripts/e2e.sh      # kind: install, first run, traffic, every signal read back
IMAGES=local STREAM=1 scripts/e2e.sh
CHART=nochaos/nochaos IMAGES=local scripts/e2e.sh   # the same, with the published chart
```

`IMAGES=local` uses the images `make dev` builds in a nochaos clone
(`oop/services:dev`, `oop/portal:dev`, `oop/flink-jobs:dev`).

Releases: bump the chart's `version` in `Chart.yaml`; merging to `main`
publishes it (chart-releaser, GitHub Pages).

## License

Apache-2.0.
