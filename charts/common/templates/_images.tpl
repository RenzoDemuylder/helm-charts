{{/*
Full image reference. global.imageRegistry overrides image.registry; a digest overrides the tag;
the tag defaults to the chart appVersion when a chart is passed.
  include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global "chart" .Chart)
*/}}
{{- define "common.images.image" -}}
{{- $registry := default .imageRoot.registry ((.global).imageRegistry) -}}
{{- $ref := printf "%s:%s" .imageRoot.repository (default ((.chart).AppVersion | default "latest") (.imageRoot.tag | toString)) -}}
{{- if .imageRoot.digest -}}
{{- $ref = printf "%s@%s" .imageRoot.repository .imageRoot.digest -}}
{{- end -}}
{{- if $registry -}}{{ printf "%s/%s" $registry $ref }}{{- else -}}{{ $ref }}{{- end -}}
{{- end -}}

{{/*
imagePullSecrets block built from global.imagePullSecrets plus the pullSecrets of the given image roots.
Entries can be plain names or {name: x} maps. Renders nothing when there are none.
  include "common.images.pullSecrets" (dict "images" (list .Values.image) "global" .Values.global)
*/}}
{{- define "common.images.pullSecrets" -}}
{{- $entries := default (list) ((.global).imagePullSecrets) -}}
{{- range .images -}}
{{- $entries = concat $entries (default (list) .pullSecrets) -}}
{{- end -}}
{{- $names := list -}}
{{- range $entries -}}
{{- if kindIs "map" . -}}
{{- $names = append $names .name -}}
{{- else -}}
{{- $names = append $names . -}}
{{- end -}}
{{- end -}}
{{- if $names }}
imagePullSecrets:
{{- range uniq $names }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- end -}}
