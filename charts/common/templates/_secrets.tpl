{{/*
Base64 value for a Secret key that is stable across upgrades. Precedence:
  1. the key already present in the live Secret (via lookup),
  2. the explicit `provided` value,
  3. a new random alphanumeric string of `length` characters.
Under `helm template` there is no cluster, so step 3 yields a fresh value on every render.
  include "common.secrets.generate" (dict "secret" "name" "key" "password" "provided" .Values.password "length" 24 "context" $)
*/}}
{{- define "common.secrets.generate" -}}
{{- $existing := (lookup "v1" "Secret" (include "common.names.namespace" .context) .secret).data -}}
{{- if and $existing (hasKey $existing .key) -}}
{{- index $existing .key | quote -}}
{{- else if .provided -}}
{{- .provided | toString | b64enc | quote -}}
{{- else -}}
{{- randAlphaNum (int (default 24 .length)) | b64enc | quote -}}
{{- end -}}
{{- end -}}
