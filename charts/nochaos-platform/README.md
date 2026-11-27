# nochaos-platform

The nochaos community edition platform: API, portal, the ingestion edge
(Envoy with authz checking every request), the telemetry pipeline
(OpenTelemetry Collector with RED metrics from spans), the events gateway
(Vector), tenant-router, alerter, prober, MCP server and RUM collector, with
PostgreSQL, Redis, Garage (S3), flagd and Mailpit.

It needs the stores: install [nochaos-stores](../nochaos-stores) with the same
prefix, or point `stores.*` at your own URLs. Most installs use the
[nochaos](../nochaos) chart, which brings both.

## Main values

| Key | Default | Description |
|---|---|---|
| `publicURL`, `ingestURL` | localhost | Portal and ingest URLs (`global.*` wins) |
| `image.services`, `image.portal` | `ghcr.io/nochaosio/nochaos/*`, appVersion | The nochaos images |
| `modules.<name>` | all on but `flow` | Product modules; off hides it and stops its workload |
| `stores.<store>` | `auto` | `auto`: `<prefix>-<store>`; empty: left out; else a URL |
| `admin.email`, `admin.username`, `admin.password` | empty | Headless first run; empty: the portal asks on the first visit |
| `secrets.existingSecret` | empty | Your own Secret instead of the generated one |
| `guards.rateLimitRPS` | `1000` | Ingestion requests per second per organization |
| `edge.service.type` | `ClusterIP` | `LoadBalancer` or `NodePort` to expose ports 8080 and 4318 |
| `edge.trustedHops` | `0` | Proxies in front that append to X-Forwarded-For |
| `ingress.enabled` | `false` | Ingress with the app and ingest hosts |
| `postgresql.enabled` / `externalDatabase.url` | bundled | PostgreSQL |
| `redis.enabled` / `externalRedis.*` | bundled | Redis |
| `garage.enabled` / `externalS3.*` | bundled | S3 for session recordings |
| `smtp.*` | Mailpit | SMTP relay for invitations, resets and alert e-mails |
| `stream.enabled` | `false` | Also produce to Kafka (needs nochaos-stream) |

Every value with comments: [values.yaml](values.yaml).
