{{/* vim: set filetype=mustache: */}}

{{/*
Return the proper Redis image name
*/}}
{{- define "redis.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global "chart" .Chart) }}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "redis.imagePullSecrets" -}}
{{- include "common.images.pullSecrets" (dict "images" (list .Values.image) "global" .Values.global) -}}
{{- end -}}

{{/*
Return the name of the Secret holding the Redis password
*/}}
{{- define "redis.secretName" -}}
{{- default (include "common.names.fullname" .) .Values.auth.existingSecret -}}
{{- end -}}

{{/*
Security context of the helm test pods: always satisfies the "restricted" Pod Security Standard, independent of
the (user configurable) security contexts of the application.
*/}}
{{- define "redis.tests.securityContext" -}}
runAsNonRoot: true
runAsUser: 1000
runAsGroup: 1000
privileged: false
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
seccompProfile:
  type: RuntimeDefault
{{- end -}}
