{{/* The gateway and consumer collectors of the cloud in one collector, writing through tenant-router. */}}
{{- define "platform.pipelineConfig" -}}
{{- $p := include "platform.prefix" . -}}
{{- $kafka := include "platform.kafkaBrokers" . -}}
receivers:
  otlp:
    protocols:
      grpc: {endpoint: 0.0.0.0:4317, include_metadata: true, max_recv_msg_size_mib: 4}
      http: {endpoint: 0.0.0.0:4318, include_metadata: true, max_request_body_size: 4194304}
processors:
  memory_limiter: {check_interval: 1s, limit_percentage: 80, spike_limit_percentage: 20}
  resource/tenant:
    attributes:
      - {key: tenant.id, from_context: metadata.x-tenant-id, action: upsert}
      - {key: deployment.environment.name, from_context: metadata.x-oop-env, action: upsert}
  batch:
    send_batch_size: 2048
    timeout: 2s
    metadata_keys: [x-tenant-id]
    metadata_cardinality_limit: 2000
  batch/red: {send_batch_size: 4096, timeout: 5s}
  # A "level" field from severity_text or severity_number, read by Grafana's
  # log explorer and the dashboards' query language.
  transform/level:
    error_mode: ignore
    log_statements:
      - context: log
        statements:
          - set(log.attributes["level"], ConvertCase(log.severity_text, "lower")) where log.attributes["level"] == nil and log.severity_text != ""
          - set(log.attributes["level"], "trace") where log.attributes["level"] == nil and log.severity_number >= 1 and log.severity_number <= 4
          - set(log.attributes["level"], "debug") where log.attributes["level"] == nil and log.severity_number >= 5 and log.severity_number <= 8
          - set(log.attributes["level"], "info") where log.attributes["level"] == nil and log.severity_number >= 9 and log.severity_number <= 12
          - set(log.attributes["level"], "warn") where log.attributes["level"] == nil and log.severity_number >= 13 and log.severity_number <= 16
          - set(log.attributes["level"], "error") where log.attributes["level"] == nil and log.severity_number >= 17 and log.severity_number <= 20
          - set(log.attributes["level"], "fatal") where log.attributes["level"] == nil and log.severity_number >= 21
  transform/red:
    metric_statements:
      - context: resource
        statements:
          - keep_keys(attributes, ["tenant.id", "deployment.environment.name"])
connectors:
  # RED metrics from spans: delta exponential histograms flushed once a
  # minute, the resolution of the metrics store (-dedup.minScrapeInterval).
  spanmetrics:
    histogram:
      unit: ms
      exponential: {max_size: 160}
    dimensions: []
    exclude_dimensions: []
    resource_metrics_key_attributes: [service.name, deployment.environment.name, tenant.id]
    add_resource_attributes: true
    aggregation_temporality: AGGREGATION_TEMPORALITY_DELTA
    metrics_flush_interval: 60s
    metrics_expiration: 10m
    aggregation_cardinality_limit: 50000
    namespace: oop.red
exporters:
  otlphttp/router:
    endpoint: http://{{ $p }}-tenant-router:4318
    compression: none
    encoding: proto
    auth: {authenticator: headers_setter}
    retry_on_failure: {enabled: true, max_elapsed_time: 5m}
  otlphttp/red:
    endpoint: http://{{ $p }}-tenant-router:4318
    compression: none
    encoding: proto
    retry_on_failure: {enabled: true, max_elapsed_time: 5m}
  {{- if (include "platform.streamOn" .) }}
  {{- range $s := list "traces" "metrics" "logs" }}
  kafka/{{ $s }}:
    brokers: [{{ $kafka }}]
    include_metadata_keys: [x-tenant-id]
    {{ $s }}: {topic: otlp.{{ $s }}, encoding: otlp_proto, message_key_from_metadata_key: x-tenant-id}
    producer: {compression: zstd, required_acks: -1, max_message_bytes: 8388608}
    sending_queue: {enabled: true, queue_size: 1000}
  {{- end }}
  {{- end }}
extensions:
  health_check: {endpoint: 0.0.0.0:13133}
  headers_setter:
    headers:
      - {key: x-tenant-id, from_context: x-tenant-id, action: upsert}
service:
  extensions: [health_check, headers_setter]
  telemetry:
    logs: {level: warn}
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resource/tenant, batch]
      exporters: [otlphttp/router, spanmetrics{{ if (include "platform.streamOn" .) }}, kafka/traces{{ end }}]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, resource/tenant, batch]
      exporters: [otlphttp/router{{ if (include "platform.streamOn" .) }}, kafka/metrics{{ end }}]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, resource/tenant, transform/level, batch]
      exporters: [otlphttp/router{{ if (include "platform.streamOn" .) }}, kafka/logs{{ end }}]
    metrics/red:
      receivers: [spanmetrics]
      processors: [memory_limiter, transform/red, batch/red]
      exporters: [otlphttp/red]
{{- end -}}

{{/* Vector: shapes business events for ClickHouse, writing through tenant-router. */}}
{{- define "platform.eventsConfig" -}}
api: {enabled: true, address: "0.0.0.0:8686"}
sources:
  http:
    type: http_server
    address: 0.0.0.0:8080
    path: /v1/events
    strict_path: true
    method: POST
    headers: [x-tenant-id, x-oop-env]
    framing: {method: newline_delimited}
    decoding: {codec: json}
transforms:
  shape:
    type: remap
    inputs: [http]
    drop_on_abort: true
    source: |
      tenant = string(."x-tenant-id") ?? ""
      if !match(tenant, r'^[a-z][a-z0-9]{7}$') { abort }
      env = string(."x-oop-env") ?? "production"
      ts = .timestamp
      del(."x-tenant-id"); del(."x-oop-env"); del(.path); del(.source_type); del(.timestamp)
      etype = string(.event_type) ?? string(.type) ?? "event"
      if length(etype) > 128 { etype = slice!(etype, 0, 128) }
      body = .
      # The JSON column needs an object; the size check uses the serialized form.
      if length(encode_json(body)) > 1048576 { abort }
      . = {
        "tenant_id": tenant,
        "timestamp": format_timestamp!(timestamp(ts) ?? now(), "%Y-%m-%d %H:%M:%S%.3f"),
        "event_type": etype,
        "environment": env,
        "body": body
      }
sinks:
  router:
    type: http
    inputs: [shape]
    uri: http://{{ include "platform.prefix" . }}-tenant-router:4318/v1/events
    method: post
    encoding: {codec: json}
    framing: {method: newline_delimited}
    batch: {max_events: 2000, timeout_secs: 2}
    request: {retry_attempts: 30, timeout_secs: 30}
  {{- if (include "platform.streamOn" .) }}
  kafka:
    type: kafka
    inputs: [shape]
    bootstrap_servers: {{ include "platform.kafkaBrokers" . | quote }}
    topic: events.raw
    key_field: tenant_id
    encoding: {codec: json}
  {{- end }}
{{- end -}}
