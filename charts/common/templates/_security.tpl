{{/*
Render a pod or container securityContext from values (drops the `enabled` flag).
On OpenShift the fixed runAsUser/runAsGroup/fsGroup are removed so the restricted SCC can assign its own IDs
(controlled by global.compatibility.openshift.adaptSecurityContext: auto|force|disabled).
  include "common.security.context" (dict "secContext" .Values.containerSecurityContext "context" $)
*/}}
{{- define "common.security.context" -}}
{{- $sc := omit .secContext "enabled" -}}
{{- $mode := default "disabled" ((((.context.Values.global).compatibility).openshift).adaptSecurityContext) -}}
{{- if or (eq $mode "force") (and (eq $mode "auto") (.context.Capabilities.APIVersions.Has "security.openshift.io/v1")) -}}
{{- $sc = omit $sc "runAsUser" "runAsGroup" "fsGroup" -}}
{{- end -}}
{{- if not $sc.seLinuxOptions -}}
{{- $sc = omit $sc "seLinuxOptions" -}}
{{- end -}}
{{- toYaml $sc -}}
{{- end -}}
