# Profile: single

One machine, low volume. The profile most people should start with.

## Shape

```
one binary (platform + plugins, every component in one process)
  + ClickHouse   metrics, logs, traces and events in one store
  + PostgreSQL   accounts, configuration, plugin state
  + local disk   session recordings
```

No Kafka, no Flink, no per-tenant routing: one account, no billing.

## What the platform needs first

This profile is planned, not shipped. It depends on work in the platform:

| Needed | Why |
|---|---|
| A single-process mode (every component in one binary) | Today the platform is several services |
| An in-memory ingestion queue | Today ingestion goes through Kafka |
| ClickHouse as the store of every signal | Exists as a separate edition; it has to become a driver of the platform |
| In-process aggregation | Usage, SLOs, log patterns and the service graph run on Flink today |
| A single-account mode | Today every install is multi-tenant |

## Sizing

Not measured yet. Sizing will be published with a load test, never as a guess.
