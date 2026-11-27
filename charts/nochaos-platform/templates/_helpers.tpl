{{/* Prefix of every object name: global.prefix, or the release name. */}}
{{- define "platform.prefix" -}}
{{- ((.Values.global).prefix | default .Release.Name) | trunc 40 | trimSuffix "-" -}}
{{- end -}}

{{/* Name of a component: (dict "ctx" $ "name" "metrics") -> <prefix>-metrics. */}}
{{- define "platform.name" -}}
{{- printf "%s-%s" (include "platform.prefix" .ctx) .name -}}
{{- end -}}

{{- define "platform.selector" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
{{- end -}}

{{- define "platform.labels" -}}
{{ include "platform.selector" . }}
app.kubernetes.io/part-of: nochaos
app.kubernetes.io/component: platform
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .ctx.Chart.Name .ctx.Chart.Version }}
{{- end -}}

{{- define "platform.image" -}}
{{- $registry := (.ctx.Values.global).imageRegistry | default "" -}}
{{- printf "%s%s:%s" (ternary "" (printf "%s/" $registry) (eq $registry "")) .img.repository (toString .img.tag) -}}
{{- end -}}

{{- define "platform.podSecurity" -}}
securityContext:
  runAsNonRoot: true
  runAsUser: {{ .uid }}
  runAsGroup: {{ .uid }}
  fsGroup: {{ .uid }}
  seccompProfile: {type: RuntimeDefault}
automountServiceAccountToken: false
{{- end -}}

{{- define "platform.containerSecurity" -}}
securityContext:
  allowPrivilegeEscalation: false
  capabilities: {drop: [ALL]}
{{- end -}}

{{- define "platform.scheduling" -}}
{{- with .nodeSelector }}
nodeSelector: {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .tolerations }}
tolerations: {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .affinity }}
affinity: {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/* volumeClaimTemplates of a StatefulSet, or nothing when persistence is off. */}}
{{- define "platform.claims" -}}
{{- if .persistence.enabled }}
volumeClaimTemplates:
  - apiVersion: v1
    kind: PersistentVolumeClaim
    metadata: {name: data}
    spec:
      accessModes: [ReadWriteOnce]
      {{- with (.persistence.storageClass | default .global) }}
      storageClassName: {{ . | quote }}
      {{- end }}
      resources: {requests: {storage: {{ .persistence.size }}}}
{{- end }}
{{- end -}}

{{/* The data volume when persistence is off. */}}
{{- define "platform.dataVolume" -}}
{{- if not .persistence.enabled }}
- name: data
  emptyDir: {}
{{- end }}
{{- end -}}

{{- define "platform.storageClass" -}}
{{- (.Values.global).storageClass | default "" -}}
{{- end -}}

{{- define "platform.pullSecrets" -}}
{{- with (.Values.global).imagePullSecrets }}
imagePullSecrets:
  {{- range . }}
  - name: {{ . }}
  {{- end }}
{{- end }}
{{- end -}}

{{- define "platform.servicesImage" -}}
{{- include "platform.image" (dict "ctx" . "img" (dict "repository" .Values.image.services.repository "tag" (.Values.image.services.tag | default .Chart.AppVersion))) -}}
{{- end -}}

{{- define "platform.portalImage" -}}
{{- include "platform.image" (dict "ctx" . "img" (dict "repository" .Values.image.portal.repository "tag" (.Values.image.portal.tag | default .Chart.AppVersion))) -}}
{{- end -}}

{{- define "platform.secretName" -}}
{{- .Values.secrets.existingSecret | default (printf "%s-secrets" (include "platform.prefix" .)) -}}
{{- end -}}

{{/* TENANT_BACKENDS: the fixed stores of the community edition. */}}
{{- define "platform.backends" -}}
{{- $p := include "platform.prefix" . -}}
{{- $ports := dict "metrics" 8428 "traces" 10428 "logs" 9428 "events" 8123 "grafana" 3000 "jaeger" 8080 -}}
{{- $out := list -}}
{{- range $k := list "metrics" "traces" "logs" "events" "grafana" "jaeger" -}}
{{- $v := index $.Values.stores $k | default "" -}}
{{- if eq $v "auto" -}}
{{- $out = append $out (printf "%s=http://%s-%s:%v" $k $p $k (index $ports $k)) -}}
{{- else if $v -}}
{{- $out = append $out (printf "%s=%s" $k $v) -}}
{{- end -}}
{{- end -}}
{{- join "," $out -}}
{{- end -}}

{{- define "platform.kafkaBrokers" -}}
{{- .Values.stream.kafkaBrokers | default (printf "%s-kafka:9092" (include "platform.prefix" .)) -}}
{{- end -}}

{{- define "platform.rumOn" -}}
{{- if or .Values.modules.rum .Values.modules.replay }}true{{ end -}}
{{- end -}}

{{/* Environment shared by the Go services. */}}
{{- define "platform.env.edition" -}}
- {name: EDITION, value: community}
- {name: TENANT_BACKENDS, value: {{ include "platform.backends" . | quote }}}
{{- end -}}

{{- define "platform.env.database" -}}
{{- if .Values.postgresql.enabled }}
- name: PG_PASSWORD
  valueFrom: {secretKeyRef: {name: {{ include "platform.secretName" . }}, key: postgres-password}}
- name: DATABASE_URL
  value: {{ printf "postgres://%s:$(PG_PASSWORD)@%s-postgres:5432/%s?sslmode=disable" .Values.postgresql.username (include "platform.prefix" .) .Values.postgresql.database | quote }}
{{- else if .Values.externalDatabase.existingSecret }}
- name: DATABASE_URL
  valueFrom: {secretKeyRef: {name: {{ .Values.externalDatabase.existingSecret }}, key: url}}
{{- else }}
- name: DATABASE_URL
  valueFrom: {secretKeyRef: {name: {{ printf "%s-database" (include "platform.prefix" .) }}, key: url}}
{{- end }}
{{- end -}}

{{- define "platform.env.redis" -}}
{{- if .Values.redis.enabled }}
- {name: REDIS_ADDR, value: {{ printf "%s-redis:6379" (include "platform.prefix" .) | quote }}}
- name: REDIS_PASSWORD
  valueFrom: {secretKeyRef: {name: {{ include "platform.secretName" . }}, key: redis-password}}
{{- else }}
- {name: REDIS_ADDR, value: {{ required "externalRedis.address is required when redis.enabled=false" .Values.externalRedis.address | quote }}}
- name: REDIS_PASSWORD
  valueFrom: {secretKeyRef: {name: {{ include "platform.secretName" . }}, key: redis-password}}
{{- end }}
{{- end -}}

{{- define "platform.env.s3" -}}
{{- if .Values.garage.enabled }}
- {name: S3_ENDPOINT, value: {{ printf "%s-garage:3900" (include "platform.prefix" .) | quote }}}
- {name: S3_REGION, value: garage}
- {name: S3_BUCKET, value: {{ .Values.garage.bucket | quote }}}
- {name: S3_SSL, value: "false"}
{{- else }}
- {name: S3_ENDPOINT, value: {{ .Values.externalS3.endpoint | quote }}}
- {name: S3_REGION, value: {{ .Values.externalS3.region | quote }}}
- {name: S3_BUCKET, value: {{ .Values.externalS3.bucket | quote }}}
- {name: S3_SSL, value: {{ .Values.externalS3.ssl | quote }}}
{{- end }}
- {name: S3_CREATE_BUCKET, value: "true"}
- name: S3_ACCESS_KEY
  valueFrom: {secretKeyRef: {name: {{ include "platform.secretName" . }}, key: s3-access-key}}
- name: S3_SECRET_KEY
  valueFrom: {secretKeyRef: {name: {{ include "platform.secretName" . }}, key: s3-secret-key}}
{{- end -}}

{{- define "platform.env.smtp" -}}
{{- $addr := .Values.smtp.address | default (ternary (printf "%s-mailpit:1025" (include "platform.prefix" .)) "" .Values.mailpit.enabled) -}}
{{- if $addr }}
- {name: SMTP_ADDR, value: {{ $addr | quote }}}
{{- with .Values.smtp.user }}
- {name: SMTP_USER, value: {{ . | quote }}}
{{- end }}
{{- if .Values.smtp.password }}
- name: SMTP_PASSWORD
  valueFrom: {secretKeyRef: {name: {{ include "platform.secretName" . }}, key: smtp-password}}
{{- end }}
{{- with .Values.smtp.from }}
- {name: MAIL_FROM, value: {{ . | quote }}}
{{- end }}
{{- end }}
{{- end -}}

{{- define "platform.env.notify" -}}
- name: NOTIFY_KEY
  valueFrom: {secretKeyRef: {name: {{ include "platform.secretName" . }}, key: notify-key}}
{{- end -}}

{{- define "platform.env.flags" -}}
- {name: FLAGS_URL, value: {{ printf "http://%s-flagd:8016" (include "platform.prefix" .) | quote }}}
{{- end -}}

{{/* Pod spec pieces of the Go services (image USER 65532). */}}
{{- define "platform.goPod" -}}
{{- include "platform.pullSecrets" . }}
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  runAsGroup: 65532
  seccompProfile: {type: RuntimeDefault}
automountServiceAccountToken: false
{{- include "platform.scheduling" .Values }}
{{- end -}}

{{- define "platform.goContainerSecurity" -}}
securityContext:
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities: {drop: [ALL]}
{{- end -}}

{{/* A ClusterIP Service: (dict "ctx" $ "name" "api" "port" 8080). */}}
{{- define "platform.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "platform.name" . }}
  labels: {{- include "platform.labels" . | nindent 4 }}
spec:
  selector: {{- include "platform.selector" . | nindent 4 }}
  ports: [{name: http, port: {{ .port }}, targetPort: {{ .port }}}]
{{- end -}}

{{/* "10G" or "500M" -> bytes (decimal units). */}}
{{- define "platform.bytes" -}}
{{- $s := toString . -}}
{{- if hasSuffix "T" $s }}{{ mul (trimSuffix "T" $s | int64) 1000000000000 }}
{{- else if hasSuffix "G" $s }}{{ mul (trimSuffix "G" $s | int64) 1000000000 }}
{{- else if hasSuffix "M" $s }}{{ mul (trimSuffix "M" $s | int64) 1000000 }}
{{- else }}{{ $s | int64 }}{{ end -}}
{{- end -}}

{{- define "platform.publicURL" -}}
{{- ((.Values.global).publicURL | default .Values.publicURL) | trimSuffix "/" -}}
{{- end -}}

{{- define "platform.ingestURL" -}}
{{- ((.Values.global).ingestURL | default .Values.ingestURL) | trimSuffix "/" -}}
{{- end -}}

{{- define "platform.streamOn" -}}
{{- if or .Values.stream.enabled ((.Values.global).stream).enabled }}true{{ end -}}
{{- end -}}
