{{- define "worker.name" -}}
worker
{{- end }}

{{- define "worker.labels" -}}
app: {{ include "worker.name" . }}
app.kubernetes.io/name: {{ include "worker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "worker.selectorLabels" -}}
app: {{ include "worker.name" . }}
{{- end }}
