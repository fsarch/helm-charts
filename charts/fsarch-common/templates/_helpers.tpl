{{/*
Expand the name of the chart.
*/}}
{{- define "fsarch-common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 chars because some Kubernetes name fields are limited to this
(by the DNS naming spec).
*/}}
{{- define "fsarch-common.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Resolve the target namespace: explicit override wins, otherwise the release namespace.
*/}}
{{- define "fsarch-common.namespace" -}}
{{- default .Release.Namespace .Values.namespace.name }}
{{- end }}

{{/*
Chart name and version as used by the chart label.
*/}}
{{- define "fsarch-common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fsarch-common.labels" -}}
helm.sh/chart: {{ include "fsarch-common.chart" . }}
{{ include "fsarch-common.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "fsarch-common.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fsarch-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ConfigMap name
*/}}
{{- define "fsarch-common.configMapName" -}}
{{- if .Values.configMap.nameOverride }}
{{- .Values.configMap.nameOverride }}
{{- else }}
{{- printf "%s-config" (include "fsarch-common.fullname" .) }}
{{- end }}
{{- end }}

{{/*
ServiceAccount name
*/}}
{{- define "fsarch-common.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "fsarch-common.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
