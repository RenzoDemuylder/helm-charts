{{/*
Resource requests/limits for a named size. Sizes are rough starting points, not tuned for any application:
set `resources` explicitly for production.
  include "common.resources.preset" (dict "type" "small")
*/}}
{{- define "common.resources.preset" -}}
{{- $presets := dict
      "nano"    (dict "requests" (dict "cpu" "50m"  "memory" "64Mi")  "limits" (dict "cpu" "100m" "memory" "128Mi"))
      "micro"   (dict "requests" (dict "cpu" "100m" "memory" "128Mi") "limits" (dict "cpu" "250m" "memory" "256Mi"))
      "small"   (dict "requests" (dict "cpu" "250m" "memory" "256Mi") "limits" (dict "cpu" "500m" "memory" "512Mi"))
      "medium"  (dict "requests" (dict "cpu" "500m" "memory" "512Mi") "limits" (dict "cpu" "1"    "memory" "1Gi"))
      "large"   (dict "requests" (dict "cpu" "1"    "memory" "1Gi")   "limits" (dict "cpu" "2"    "memory" "2Gi"))
      "xlarge"  (dict "requests" (dict "cpu" "2"    "memory" "2Gi")   "limits" (dict "cpu" "4"    "memory" "4Gi")) -}}
{{- if not (hasKey $presets .type) -}}
{{- fail (printf "invalid resources preset %q, allowed: none, %s" .type (keys $presets | sortAlpha | join ", ")) -}}
{{- end -}}
{{- index $presets .type | toYaml -}}
{{- end -}}
