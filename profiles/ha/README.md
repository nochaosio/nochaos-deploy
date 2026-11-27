# Profile: ha

Self-hosted at volume: Kubernetes, each component scaled on its own.

## Shape

```
edge (Envoy) -> gateways (OpenTelemetry Collector, Vector) -> [Kafka, optional] -> stores
platform components as separate deployments (api, ingest, alerter, router)
VictoriaMetrics, VictoriaLogs, VictoriaTraces, ClickHouse, PostgreSQL, Redis, Garage
```

## How to install

With the Helm charts in [charts/](../../charts), published at
`https://nochaosio.github.io/nochaos-deploy` (see the
[README](../../README.md#helm-charts)). The tools run at the versions of
[TOOLS.md](../../TOOLS.md).

## Status

Charts published. The end-to-end run on kind and the public nochaos images
are still pending (see the open issues).
