# Tools

The open-source software nochaos is built on. nochaos is a layer above these
tools. This table is generated from [tools/catalog.yaml](tools/catalog.yaml):
edit the catalog and run `scripts/check.py --write`.

| Tool | What it does for nochaos | License | Version | Profiles | Used by |
|---|---|---|---|---|---|
| [VictoriaMetrics](https://victoriametrics.com) | Metrics store (PromQL and MetricsQL) | Apache-2.0 | 1.154.0 | ha, cloud | metrics, apm, infrastructure, slo, anomalies, dashboards, alerts |
| [VictoriaLogs](https://docs.victoriametrics.com/victorialogs/) | Logs store (LogsQL) | Apache-2.0 | 1.53.0 | ha, cloud | logs, anomalies, dashboards, alerts |
| [VictoriaTraces](https://docs.victoriametrics.com/victoriatraces/) | Traces store (Jaeger query API) | Apache-2.0 | 0.12.0 | ha, cloud | apm, llm |
| [ClickHouse](https://clickhouse.com) | Business events store; the single store of the single-machine profile | Apache-2.0 | 26.3 | single, ha, cloud | events, analytics, dashboards, alerts |
| [PostgreSQL](https://www.postgresql.org) | The platform's database (accounts, configuration, plugin state) | PostgreSQL | 18.6 | single, ha, cloud | platform, incidents, catalog, synthetics, rum, deployments |
| [Redis](https://redis.io) | Sessions, quotas and live rates | RSALv2 / SSPLv1 / AGPL-3.0 | 8 | ha, cloud | platform |
| [Apache Kafka](https://kafka.apache.org) | Ingestion queue between the gateways and the stores | Apache-2.0 | 4.3.1 | cloud | platform, flow |
| [Apache Flink](https://flink.apache.org) | Stream aggregation (usage, quotas, SLOs, log patterns, service graph) | Apache-2.0 | 2.2.1 | cloud | apm, logs, slo, deployments, schema, flow |
| [OpenTelemetry Collector (contrib)](https://opentelemetry.io/docs/collector/) | OTLP gateways, span metrics, Kafka consumers | Apache-2.0 | 0.162.0 | single, ha, cloud | platform, apm, infrastructure |
| [Vector](https://vector.dev) | Gateway of business events | MPL-2.0 | 0.59.0 | ha, cloud | events |
| [Envoy](https://www.envoyproxy.io) | The edge of ingestion and of the portal (TLS, rate limits, external authorization) | Apache-2.0 | 1.40.0 | ha, cloud | platform |
| [Grafana](https://grafana.com/oss/grafana/) | Embedded explorers and dashboards next to the native ones | AGPL-3.0 | 13.2.5 | single, ha, cloud | dashboards, logs, metrics |
| [Jaeger UI](https://www.jaegertracing.io) | Embedded trace viewer | Apache-2.0 |  | ha, cloud | apm |
| [Garage](https://garagehq.deuxfleurs.fr) | S3-compatible object store for session recordings | AGPL-3.0 | 2.4.1 | ha, cloud | replay |
| [flagd (OpenFeature)](https://flagd.dev) | Feature flags per account (module.<plugin id>) | Apache-2.0 | 0.17.0 | ha, cloud | platform |
| [rrweb](https://www.rrweb.io) | Records and replays browser sessions | MIT | 2.2 | single, ha, cloud | replay |
| [uPlot](https://github.com/leeoniya/uPlot) | Charts of the portal | MIT | 1.6 | single, ha, cloud | platform |
| [React](https://react.dev) | The portal | MIT | 19 | single, ha, cloud | platform |
