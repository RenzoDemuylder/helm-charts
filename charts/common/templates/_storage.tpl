{{/*
storageClassName line for a PVC: global.storageClass, then persistence.storageClass, then global.defaultStorageClass.
"-" renders an empty class (disables dynamic provisioning). Renders nothing when none is set.
  include "common.storage.class" (dict "persistence" .Values.persistence "global" .Values.global)
*/}}
{{- define "common.storage.class" -}}
{{- $class := default (default ((.global).defaultStorageClass) .persistence.storageClass) ((.global).storageClass) -}}
{{- if eq $class "-" -}}
storageClassName: ""
{{- else if $class -}}
storageClassName: {{ $class | quote }}
{{- end -}}
{{- end -}}
