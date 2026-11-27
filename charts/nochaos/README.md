# nochaos

The whole nochaos community edition in one release:
[nochaos-platform](../nochaos-platform), [nochaos-stores](../nochaos-stores)
and, with `global.stream.enabled=true`, [nochaos-stream](../nochaos-stream).

```sh
helm install nochaos nochaos/nochaos -n nochaos --create-namespace \
  --set global.publicURL=https://nochaos.example.com \
  --set global.ingestURL=https://ingest.nochaos.example.com \
  --set platform.ingress.enabled=true \
  --set platform.ingress.app.host=nochaos.example.com \
  --set platform.ingress.ingest.host=ingest.nochaos.example.com \
  --set platform.edge.trustedHops=1
```

## Values

| Key | Default | Description |
|---|---|---|
| `global.prefix` | release name | Prefix of every object name |
| `global.publicURL` | `http://localhost:8080` | Where people open the portal |
| `global.ingestURL` | `http://localhost:4318` | Where SDKs and agents send OTLP |
| `global.imageRegistry` | `""` | Registry mirror prepended to every image |
| `global.storageClass` | `""` | StorageClass of every volume |
| `global.stream.enabled` | `false` | Kafka and Flink (about 4 GiB of memory more) |
| `platform.*` | | [nochaos-platform values](../nochaos-platform/values.yaml) |
| `stores.*` | | [nochaos-stores values](../nochaos-stores/values.yaml) |
| `stream.*` | | [nochaos-stream values](../nochaos-stream/values.yaml) |

A store switched off in `stores` must also be left out of the platform:
`--set stores.events.enabled=false --set platform.stores.events=""`.
