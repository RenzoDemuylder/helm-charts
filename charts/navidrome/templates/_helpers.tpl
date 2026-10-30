{{/* vim: set filetype=mustache: */}}

{{/*
Return the proper Navidrome image name
*/}}
{{- define "navidrome.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global "chart" .Chart) }}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "navidrome.imagePullSecrets" -}}
{{- include "common.images.pullSecrets" (dict "images" (list .Values.image) "global" .Values.global) -}}
{{- end -}}

{{/*
Return the ServiceAccount name
*/}}
{{- define "navidrome.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Return the name of the Secret holding the Navidrome credentials
*/}}
{{- define "navidrome.secretName" -}}
{{- default (include "common.names.fullname" .) .Values.existingSecret -}}
{{- end -}}

{{/*
Return the name of the data PVC
*/}}
{{- define "navidrome.pvcName" -}}
{{- default (include "common.names.fullname" .) .Values.persistence.existingClaim -}}
{{- end -}}

{{/*
Return the volume source of the music library: the existing PVC, the raw volume spec or an emptyDir
*/}}
{{- define "navidrome.music.volume" -}}
{{- if .Values.music.existingClaim -}}
persistentVolumeClaim:
  claimName: {{ .Values.music.existingClaim }}
{{- else if .Values.music.volume -}}
{{- include "common.tplvalues.render" (dict "value" .Values.music.volume "context" $) -}}
{{- else -}}
emptyDir: {}
{{- end -}}
{{- end -}}

{{/*
Return the health check path. Navidrome serves /ping below the path of baseUrl, when one is set
*/}}
{{- define "navidrome.probePath" -}}
{{- $base := .Values.baseUrl -}}
{{- if hasPrefix "http" $base -}}{{- $base = (urlParse $base).path -}}{{- end -}}
{{- printf "%s/ping" (trimSuffix "/" $base) -}}
{{- end -}}

{{/*
Security context of the helm test pods: always satisfies the "restricted" Pod Security Standard, independent of
the (user configurable) security contexts of the application.
*/}}
{{- define "navidrome.tests.securityContext" -}}
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

{{/*
Compile all warnings into a single message.
*/}}
{{- define "navidrome.validateValues" -}}
{{- $messages := list -}}
{{- $messages = append $messages (include "navidrome.validateValues.replicas" .) -}}
{{- $messages = append $messages (include "navidrome.validateValues.music" .) -}}
{{- $messages = without $messages "" -}}
{{- $message := join "\n" $messages -}}
{{- if $message -}}
{{- printf "\nVALUES VALIDATION:\n%s" $message | fail -}}
{{- end -}}
{{- end -}}

{{/* Validate replica count */}}
{{- define "navidrome.validateValues.replicas" -}}
{{- if gt (int .Values.replicaCount) 1 -}}
navidrome: replicaCount
    Navidrome keeps its SQLite database on a local volume. Do not run more than 1 replica.
{{- end -}}
{{- end -}}

{{/* Validate the music library source */}}
{{- define "navidrome.validateValues.music" -}}
{{- if and .Values.music.existingClaim .Values.music.volume -}}
navidrome: music.existingClaim / music.volume
    Both are set. Provide the music library either as an existing PVC or as a raw volume, not both.
{{- end -}}
{{- end -}}
