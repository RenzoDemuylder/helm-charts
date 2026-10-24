{{/* vim: set filetype=mustache: */}}

{{/*
Return the proper Scrob image name
*/}}
{{- define "scrob.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global "chart" .Chart) }}
{{- end -}}

{{/*
Return the proper PostgreSQL image name
*/}}
{{- define "scrob.postgresql.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.postgresql.image "global" .Values.global) }}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "scrob.imagePullSecrets" -}}
{{- include "common.images.pullSecrets" (dict "images" (list .Values.image .Values.postgresql.image) "global" .Values.global) -}}
{{- end -}}

{{/*
Return the ServiceAccount name
*/}}
{{- define "scrob.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Return the name of the Secret holding the Scrob credentials
*/}}
{{- define "scrob.secretName" -}}
{{- default (include "common.names.fullname" .) .Values.existingSecret -}}
{{- end -}}

{{/*
Return the name of the data PVC
*/}}
{{- define "scrob.pvcName" -}}
{{- default (include "common.names.fullname" .) .Values.persistence.existingClaim -}}
{{- end -}}

{{/*
Return the public URL of Scrob
*/}}
{{- define "scrob.serverUrl" -}}
{{- if .Values.serverUrl -}}
{{- .Values.serverUrl -}}
{{- else if .Values.ingress.enabled -}}
{{- printf "%s://%s" (ternary "https" "http" .Values.ingress.tls) .Values.ingress.hostname -}}
{{- else -}}
{{- printf "http://localhost:%v" .Values.containerPorts.http -}}
{{- end -}}
{{- end -}}

{{/*
Return the PostgreSQL fullname
*/}}
{{- define "scrob.postgresql.fullname" -}}
{{- printf "%s-postgresql" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the name of the Secret holding the PostgreSQL password (deployed by this chart)
*/}}
{{- define "scrob.postgresql.secretName" -}}
{{- default (include "scrob.postgresql.fullname" .) .Values.postgresql.auth.existingSecret -}}
{{- end -}}

{{/*
Return which database backs Scrob: "postgresql" (StatefulSet of this chart), "cnpg" (CloudNativePG Cluster created by
this chart) or "external" (externalDatabase)
*/}}
{{- define "scrob.database.mode" -}}
{{- if .Values.postgresql.enabled -}}postgresql{{- else if .Values.cnpg.enabled -}}cnpg{{- else -}}external{{- end -}}
{{- end -}}

{{/*
Return the name of the CloudNativePG Cluster
*/}}
{{- define "scrob.cnpg.fullname" -}}
{{- printf "%s-db" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Return the database host
*/}}
{{- define "scrob.database.host" -}}
{{- $mode := include "scrob.database.mode" . -}}
{{- if eq $mode "postgresql" -}}
{{- include "scrob.postgresql.fullname" . -}}
{{- else if eq $mode "cnpg" -}}
{{- printf "%s-rw" (include "scrob.cnpg.fullname" .) -}}
{{- else -}}
{{- .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{/*
Return the database port
*/}}
{{- define "scrob.database.port" -}}
{{- $mode := include "scrob.database.mode" . -}}
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
{{- define "scrob.database.user" -}}
{{- $mode := include "scrob.database.mode" . -}}
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
{{- define "scrob.database.name" -}}
{{- $mode := include "scrob.database.mode" . -}}
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
{{- define "scrob.database.secretName" -}}
{{- $mode := include "scrob.database.mode" . -}}
{{- if eq $mode "postgresql" -}}
{{- include "scrob.postgresql.secretName" . -}}
{{- else if eq $mode "cnpg" -}}
{{- printf "%s-app" (include "scrob.cnpg.fullname" .) -}}
{{- else if .Values.externalDatabase.existingSecret -}}
{{- .Values.externalDatabase.existingSecret -}}
{{- else -}}
{{- include "scrob.secretName" . -}}
{{- end -}}
{{- end -}}

{{/*
Return the key of the database password in the database Secret
*/}}
{{- define "scrob.database.passwordKey" -}}
{{- $mode := include "scrob.database.mode" . -}}
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
Usage: include "scrob.database.env" .
*/}}
{{- define "scrob.database.env" -}}
{{- $keys := .Values.externalDatabase.existingSecretKeys -}}
{{- $fromSecret := and (eq (include "scrob.database.mode" .) "external") .Values.externalDatabase.existingSecret -}}
{{- range $f := list (list "POSTGRES_HOST" "host" "scrob.database.host") (list "POSTGRES_PORT" "port" "scrob.database.port") (list "POSTGRES_USER" "user" "scrob.database.user") (list "POSTGRES_DB" "database" "scrob.database.name") }}
- name: {{ index $f 0 }}
  {{- if and $fromSecret (index $keys (index $f 1)) }}
  valueFrom:
    secretKeyRef:
      name: {{ $.Values.externalDatabase.existingSecret }}
      key: {{ index $keys (index $f 1) }}
  {{- else }}
  value: {{ include (index $f 2) $ | quote }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Security context of the helm test pods: always satisfies the "restricted" Pod Security Standard, independent of
the (user configurable) security contexts of the application.
*/}}
{{- define "scrob.tests.securityContext" -}}
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
{{- define "scrob.validateValues" -}}
{{- $messages := list -}}
{{- $messages = append $messages (include "scrob.validateValues.database" .) -}}
{{- $messages = append $messages (include "scrob.validateValues.replicas" .) -}}
{{- $messages = without $messages "" -}}
{{- $message := join "\n" $messages -}}
{{- if $message -}}
{{- printf "\nVALUES VALIDATION:\n%s" $message | fail -}}
{{- end -}}
{{- end -}}

{{/* Validate database configuration */}}
{{- define "scrob.validateValues.database" -}}
{{- if and .Values.postgresql.enabled .Values.cnpg.enabled -}}
scrob: postgresql.enabled / cnpg.enabled
    Both are enabled. Choose one database: the built-in PostgreSQL, a CloudNativePG cluster, or externalDatabase.
{{- else if and (eq (include "scrob.database.mode" .) "external") (not .Values.externalDatabase.host) (not (and .Values.externalDatabase.existingSecret .Values.externalDatabase.existingSecretKeys.host)) -}}
scrob: externalDatabase.host
    Scrob requires PostgreSQL. Enable postgresql.enabled or cnpg.enabled, or set externalDatabase.host (or externalDatabase.existingSecret with existingSecretKeys.host).
{{- end -}}
{{- end -}}

{{/* Validate replica count */}}
{{- define "scrob.validateValues.replicas" -}}
{{- if gt (int .Values.replicaCount) 1 -}}
scrob: replicaCount
    Scrob keeps state on a local volume and runs in-process schedulers. Do not run more than 1 replica.
{{- end -}}
{{- end -}}
