{{/*
Notice for mutable image tags, for use in NOTES.txt.
  include "common.warnings.rollingTag" .Values.image
*/}}
{{- define "common.warnings.rollingTag" -}}
{{- if and (not .digest) (or (eq (.tag | toString) "latest") (eq (.tag | toString) "main") (eq (.tag | toString) "edge")) }}

WARNING: image "{{ .repository }}:{{ .tag }}" uses a rolling tag. Pin an immutable tag or a digest for reproducible deployments.
{{- end }}
{{- end -}}
