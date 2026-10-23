{{/*
Standard labels for metadata.labels. User labels are merged in, the standard ones win on conflict.
  include "common.labels.standard" (dict "customLabels" .Values.commonLabels "context" $)
*/}}
{{- define "common.labels.standard" -}}
{{- $ctx := .context -}}
{{- $labels := dict
      "app.kubernetes.io/name" (include "common.names.name" $ctx)
      "app.kubernetes.io/instance" $ctx.Release.Name
      "app.kubernetes.io/managed-by" $ctx.Release.Service
      "helm.sh/chart" (include "common.names.chart" $ctx) -}}
{{- with $ctx.Chart.AppVersion -}}
{{- $_ := set $labels "app.kubernetes.io/version" (. | toString | replace "+" "_" | trunc 63 | trimSuffix "-") -}}
{{- end -}}
{{- merge $labels (include "common.tplvalues.render" (dict "value" (default (dict) .customLabels) "context" $ctx) | fromYaml) | toYaml -}}
{{- end -}}

{{/*
Immutable labels for selectors (spec.selector.matchLabels, Service selector). Only name and instance:
custom labels are accepted for call-site symmetry but deliberately never used, so values changes cannot break selectors.
  include "common.labels.matchLabels" (dict "customLabels" .Values.podLabels "context" $)
*/}}
{{- define "common.labels.matchLabels" -}}
app.kubernetes.io/name: {{ include "common.names.name" .context }}
app.kubernetes.io/instance: {{ .context.Release.Name }}
{{- end -}}
