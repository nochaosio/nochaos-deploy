{{/*
A Deployment (and its Service when port is set) of one Go binary of the
services image: (dict "ctx" $ "name" "api" "binary" "api" "port" 8080
"probe" "/readyz" "values" .Values.api "env" (include ...)).
*/}}
{{- define "platform.goWorkload" -}}
{{- $ := .ctx -}}
{{- if .port }}
{{ include "platform.service" . }}
---
{{- end }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "platform.name" . }}
  labels: {{- include "platform.labels" . | nindent 4 }}
spec:
  replicas: {{ .values.replicas }}
  selector:
    matchLabels: {{- include "platform.selector" . | nindent 6 }}
  {{- if .port }}
  strategy: {type: RollingUpdate, rollingUpdate: {maxUnavailable: 0, maxSurge: 1}}
  {{- end }}
  template:
    metadata:
      labels: {{- include "platform.labels" . | nindent 8 }}
      annotations:
        checksum/secrets: {{ include (print $.Template.BasePath "/secrets.yaml") $ | sha256sum | trunc 16 }}
    spec:
      {{- include "platform.goPod" $ | nindent 6 }}
      {{- with .sysctls }}
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532
        seccompProfile: {type: RuntimeDefault}
        sysctls: {{- toYaml . | nindent 10 }}
      {{- end }}
      containers:
        - name: {{ .name }}
          image: {{ include "platform.servicesImage" $ }}
          imagePullPolicy: {{ $.Values.image.pullPolicy }}
          command: [/usr/local/bin/{{ .binary }}]
          env:
            {{- .env | nindent 12 }}
            {{- with .values.extraEnv }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- if .probePort }}
          ports: [{name: http, containerPort: {{ .probePort }}}]
          readinessProbe: {httpGet: {path: {{ .probe }}, port: {{ .probePort }}}, periodSeconds: 5}
          livenessProbe: {httpGet: {path: /healthz, port: {{ .probePort }}}, periodSeconds: 20, failureThreshold: 6}
          {{- end }}
          {{- if .port }}
          lifecycle: {preStop: {sleep: {seconds: 5}}}
          {{- end }}
          resources: {{- toYaml .values.resources | nindent 12 }}
          {{- include "platform.goContainerSecurity" . | nindent 10 }}
{{- end -}}
