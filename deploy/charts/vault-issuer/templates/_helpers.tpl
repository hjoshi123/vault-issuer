{{/*
Expand the name of the chart.
*/}}
{{- define "vault-issuer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.

We truncate at 63 chars because some Kubernetes name fields are limited to this
(by the DNS naming spec).
*/}}
{{- define "vault-issuer.fullname" -}}
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
Chart name and version, as used by the helm.sh/chart label.
*/}}
{{- define "vault-issuer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Labels applied to every resource this chart creates.
*/}}
{{- define "vault-issuer.labels" -}}
helm.sh/chart: {{ include "vault-issuer.chart" . }}
{{ include "vault-issuer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Labels used to select the controller's Pods. These must not change between
releases: they are immutable on the Deployment.
*/}}
{{- define "vault-issuer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vault-issuer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Name of the ServiceAccount the controller runs as.
*/}}
{{- define "vault-issuer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "vault-issuer.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
The namespace Secrets referenced by a ClusterIssuer are read from.
*/}}
{{- define "vault-issuer.clusterResourceNamespace" -}}
{{- default .Release.Namespace .Values.clusterResourceNamespace }}
{{- end }}

{{/*
The controller image reference, by digest when one is given and by tag
otherwise.
*/}}
{{- define "vault-issuer.image" -}}
{{- if .Values.image.digest -}}
{{ .Values.image.repository }}@{{ .Values.image.digest }}
{{- else -}}
{{ .Values.image.repository }}:{{ default .Chart.AppVersion .Values.image.tag }}
{{- end -}}
{{- end }}
