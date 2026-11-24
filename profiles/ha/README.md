# Profile: ha

Self-hosted at volume: Kubernetes, each component scaled on its own.

## Shape

```
edge (Envoy) -> gateways (OpenTelemetry Collector, Vector) -> [Kafka, optional] -> stores
platform components as separate deployments (api, ingest, alerter, router)
VictoriaMetrics, VictoriaLogs, VictoriaTraces, ClickHouse, PostgreSQL, Redis, Garage
```

## Status

Planned. The Helm chart lands here once the platform can run each component
as its own process from released images, with the tools of
[TOOLS.md](../../TOOLS.md) at the listed versions.
