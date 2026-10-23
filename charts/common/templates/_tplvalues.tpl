{{/*
Render a value that may contain template expressions. Strings are evaluated as templates, anything else is
serialised to YAML first, so nested strings are evaluated too.
  include "common.tplvalues.render" (dict "value" .Values.foo "context" $)
*/}}
{{- define "common.tplvalues.render" -}}
{{- if typeIs "string" .value -}}
{{- tpl .value .context -}}
{{- else -}}
{{- tpl (.value | toYaml) .context -}}
{{- end -}}
{{- end -}}

{{/*
Merge a list of maps (each one rendered first). Earlier entries win on conflict.
  include "common.tplvalues.merge" (dict "values" (list .Values.a .Values.b) "context" $)
*/}}
{{- define "common.tplvalues.merge" -}}
{{- $merged := dict -}}
{{- range .values -}}
{{- if . -}}
{{- $merged = merge $merged (include "common.tplvalues.render" (dict "value" . "context" $.context) | fromYaml) -}}
{{- end -}}
{{- end -}}
{{- toYaml $merged -}}
{{- end -}}
