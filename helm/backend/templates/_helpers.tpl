{{- define "backend.name" -}}
backend
{{- end }}

{{- define "backend.labels" -}}
app: {{ include "backend.name" . }}
app.kubernetes.io/name: {{ include "backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "backend.selectorLabels" -}}
app: {{ include "backend.name" . }}
{{- end }}
