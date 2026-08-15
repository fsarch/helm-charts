{{- define "fsarch-common.serviceaccount" -}}
{{- if .Values.serviceAccount.create }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "fsarch-common.serviceAccountName" . }}
  namespace: {{ include "fsarch-common.namespace" . }}
  labels:
    {{- include "fsarch-common.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end -}}
