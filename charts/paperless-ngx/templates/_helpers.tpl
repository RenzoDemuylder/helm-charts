{{/* vim: set filetype=mustache: */}}

{{/*
Return the proper Paperless-ngx image name
*/}}
{{- define "paperless-ngx.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global "chart" .Chart) }}
{{- end -}}

{{/*
Return the proper image name of the wait-for-database init container
*/}}
{{- define "paperless-ngx.waitForDatabase.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.waitForDatabase.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "paperless-ngx.imagePullSecrets" -}}
{{- include "common.images.pullSecrets" (dict "images" (list .Values.image .Values.waitForDatabase.image) "global" .Values.global) -}}
{{- end -}}

{{/*
Return the ServiceAccount name
*/}}
{{- define "paperless-ngx.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Return the name of the Secret holding the Paperless-ngx credentials
*/}}
{{- define "paperless-ngx.secretName" -}}
{{- default (include "common.names.fullname" .) .Values.existingSecret -}}
{{- end -}}

{{/*
Return the name of the data PVC
*/}}
{{- define "paperless-ngx.pvcName" -}}
{{- default (include "common.names.fullname" .) .Values.persistence.existingClaim -}}
{{- end -}}

{{/*
Return the public URL of Paperless-ngx (PAPERLESS_URL): `url`, else the ingress host, else empty.
An empty value is not passed on, so Paperless-ngx accepts any Host header.
*/}}
{{- define "paperless-ngx.url" -}}
{{- if .Values.url -}}
{{- .Values.url -}}
{{- else if .Values.ingress.enabled -}}
{{- printf "%s://%s" (ternary "https" "http" .Values.ingress.tls) .Values.ingress.hostname -}}
{{- end -}}
{{- end -}}

{{/*
Return the fullname of the PostgreSQL subchart resources
*/}}
{{- define "paperless-ngx.postgresql.fullname" -}}
{{- include "common.names.dependency.fullname" (dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" $) -}}
{{- end -}}

{{/*
Return the name of the Secret holding the PostgreSQL password (deployed by the postgresql subchart)
*/}}
{{- define "paperless-ngx.postgresql.secretName" -}}
{{- default (include "paperless-ngx.postgresql.fullname" .) .Values.postgresql.auth.existingSecret -}}
{{- end -}}

{{/*
Return which database backs Paperless-ngx: "postgresql" (StatefulSet of the postgresql subchart), "cnpg" (CloudNativePG Cluster created by
this chart) or "external" (externalDatabase)
*/}}
{{- define "paperless-ngx.database.mode" -}}
{{- if .Values.postgresql.enabled -}}postgresql{{- else if .Values.cnpg.enabled -}}cnpg{{- else -}}external{{- end -}}
{{- end -}}

{{/*
Return the name of the CloudNativePG Cluster
*/}}
{{- define "paperless-ngx.cnpg.fullname" -}}
{{- printf "%s-db" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the database host
*/}}
{{- define "paperless-ngx.database.host" -}}
{{- $mode := include "paperless-ngx.database.mode" . -}}
{{- if eq $mode "postgresql" -}}
{{- include "paperless-ngx.postgresql.fullname" . -}}
{{- else if eq $mode "cnpg" -}}
{{- printf "%s-rw" (include "paperless-ngx.cnpg.fullname" .) -}}
{{- else -}}
{{- .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{/*
Return the database port
*/}}
{{- define "paperless-ngx.database.port" -}}
{{- $mode := include "paperless-ngx.database.mode" . -}}
{{- if eq $mode "postgresql" -}}
{{- .Values.postgresql.service.ports.postgresql -}}
{{- else if eq $mode "cnpg" -}}
5432
{{- else -}}
{{- .Values.externalDatabase.port -}}
{{- end -}}
{{- end -}}

{{/*
Return the database user
*/}}
{{- define "paperless-ngx.database.user" -}}
{{- $mode := include "paperless-ngx.database.mode" . -}}
{{- if eq $mode "postgresql" -}}
{{- .Values.postgresql.auth.username -}}
{{- else if eq $mode "cnpg" -}}
{{- .Values.cnpg.owner -}}
{{- else -}}
{{- .Values.externalDatabase.user -}}
{{- end -}}
{{- end -}}

{{/*
Return the database name
*/}}
{{- define "paperless-ngx.database.name" -}}
{{- $mode := include "paperless-ngx.database.mode" . -}}
{{- if eq $mode "postgresql" -}}
{{- .Values.postgresql.auth.database -}}
{{- else if eq $mode "cnpg" -}}
{{- .Values.cnpg.database -}}
{{- else -}}
{{- .Values.externalDatabase.database -}}
{{- end -}}
{{- end -}}

{{/*
Return the name of the Secret holding the database password.
CloudNativePG stores the owner credentials in <cluster>-app.
*/}}
{{- define "paperless-ngx.database.secretName" -}}
{{- $mode := include "paperless-ngx.database.mode" . -}}
{{- if eq $mode "postgresql" -}}
{{- include "paperless-ngx.postgresql.secretName" . -}}
{{- else if eq $mode "cnpg" -}}
{{- printf "%s-app" (include "paperless-ngx.cnpg.fullname" .) -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "paperless-ngx.secretName" . -}}
{{- end -}}
{{- end -}}

{{/*
Return the key of the database password in the database Secret
*/}}
{{- define "paperless-ngx.database.passwordKey" -}}
{{- $mode := include "paperless-ngx.database.mode" . -}}
{{- if eq $mode "postgresql" -}}
{{- .Values.postgresql.auth.secretKeys.passwordKey -}}
{{- else if eq $mode "cnpg" -}}
password
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecretKeys.password -}}
{{- else -}}
database-password
{{- end -}}
{{- end -}}

{{/*
Environment variables describing the database connection (host, port, user, name).
Each one comes from externalDatabase.existingSecret when the matching existingSecretKeys entry is set
(e.g. a CloudNativePG `<cluster>-app` Secret), otherwise from plain values.
Usage: include "paperless-ngx.database.env" (dict "names" (list "HOST_VAR" "PORT_VAR" "USER_VAR" "NAME_VAR") "context" $)
*/}}
{{- define "paperless-ngx.database.env" -}}
{{- $ctx := .context -}}
{{- $keys := $ctx.Values.externalDatabase.existingSecretKeys -}}
{{- $fromSecret := and (eq (include "paperless-ngx.database.mode" $ctx) "external") $ctx.Values.externalDatabase.existingSecret -}}
{{- $names := .names -}}
{{- range $f := list (list (index $names 0) "host" "paperless-ngx.database.host") (list (index $names 1) "port" "paperless-ngx.database.port") (list (index $names 2) "user" "paperless-ngx.database.user") (list (index $names 3) "database" "paperless-ngx.database.name") }}
- name: {{ index $f 0 }}
  {{- if and $fromSecret (index $keys (index $f 1)) }}
  valueFrom:
    secretKeyRef:
      name: {{ $ctx.Values.externalDatabase.existingSecret }}
      key: {{ index $keys (index $f 1) }}
  {{- else }}
  value: {{ include (index $f 2) $ctx | quote }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Return the fullname of the Redis subchart resources
*/}}
{{- define "paperless-ngx.redis.fullname" -}}
{{- include "common.names.dependency.fullname" (dict "chartName" "redis" "chartValues" .Values.redis "context" $) -}}
{{- end -}}

{{/*
Return which Redis backs Paperless-ngx: "redis" (subchart) or "external" (externalRedis)
*/}}
{{- define "paperless-ngx.redis.mode" -}}
{{- if .Values.redis.enabled -}}redis{{- else -}}external{{- end -}}
{{- end -}}

{{/*
Return the Redis host
*/}}
{{- define "paperless-ngx.redis.host" -}}
{{- if .Values.redis.enabled -}}
{{- include "paperless-ngx.redis.fullname" . -}}
{{- else -}}
{{- .Values.externalRedis.host -}}
{{- end -}}
{{- end -}}

{{/*
Return the Redis port
*/}}
{{- define "paperless-ngx.redis.port" -}}
{{- if .Values.redis.enabled -}}
{{- .Values.redis.service.ports.redis -}}
{{- else -}}
{{- .Values.externalRedis.port -}}
{{- end -}}
{{- end -}}

{{/*
Return "true" when a Redis password has to be passed on
*/}}
{{- define "paperless-ngx.redis.hasPassword" -}}
{{- if .Values.redis.enabled -}}
{{- if .Values.redis.auth.enabled -}}true{{- end -}}
{{- else if or .Values.externalRedis.existingSecret .Values.externalRedis.password -}}
true
{{- end -}}
{{- end -}}

{{/*
Return the name of the Secret holding the Redis password
*/}}
{{- define "paperless-ngx.redis.secretName" -}}
{{- if .Values.redis.enabled -}}
{{- default (include "paperless-ngx.redis.fullname" .) .Values.redis.auth.existingSecret -}}
{{- else if .Values.externalRedis.existingSecret -}}
{{- .Values.externalRedis.existingSecret -}}
{{- else -}}
{{- include "paperless-ngx.secretName" . -}}
{{- end -}}
{{- end -}}

{{/*
Return the key of the Redis password in the Redis Secret
*/}}
{{- define "paperless-ngx.redis.passwordKey" -}}
{{- if .Values.redis.enabled -}}
{{- .Values.redis.auth.secretKeys.passwordKey -}}
{{- else if .Values.externalRedis.existingSecret -}}
{{- .Values.externalRedis.existingSecretPasswordKey -}}
{{- else -}}
redis-password
{{- end -}}
{{- end -}}

{{/*
Return the Redis connection URL. The password is substituted by Kubernetes from the PAPERLESS_REDIS_PASSWORD variable,
so it never appears in the pod spec.
*/}}
{{- define "paperless-ngx.redis.url" -}}
{{- $scheme := ternary "rediss" "redis" (and (not .Values.redis.enabled) .Values.externalRedis.tls) -}}
{{- $db := ternary 0 .Values.externalRedis.database .Values.redis.enabled -}}
{{- $auth := ternary ":$(PAPERLESS_REDIS_PASSWORD)@" "" (eq (include "paperless-ngx.redis.hasPassword" .) "true") -}}
{{- printf "%s://%s%s:%v/%v" $scheme $auth (include "paperless-ngx.redis.host" .) (include "paperless-ngx.redis.port" .) $db -}}
{{- end -}}

{{/*
Security context of the helm test pods: always satisfies the "restricted" Pod Security Standard, independent of
the (user configurable) security contexts of the application.
*/}}
{{- define "paperless-ngx.tests.securityContext" -}}
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
{{- define "paperless-ngx.validateValues" -}}
{{- $messages := list -}}
{{- $messages = append $messages (include "paperless-ngx.validateValues.database" .) -}}
{{- $messages = append $messages (include "paperless-ngx.validateValues.redis" .) -}}
{{- $messages = append $messages (include "paperless-ngx.validateValues.replicas" .) -}}
{{- $messages = without $messages "" -}}
{{- $message := join "\n" $messages -}}
{{- if $message -}}
{{- printf "\nVALUES VALIDATION:\n%s" $message | fail -}}
{{- end -}}
{{- end -}}

{{/* Validate database configuration */}}
{{- define "paperless-ngx.validateValues.database" -}}
{{- if and .Values.postgresql.enabled .Values.cnpg.enabled -}}
paperless-ngx: postgresql.enabled / cnpg.enabled
    Both are enabled. Choose one database: the built-in PostgreSQL, a CloudNativePG cluster, or externalDatabase.
{{- else if and (eq (include "paperless-ngx.database.mode" .) "external") (not .Values.externalDatabase.host) (not (and .Values.externalDatabase.existingSecret .Values.externalDatabase.existingSecretKeys.host)) -}}
paperless-ngx: externalDatabase.host
    Paperless-ngx requires PostgreSQL. Enable postgresql.enabled or cnpg.enabled, or set externalDatabase.host (or externalDatabase.existingSecret with existingSecretKeys.host).
{{- end -}}
{{- end -}}

{{/* Validate Redis configuration */}}
{{- define "paperless-ngx.validateValues.redis" -}}
{{- if and (not .Values.redis.enabled) (not .Values.externalRedis.host) -}}
paperless-ngx: externalRedis.host
    Paperless-ngx requires Redis. Enable redis.enabled or set externalRedis.host.
{{- end -}}
{{- end -}}

{{/* Validate replica count */}}
{{- define "paperless-ngx.validateValues.replicas" -}}
{{- if gt (int .Values.replicaCount) 1 -}}
paperless-ngx: replicaCount
    Paperless-ngx keeps state on local volumes and runs its own task workers. Do not run more than 1 replica.
{{- end -}}
{{- end -}}
