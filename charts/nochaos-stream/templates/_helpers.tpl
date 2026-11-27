{{/* Prefix of every object name: global.prefix, or the release name. */}}
{{- define "stream.prefix" -}}
{{- ((.Values.global).prefix | default .Release.Name) | trunc 40 | trimSuffix "-" -}}
{{- end -}}

{{/* Name of a component: (dict "ctx" $ "name" "metrics") -> <prefix>-metrics. */}}
{{- define "stream.name" -}}
{{- printf "%s-%s" (include "stream.prefix" .ctx) .name -}}
{{- end -}}

{{- define "stream.selector" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
{{- end -}}

{{- define "stream.labels" -}}
{{ include "stream.selector" . }}
app.kubernetes.io/part-of: nochaos
app.kubernetes.io/component: stream
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .ctx.Chart.Name .ctx.Chart.Version }}
{{- end -}}

{{- define "stream.image" -}}
{{- $registry := (.ctx.Values.global).imageRegistry | default "" -}}
{{- printf "%s%s:%s" (ternary "" (printf "%s/" $registry) (eq $registry "")) .img.repository (toString .img.tag) -}}
{{- end -}}

{{- define "stream.podSecurity" -}}
securityContext:
  runAsNonRoot: true
  runAsUser: {{ .uid }}
  runAsGroup: {{ .uid }}
  fsGroup: {{ .uid }}
  seccompProfile: {type: RuntimeDefault}
automountServiceAccountToken: false
{{- end -}}

{{- define "stream.containerSecurity" -}}
securityContext:
  allowPrivilegeEscalation: false
  capabilities: {drop: [ALL]}
{{- end -}}

{{- define "stream.scheduling" -}}
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
{{- define "stream.claims" -}}
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
{{- define "stream.dataVolume" -}}
{{- if not .persistence.enabled }}
- name: data
  emptyDir: {}
{{- end }}
{{- end -}}

{{- define "stream.storesStorageClass" -}}
{{- (.Values.global).storageClass | default "" -}}
{{- end -}}
