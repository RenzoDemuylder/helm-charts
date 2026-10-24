{{/* Chart name, honouring nameOverride. */}}
{{- define "common.names.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Chart name and version, safe for use as a label value. */}}
{{- define "common.names.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Release-scoped name: fullnameOverride, or <release>-<name> (just <release> if it already contains the name). */}}
{{- define "common.names.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "common.names.name" . -}}
{{- $release := .Release.Name | lower -}}
{{- if contains $name $release -}}
{{- $release | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" $release $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Namespace to deploy into, honouring namespaceOverride. */}}
{{- define "common.names.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fullname of a subchart, computed from the parent chart: same rules as common.names.fullname applied to the subchart's
own values (fullnameOverride, nameOverride, release name already containing the name).
Usage: include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" $)
*/}}
{{- define "common.names.dependency.fullname" -}}
{{- if .chartValues.fullnameOverride -}}
{{- .chartValues.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .chartName .chartValues.nameOverride -}}
{{- $release := .context.Release.Name | lower -}}
{{- if contains $name $release -}}
{{- $release | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" $release $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}
