{{- define "frontend.name" -}}
frontend
{{- end }}

{{- define "frontend.labels" -}}
app: {{ include "frontend.name" . }}
app.kubernetes.io/name: {{ include "frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "frontend.selectorLabels" -}}
app: {{ include "frontend.name" . }}
{{- end }}
