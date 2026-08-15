{{- define "fsarch-common.notes" -}}
{{ .Chart.Name }} has been deployed.

Namespace: {{ include "fsarch-common.namespace" . }}
Release:   {{ .Release.Name }}

Service:
  {{ include "fsarch-common.fullname" . }}.{{ include "fsarch-common.namespace" . }}.svc.cluster.local:{{ .Values.service.port }}

{{- if .Values.ingress.enabled }}

Ingress hosts:
{{- range .Values.ingress.hosts }}
  http://{{ .host }}
{{- end }}
{{- else }}

Ingress is disabled. To reach the service from your machine:
  kubectl -n {{ include "fsarch-common.namespace" . }} port-forward svc/{{ include "fsarch-common.fullname" . }} {{ .Values.service.port }}:{{ .Values.service.port }}
{{- end }}
{{- end -}}
