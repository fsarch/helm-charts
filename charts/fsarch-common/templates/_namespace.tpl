{{- define "fsarch-common.namespace-resource" -}}
{{- if .Values.namespace.create }}
apiVersion: v1
kind: Namespace
metadata:
  name: {{ include "fsarch-common.namespace" . }}
  labels:
    {{- include "fsarch-common.labels" . | nindent 4 }}
  {{- with .Values.commonAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end -}}
