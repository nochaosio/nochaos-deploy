{{/* Grafana datasources: uids are the ones the platform's API checks per module. */}}
{{- define "stores.grafanaDatasources" -}}
{{- $p := include "stores.prefix" . -}}
apiVersion: 1
datasources:
  - name: Metrics
    uid: metrics
    type: prometheus
    url: http://{{ $p }}-metrics:8428
    isDefault: true
    editable: false
    jsonData: {timeInterval: 15s, httpMethod: POST}
  - name: Logs
    uid: logs
    type: victoriametrics-logs-datasource
    url: http://{{ $p }}-logs:9428
    editable: false
    jsonData:
      derivedFields:
        - {name: trace_id, matcherType: label, matcherRegex: trace_id, datasourceUid: traces, url: "$${__value.raw}"}
        - {name: Open trace, matcherType: label, matcherRegex: trace_id, url: "/traces/$${__value.raw}", urlDisplayLabel: "Open in nochaos", targetBlank: true}
        - {name: traceId, matcherType: label, matcherRegex: traceId, url: "/traces/$${__value.raw}", urlDisplayLabel: "Open in nochaos", targetBlank: true}
  - name: Traces
    uid: traces
    type: jaeger
    url: http://{{ $p }}-traces:10428/select/jaeger
    editable: false
    jsonData:
      tracesToLogsV2: {datasourceUid: logs, filterByTraceID: true, spanStartTimeShift: "-5m", spanEndTimeShift: "5m"}
      tracesToMetrics: {datasourceUid: metrics}
  {{- if .Values.events.enabled }}
  - name: Events
    uid: events
    type: grafana-clickhouse-datasource
    editable: false
    jsonData: {host: {{ $p }}-events, port: 8123, protocol: http, username: grafana, defaultDatabase: oop}
  {{- end }}
{{- end -}}

{{- define "stores.jaegerConf" -}}
server {
    listen 8080;
    server_tokens off;

    location = /jaeger/healthz { return 200 "ok\n"; }

    location /jaeger/api/ {
        proxy_pass http://{{ include "stores.prefix" . }}-traces:10428/select/jaeger/api/;
        proxy_read_timeout 60s;
    }

    location /jaeger/ {
        root /srv;
        try_files $uri /jaeger/index.html;
        add_header Cache-Control "no-cache";
    }
}
{{- end -}}

{{/* TENANT_BACKENDS for the platform, from what this chart runs. */}}
{{- define "stores.backends" -}}
{{- $p := include "stores.prefix" . -}}
{{- $out := list -}}
{{- if .Values.metrics.enabled }}{{ $out = append $out (printf "metrics=http://%s-metrics:8428" $p) }}{{ end -}}
{{- if .Values.traces.enabled }}{{ $out = append $out (printf "traces=http://%s-traces:10428" $p) }}{{ end -}}
{{- if .Values.logs.enabled }}{{ $out = append $out (printf "logs=http://%s-logs:9428" $p) }}{{ end -}}
{{- if .Values.events.enabled }}{{ $out = append $out (printf "events=http://%s-events:8123" $p) }}{{ end -}}
{{- if .Values.grafana.enabled }}{{ $out = append $out (printf "grafana=http://%s-grafana:3000" $p) }}{{ end -}}
{{- if .Values.jaeger.enabled }}{{ $out = append $out (printf "jaeger=http://%s-jaeger:8080" $p) }}{{ end -}}
{{ join "," $out }}
{{- end -}}
