{{/*
Pod (anti-)affinity from a preset. Renders nothing for an empty type.
  include "common.affinities.pods" (dict "type" "soft|hard" "component" "app" "customLabels" $podLabels "context" $)
*/}}
{{- define "common.affinities.pods" -}}
{{- $term := dict
      "labelSelector" (dict "matchLabels" (merge (dict "app.kubernetes.io/component" (default "" .component)) (include "common.labels.matchLabels" (dict "customLabels" .customLabels "context" .context) | fromYaml)))
      "topologyKey" "kubernetes.io/hostname" -}}
{{- if eq .type "soft" -}}
{{- dict "preferredDuringSchedulingIgnoredDuringExecution" (list (dict "weight" 1 "podAffinityTerm" $term)) | toYaml -}}
{{- else if eq .type "hard" -}}
{{- dict "requiredDuringSchedulingIgnoredDuringExecution" (list $term) | toYaml -}}
{{- end -}}
{{- end -}}

{{/*
Node affinity from a preset. Renders nothing for an empty type or key.
  include "common.affinities.nodes" (dict "type" "soft|hard" "key" "k" "values" (list "a" "b"))
*/}}
{{- define "common.affinities.nodes" -}}
{{- if and .type .key -}}
{{- $expr := dict "key" .key "operator" "In" "values" .values -}}
{{- if eq .type "soft" -}}
{{- dict "preferredDuringSchedulingIgnoredDuringExecution" (list (dict "weight" 1 "preference" (dict "matchExpressions" (list $expr)))) | toYaml -}}
{{- else if eq .type "hard" -}}
{{- dict "requiredDuringSchedulingIgnoredDuringExecution" (dict "nodeSelectorTerms" (list (dict "matchExpressions" (list $expr)))) | toYaml -}}
{{- end -}}
{{- end -}}
{{- end -}}
