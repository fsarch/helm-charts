{{- define "fsarch-common.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "fsarch-common.fullname" . }}
  namespace: {{ include "fsarch-common.namespace" . }}
  labels:
    {{- include "fsarch-common.labels" . | nindent 4 }}
  {{- with .Values.commonAnnotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  replicas: {{ .Values.replicaCount }}
  revisionHistoryLimit: {{ .Values.revisionHistoryLimit }}
  selector:
    matchLabels:
      {{- include "fsarch-common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "fsarch-common.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if or .Values.serviceAccount.create .Values.serviceAccount.name }}
      serviceAccountName: {{ include "fsarch-common.serviceAccountName" . }}
      {{- end }}
      {{- with .Values.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}
          {{- with .Values.securityContext }}
          securityContext:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.containerPort }}
          env:
            {{- if .Values.env.port }}
            - name: PORT
              value: {{ .Values.env.port | quote }}
            {{- end }}
            {{- if and .Values.configMap.create .Values.env.configFilePath }}
            - name: CONFIG_FILE_PATH
              value: {{ .Values.env.configFilePath | quote }}
            {{- end }}
            {{- with .Values.extraEnv }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- if or .Values.configMap.create .Values.extraVolumeMounts }}
          volumeMounts:
            {{- if .Values.configMap.create }}
            - name: config
              mountPath: {{ .Values.env.configFilePath }}
              subPath: {{ base .Values.env.configFilePath }}
              readOnly: true
            {{- end }}
            {{- with .Values.extraVolumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          {{- end }}
          {{- if .Values.livenessProbe.enabled }}
          livenessProbe:
            {{- omit .Values.livenessProbe "enabled" | toYaml | nindent 12 }}
          {{- end }}
          {{- if .Values.readinessProbe.enabled }}
          readinessProbe:
            {{- omit .Values.readinessProbe "enabled" | toYaml | nindent 12 }}
          {{- end }}
          {{- with .Values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- if or .Values.configMap.create .Values.extraVolumes }}
      volumes:
        {{- if .Values.configMap.create }}
        - name: config
          configMap:
            name: {{ include "fsarch-common.configMapName" . }}
        {{- end }}
        {{- with .Values.extraVolumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}
