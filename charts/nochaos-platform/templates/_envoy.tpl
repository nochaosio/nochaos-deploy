{{/*
Envoy, the entry point (the same routes as the Envoy Gateway of the cloud):
  :8080  app     /api, /grafana, /jaeger -> api; /mcp -> mcp; the rest -> portal
  :4318  ingest  OTLP gRPC and HTTP, /v1/events, /v1/rum; every request
                 checked by authz, which stamps x-tenant-id and x-oop-env.
*/}}
{{- define "platform.envoyConfig" -}}
{{- $p := include "platform.prefix" . -}}
{{- $rum := include "platform.rumOn" . -}}
{{- $hcm := printf `request_headers_timeout: 10s
request_timeout: 60s
common_http_protocol_options: {idle_timeout: 900s}
use_remote_address: true
xff_num_trusted_hops: %v` (int .Values.edge.trustedHops) -}}
admin:
  address: {socket_address: {address: 127.0.0.1, port_value: 9901}}
static_resources:
  listeners:
    - name: app
      address: {socket_address: {address: 0.0.0.0, port_value: 8080}}
      filter_chains:
        - filters:
            - name: envoy.filters.network.http_connection_manager
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                stat_prefix: app
                {{- $hcm | nindent 16 }}
                upgrade_configs: [{upgrade_type: websocket}]
                route_config:
                  virtual_hosts:
                    - name: app
                      domains: ["*"]
                      routes:
                        - {match: {path: /healthz}, direct_response: {status: 200, body: {inline_string: "ok\n"}}}
                        {{- if .Values.modules.mcp }}
                        - {match: {path: /mcp}, route: {cluster: mcp, timeout: 60s}}
                        {{- end }}
                        - {match: {prefix: /api/}, route: {cluster: api, timeout: 0s}}
                        - {match: {prefix: /grafana/}, route: {cluster: api, timeout: 0s}}
                        - {match: {prefix: /jaeger/}, route: {cluster: api}}
                        {{- if .Values.modules.flow }}
                        - {match: {prefix: /flow-lab/}, route: {cluster: api, timeout: 60s}}
                        {{- end }}
                        - {match: {prefix: /}, route: {cluster: portal}}
                http_filters:
                  - name: envoy.filters.http.router
                    typed_config: {"@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router}
    - name: ingest
      address: {socket_address: {address: 0.0.0.0, port_value: 4318}}
      filter_chains:
        - filters:
            - name: envoy.filters.network.http_connection_manager
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                stat_prefix: ingest
                {{- $hcm | nindent 16 }}
                codec_type: AUTO
                route_config:
                  virtual_hosts:
                    - name: ingest
                      domains: ["*"]
                      routes:
                        - match: {path: /healthz}
                          direct_response: {status: 200, body: {inline_string: "ok\n"}}
                          typed_per_filter_config:
                            envoy.filters.http.ext_authz:
                              "@type": type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthzPerRoute
                              disabled: true
                        - {match: {prefix: /opentelemetry.proto.collector., grpc: {}}, route: {cluster: pipeline-grpc}}
                        {{- if .Values.modules.events }}
                        - {match: {path: /v1/events}, route: {cluster: events-gw}}
                        {{- end }}
                        {{- if $rum }}
                        # Browser sessions: the cors filter answers the preflight
                        # (no key on it) before ext_authz sees the request.
                        - match: {prefix: /v1/rum/}
                          route: {cluster: rum-collector, timeout: 30s}
                          typed_per_filter_config:
                            envoy.filters.http.cors:
                              "@type": type.googleapis.com/envoy.extensions.filters.http.cors.v3.CorsPolicy
                              allow_origin_string_match: [{safe_regex: {regex: ".*"}}]
                              allow_methods: "POST, GET, OPTIONS"
                              allow_headers: "authorization, content-type, content-encoding"
                              max_age: "600"
                        {{- end }}
                        - {match: {path: /v1/traces}, route: {cluster: pipeline-http}}
                        - {match: {path: /v1/metrics}, route: {cluster: pipeline-http}}
                        - {match: {path: /v1/logs}, route: {cluster: pipeline-http}}
                http_filters:
                  - name: envoy.filters.http.cors
                    typed_config: {"@type": type.googleapis.com/envoy.extensions.filters.http.cors.v3.Cors}
                  - name: envoy.filters.http.ext_authz
                    typed_config:
                      "@type": type.googleapis.com/envoy.extensions.filters.http.ext_authz.v3.ExtAuthz
                      transport_api_version: V3
                      failure_mode_allow: false
                      # authz slow or down is a 503 that OTLP exporters retry,
                      # never a 403, which they treat as permanent.
                      status_on_error: {code: ServiceUnavailable}
                      with_request_body: {max_request_bytes: 4194304, allow_partial_message: false}
                      allowed_headers: {patterns: [{exact: authorization}, {exact: content-encoding}, {exact: content-type}, {exact: grpc-encoding}]}
                      http_service:
                        server_uri: {uri: "http://{{ $p }}-authz:9000", cluster: authz, timeout: 3s}
                        path_prefix: /check
                        authorization_response:
                          allowed_upstream_headers: {patterns: [{exact: x-tenant-id}, {exact: x-oop-env}]}
                          allowed_client_headers: {patterns: [{exact: retry-after}, {exact: content-type}]}
                  - name: envoy.filters.http.router
                    typed_config: {"@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router}
  clusters:
    {{- include "platform.envoyCluster" (dict "name" "api" "host" (printf "%s-api" $p) "port" 8080) | nindent 4 }}
    {{- include "platform.envoyCluster" (dict "name" "portal" "host" (printf "%s-portal" $p) "port" 8080) | nindent 4 }}
    {{- include "platform.envoyCluster" (dict "name" "authz" "host" (printf "%s-authz" $p) "port" 9000) | nindent 4 }}
    {{- include "platform.envoyCluster" (dict "name" "pipeline-http" "host" (printf "%s-pipeline" $p) "port" 4318) | nindent 4 }}
    {{- include "platform.envoyCluster" (dict "name" "pipeline-grpc" "host" (printf "%s-pipeline" $p) "port" 4317 "h2" true) | nindent 4 }}
    {{- if .Values.modules.mcp }}
    {{- include "platform.envoyCluster" (dict "name" "mcp" "host" (printf "%s-mcp" $p) "port" 8080) | nindent 4 }}
    {{- end }}
    {{- if $rum }}
    {{- include "platform.envoyCluster" (dict "name" "rum-collector" "host" (printf "%s-rum-collector" $p) "port" 8090) | nindent 4 }}
    {{- end }}
    {{- if .Values.modules.events }}
    {{- include "platform.envoyCluster" (dict "name" "events-gw" "host" (printf "%s-events-gw" $p) "port" 8080) | nindent 4 }}
    {{- end }}
{{- end -}}

{{- define "platform.envoyCluster" -}}
- name: {{ .name }}
  type: STRICT_DNS
  dns_lookup_family: V4_ONLY
  {{- if .h2 }}
  typed_extension_protocol_options:
    envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
      "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
      explicit_http_config: {http2_protocol_options: {}}
  {{- end }}
  load_assignment: {cluster_name: {{ .name }}, endpoints: [{lb_endpoints: [{endpoint: {address: {socket_address: {address: {{ .host }}, port_value: {{ .port }}}}}}]}]}
{{- end -}}
