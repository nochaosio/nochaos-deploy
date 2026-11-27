# nochaos-stores

The fixed stores of a nochaos community installation:

| Component | Store | Port |
|---|---|---|
| `<prefix>-metrics` | VictoriaMetrics | 8428 |
| `<prefix>-logs` | VictoriaLogs | 9428 |
| `<prefix>-traces` | VictoriaTraces (with the service graph task) | 10428 |
| `<prefix>-events` | ClickHouse (business events) | 8123 |
| `<prefix>-grafana` | Grafana behind the platform's auth proxy, datasources provisioned | 3000 |
| `<prefix>-jaeger` | Jaeger UI over VictoriaTraces | 8080 |

Each one can be switched off (`<store>.enabled=false`) and has its own
retention, persistence and resources. Every value: [values.yaml](values.yaml).
