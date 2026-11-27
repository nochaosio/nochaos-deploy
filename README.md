# nochaos Helm charts

Helm charts for the **nochaos community edition**: the open source,
self-hosted observability platform from [nochaos](https://github.com/nochaosio/nochaos).
One installation serves one organization, with the admin made on the first run, and one fixed set of stores. No sign-up, plans or billing: those
belong to the managed service and are not in these charts.

## Usage

[Helm](https://helm.sh) 3.8 or newer must be installed.

```sh
helm repo add nochaos https://nochaosio.github.io/nochaos-helm-charts
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

## Charts

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

## What runs

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

## Modules

Every product module can be switched off with `platform.modules.<name>=false`:
the portal hides it (flagd) and its workload is not started. `alerts` runs
the alerter, `synthetics` the prober, `mcp` the MCP server, `rum`/`replay`
the RUM collector and Garage, `events` the events gateway.

## Production notes

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

## Development

```sh
scripts/check.sh                 # lint and render every chart with its ci/ values
IMAGES=local scripts/e2e.sh      # kind: install, first run, traffic, every signal read back
IMAGES=local STREAM=1 scripts/e2e.sh
```

`IMAGES=local` uses the images `make dev` builds in a nochaos clone
(`oop/services:dev`, `oop/portal:dev`, `oop/flink-jobs:dev`).

Releases: bump the chart's `version` in `Chart.yaml`; merging to `main`
publishes it (chart-releaser, GitHub Pages).

## License

[Apache 2.0](LICENSE)
