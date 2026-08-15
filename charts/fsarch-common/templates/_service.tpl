{{- define "fsarch-common.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "fsarch-common.fullname" . }}
  namespace: {{ include "fsarch-common.namespace" . }}
  labels:
    {{- include "fsarch-common.labels" . | nindent 4 }}
  {{- with .Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.service.type }}
  selector:
    {{- include "fsarch-common.selectorLabels" . | nindent 4 }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: http
{{- end -}}
