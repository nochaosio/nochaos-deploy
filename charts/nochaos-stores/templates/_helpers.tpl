{{/* Prefix of every object name: global.prefix, or the release name. */}}
{{- define "stores.prefix" -}}
{{- ((.Values.global).prefix | default .Release.Name) | trunc 40 | trimSuffix "-" -}}
{{- end -}}

{{/* Name of a component: (dict "ctx" $ "name" "metrics") -> <prefix>-metrics. */}}
{{- define "stores.name" -}}
{{- printf "%s-%s" (include "stores.prefix" .ctx) .name -}}
{{- end -}}

{{- define "stores.selector" -}}
app.kubernetes.io/name: {{ .name }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
{{- end -}}

{{- define "stores.labels" -}}
{{ include "stores.selector" . }}
app.kubernetes.io/part-of: nochaos
app.kubernetes.io/component: stores
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .ctx.Chart.Name .ctx.Chart.Version }}
{{- end -}}

{{- define "stores.image" -}}
{{- $registry := (.ctx.Values.global).imageRegistry | default "" -}}
{{- printf "%s%s:%s" (ternary "" (printf "%s/" $registry) (eq $registry "")) .img.repository (toString .img.tag) -}}
{{- end -}}

{{- define "stores.podSecurity" -}}
securityContext:
  runAsNonRoot: true
  runAsUser: {{ .uid }}
  runAsGroup: {{ .uid }}
  fsGroup: {{ .uid }}
  seccompProfile: {type: RuntimeDefault}
automountServiceAccountToken: false
{{- end -}}

{{- define "stores.containerSecurity" -}}
securityContext:
  allowPrivilegeEscalation: false
  capabilities: {drop: [ALL]}
{{- end -}}

{{- define "stores.scheduling" -}}
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
{{- define "stores.claims" -}}
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
{{- define "stores.dataVolume" -}}
{{- if not .persistence.enabled }}
- name: data
  emptyDir: {}
{{- end }}
{{- end -}}

{{- define "stores.storesStorageClass" -}}
{{- (.Values.global).storageClass | default "" -}}
{{- end -}}

{{- define "stores.publicURL" -}}
{{- ((.Values.global).publicURL | default .Values.publicURL) | trimSuffix "/" -}}
{{- end -}}
