<!--- app-name: Paperless-ngx -->

# Paperless-ngx Helm chart

[Paperless-ngx](https://docs.paperless-ngx.com/) is a document management system that scans, OCRs, indexes and archives your paper documents.

## TL;DR

```console
helm install my-paperless oci://ghcr.io/renzodemuylder/charts/paperless-ngx
```

## Introduction

This chart deploys Paperless-ngx on a Kubernetes cluster using the Helm package manager. Paperless-ngx needs PostgreSQL and Redis (Celery broker). By default the chart deploys the [`postgresql`](../postgresql) and [`redis`](../redis) subcharts (single-instance StatefulSets, official images). Use `cnpg.enabled` to create a CloudNativePG `Cluster` instead of the bundled PostgreSQL, or `externalDatabase.*` / `externalRedis.*` to point at your own servers.

The image runs the web server, the task workers, the scheduler and the document consumer in one container under s6-overlay. The chart runs it as non-root UID 1000 with a read-only root filesystem and all capabilities dropped; `/tmp` and `/run` are emptyDir volumes. This was verified with `docker run --user 1000:1000 --read-only --cap-drop ALL --security-opt no-new-privileges`.

Values follow the layout and naming conventions popularised by Bitnami charts; shared helpers come from the [`common`](../common) library chart in this repository.

## Prerequisites

- Kubernetes 1.25+
- Helm 3.8+ (4.x supported)
- PV provisioner support in the cluster (for persistence)

## Installing the chart

```console
helm install my-paperless oci://ghcr.io/renzodemuylder/charts/paperless-ngx \
  --set url=https://paperless.example.com \
  --set ingress.enabled=true \
  --set ingress.hostname=paperless.example.com \
  --set ingress.tls=true
```

Log in as `admin`. The generated password is stored in the release Secret:

```console
kubectl get secret my-paperless-paperless-ngx -o jsonpath="{.data.admin-password}" | base64 -d
```

The administrator is only created on first start, when no superuser exists. Set `admin.enabled=false` to skip it and create one with `python3 manage.py createsuperuser` instead.

## Configuration and installation details

### Resources

OCR is CPU and memory hungry. The default `resourcesPreset` is `large` (1 CPU / 1Gi requested, 2 CPU / 2Gi limit); size `resources` for your document volume.

### Public URL

`url` sets `PAPERLESS_URL`, which also restricts the allowed hosts and CSRF origins. It defaults to the first ingress host when the ingress is enabled; when neither is set, any Host header is accepted.

### Secrets

`secretKey`, the administrator password, the PostgreSQL password and the Redis password are generated on first install and reused on upgrades (via `lookup`). To manage secrets yourself, create a Secret and set `existingSecret` (keys: `secret-key`, `admin-password`, and as needed `smtp-password`, `redis-password`, `database-password`). The subcharts take their own `postgresql.auth.existingSecret` / `redis.auth.existingSecret`.

### Storage

One PVC (`persistence.*`, default 10Gi) holds the application data (`data` subPath) and the stored documents (`media` subPath). The consumption and export directories are emptyDir volumes unless you mount existing claims:

```yaml
consume:
  existingClaim: scanner-inbox   # e.g. a ReadWriteMany claim shared with a scanner
export:
  existingClaim: paperless-export
```

### External database

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: postgres.example.com
  user: paperless
  database: paperless
  existingSecret: paperless-db        # Secret with the password
  existingSecretKeys:
    password: password
```

### CloudNativePG cluster created by the chart

With the [CloudNativePG](https://cloudnative-pg.io) operator installed in the cluster, the chart can create the `Cluster` for you:

```yaml
postgresql:
  enabled: false
cnpg:
  enabled: true
  instances: 3
  storage:
    size: 20Gi
  annotations:
    helm.sh/resource-policy: keep   # keep the cluster and its data on `helm uninstall`
```

Paperless-ngx connects to the `<release>-paperless-ngx-db-rw` service with the credentials in the `<release>-paperless-ngx-db-app` Secret that the operator generates. `postgresql.enabled` and `cnpg.enabled` are mutually exclusive.

### Existing CloudNativePG cluster

Point the chart at the Secret CloudNativePG generates (`<cluster>-app`); host, port, user and database are all read from it:

```yaml
postgresql:
  enabled: false
externalDatabase:
  existingSecret: paperless-db-app    # <cluster>-app
  existingSecretKeys:
    host: host
    port: port
    user: username
    password: password
    database: dbname
```

The Secret must be in the same namespace as the release. With `networkPolicy.allowExternalEgress=false`, add an egress rule for the database pods through `networkPolicy.extraEgress`.

### External Redis

```yaml
redis:
  enabled: false
externalRedis:
  host: redis.example.com
  existingSecret: paperless-redis     # Secret with the password (key: externalRedis.existingSecretPasswordKey)
```

The password is passed in the `PAPERLESS_REDIS` connection URL (substituted by Kubernetes from a Secret, never written into the pod spec) and therefore must only contain URL-safe characters. Set `externalRedis.tls=true` for `rediss://`.

### Tika and Gotenberg

To import Office documents and emails, deploy [Apache Tika](https://tika.apache.org/) and [Gotenberg](https://gotenberg.dev/) yourself and point the chart at them:

```yaml
tika:
  enabled: true
  endpoint: http://tika:9998
  gotenbergEndpoint: http://gotenberg:3000
```

### Limitations

- `PAPERLESS_OCR_LANGUAGES` (installing extra Tesseract languages at startup) needs root and is not supported. Use `ocr.language` with the languages already in the image, or build your own image.
- Single sign-on, mail rules and other settings without a dedicated value can be set through `extraEnvVars`, `extraEnvVarsCM` and `extraEnvVarsSecret` (e.g. `PAPERLESS_SOCIALACCOUNT_PROVIDERS` from a Secret).

### Single replica

Paperless-ngx keeps its state on local volumes and runs its own workers and scheduler. `replicaCount` above 1 is rejected, and the Deployment uses the `Recreate` strategy.

## Parameters

### Global parameters

| Name                                                  | Description                                                                                                                                                                                                                                                                                                                                                         | Value  |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| `global.imageRegistry`                                | Global Docker image registry                                                                                                                                                                                                                                                                                                                                        | `""`   |
| `global.imagePullSecrets`                             | Global Docker registry secret names as an array                                                                                                                                                                                                                                                                                                                     | `[]`   |
| `global.defaultStorageClass`                          | Global default StorageClass for Persistent Volume(s)                                                                                                                                                                                                                                                                                                                | `""`   |
| `global.storageClass`                                 | DEPRECATED: use global.defaultStorageClass instead                                                                                                                                                                                                                                                                                                                  | `""`   |
| `global.compatibility.openshift.adaptSecurityContext` | Adapt the securityContext sections of the deployment to make them compatible with Openshift restricted-v2 SCC: remove runAsUser, runAsGroup and fsGroup and let the platform use their allowed default IDs. Possible values: auto (apply if the detected running cluster is Openshift), force (perform the adaptation always), disabled (do not perform adaptation) | `auto` |

### Common parameters

| Name                     | Description                                                                             | Value           |
| ------------------------ | --------------------------------------------------------------------------------------- | --------------- |
| `nameOverride`           | String to partially override common.names.name                                          | `""`            |
| `fullnameOverride`       | String to fully override common.names.fullname                                          | `""`            |
| `namespaceOverride`      | String to fully override common.names.namespace                                         | `""`            |
| `commonLabels`           | Labels to add to all deployed objects                                                   | `{}`            |
| `commonAnnotations`      | Annotations to add to all deployed objects                                              | `{}`            |
| `clusterDomain`          | Kubernetes cluster domain name                                                          | `cluster.local` |
| `extraDeploy`            | Array of extra objects to deploy with the release                                       | `[]`            |
| `diagnosticMode.enabled` | Enable diagnostic mode (all probes will be disabled and the command will be overridden) | `false`         |
| `diagnosticMode.command` | Command to override all containers in the deployment                                    | `["sleep"]`     |
| `diagnosticMode.args`    | Args to override all containers in the deployment                                       | `["infinity"]`  |

### Paperless-ngx parameters

| Name                                                | Description                                                                                                                                                                                              | Value                           |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| `image.registry`                                    | Paperless-ngx image registry                                                                                                                                                                             | `REGISTRY_NAME`                 |
| `image.repository`                                  | Paperless-ngx image repository                                                                                                                                                                           | `REPOSITORY_NAME/paperless-ngx` |
| `image.digest`                                      | Paperless-ngx image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag                                                                                            | `""`                            |
| `image.pullPolicy`                                  | Paperless-ngx image pull policy                                                                                                                                                                          | `IfNotPresent`                  |
| `image.pullSecrets`                                 | Paperless-ngx image pull secrets                                                                                                                                                                         | `[]`                            |
| `secretKey`                                         | Secret key used for cryptographic signing (PAPERLESS_SECRET_KEY). Generated randomly (64 chars) and preserved across upgrades if empty                                                                   | `""`                            |
| `existingSecret`                                    | Name of an existing Secret containing the Paperless-ngx credentials (see keys below)                                                                                                                     | `""`                            |
| `url`                                               | Public URL Paperless-ngx is reachable at (PAPERLESS_URL). Defaults to the first ingress host, when enabled; otherwise unset so any Host header is accepted                                               | `""`                            |
| `timezone`                                          | Timezone of the container (PAPERLESS_TIME_ZONE)                                                                                                                                                          | `UTC`                           |
| `ocr.language`                                      | Tesseract language(s) used for OCR, e.g. `eng` or `deu+eng` (PAPERLESS_OCR_LANGUAGE)                                                                                                                     | `eng`                           |
| `admin.enabled`                                     | Create the initial administrator (PAPERLESS_ADMIN_USER/PASSWORD/MAIL). When disabled, create one with `manage.py createsuperuser`                                                                        | `true`                          |
| `admin.username`                                    | Administrator username                                                                                                                                                                                   | `admin`                         |
| `admin.password`                                    | Administrator password (stored in the Secret, key `admin-password`). Generated randomly (24 chars) and preserved across upgrades if empty                                                                | `""`                            |
| `admin.email`                                       | Administrator email address                                                                                                                                                                              | `""`                            |
| `tika.enabled`                                      | Enable Tika/Gotenberg document parsing (PAPERLESS_TIKA_ENABLED)                                                                                                                                          | `false`                         |
| `tika.endpoint`                                     | Tika server URL (PAPERLESS_TIKA_ENDPOINT), e.g. http://tika:9998                                                                                                                                         | `""`                            |
| `tika.gotenbergEndpoint`                            | Gotenberg server URL (PAPERLESS_TIKA_GOTENBERG_ENDPOINT), e.g. http://gotenberg:3000                                                                                                                     | `""`                            |
| `smtp.host`                                         | SMTP server host (PAPERLESS_EMAIL_HOST). Email is only configured when set                                                                                                                               | `""`                            |
| `smtp.port`                                         | SMTP server port (PAPERLESS_EMAIL_PORT)                                                                                                                                                                  | `587`                           |
| `smtp.username`                                     | SMTP username (PAPERLESS_EMAIL_HOST_USER)                                                                                                                                                                | `""`                            |
| `smtp.password`                                     | SMTP password (stored in the Secret, key `smtp-password`)                                                                                                                                                | `""`                            |
| `smtp.fromEmail`                                    | Sender email address (PAPERLESS_EMAIL_FROM)                                                                                                                                                              | `""`                            |
| `smtp.useTls`                                       | Use STARTTLS (PAPERLESS_EMAIL_USE_TLS)                                                                                                                                                                   | `true`                          |
| `smtp.useSsl`                                       | Use implicit TLS (PAPERLESS_EMAIL_USE_SSL)                                                                                                                                                               | `false`                         |
| `command`                                           | Override default container command (useful when using custom images)                                                                                                                                     | `[]`                            |
| `args`                                              | Override default container args (useful when using custom images)                                                                                                                                        | `[]`                            |
| `extraEnvVars`                                      | Array with extra environment variables to add to the Paperless-ngx container                                                                                                                             | `[]`                            |
| `extraEnvVarsCM`                                    | Name of existing ConfigMap containing extra env vars                                                                                                                                                     | `""`                            |
| `extraEnvVarsSecret`                                | Name of existing Secret containing extra env vars                                                                                                                                                        | `""`                            |
| `replicaCount`                                      | Number of Paperless-ngx replicas to deploy. Paperless-ngx keeps state on local volumes and runs its own task workers: do not scale above 1                                                               | `1`                             |
| `containerPorts.http`                               | Paperless-ngx HTTP container port (PAPERLESS_PORT)                                                                                                                                                       | `8000`                          |
| `livenessProbe.enabled`                             | Enable livenessProbe on Paperless-ngx containers                                                                                                                                                         | `true`                          |
| `livenessProbe.initialDelaySeconds`                 | Initial delay seconds for livenessProbe                                                                                                                                                                  | `10`                            |
| `livenessProbe.periodSeconds`                       | Period seconds for livenessProbe                                                                                                                                                                         | `20`                            |
| `livenessProbe.timeoutSeconds`                      | Timeout seconds for livenessProbe                                                                                                                                                                        | `10`                            |
| `livenessProbe.failureThreshold`                    | Failure threshold for livenessProbe                                                                                                                                                                      | `6`                             |
| `livenessProbe.successThreshold`                    | Success threshold for livenessProbe                                                                                                                                                                      | `1`                             |
| `readinessProbe.enabled`                            | Enable readinessProbe on Paperless-ngx containers                                                                                                                                                        | `true`                          |
| `readinessProbe.initialDelaySeconds`                | Initial delay seconds for readinessProbe                                                                                                                                                                 | `5`                             |
| `readinessProbe.periodSeconds`                      | Period seconds for readinessProbe                                                                                                                                                                        | `10`                            |
| `readinessProbe.timeoutSeconds`                     | Timeout seconds for readinessProbe                                                                                                                                                                       | `10`                            |
| `readinessProbe.failureThreshold`                   | Failure threshold for readinessProbe                                                                                                                                                                     | `6`                             |
| `readinessProbe.successThreshold`                   | Success threshold for readinessProbe                                                                                                                                                                     | `1`                             |
| `startupProbe.enabled`                              | Enable startupProbe on Paperless-ngx containers (waits for migrations to complete)                                                                                                                       | `true`                          |
| `startupProbe.initialDelaySeconds`                  | Initial delay seconds for startupProbe                                                                                                                                                                   | `10`                            |
| `startupProbe.periodSeconds`                        | Period seconds for startupProbe                                                                                                                                                                          | `5`                             |
| `startupProbe.timeoutSeconds`                       | Timeout seconds for startupProbe                                                                                                                                                                         | `5`                             |
| `startupProbe.failureThreshold`                     | Failure threshold for startupProbe                                                                                                                                                                       | `120`                           |
| `startupProbe.successThreshold`                     | Success threshold for startupProbe                                                                                                                                                                       | `1`                             |
| `customLivenessProbe`                               | Custom livenessProbe that overrides the default one                                                                                                                                                      | `{}`                            |
| `customReadinessProbe`                              | Custom readinessProbe that overrides the default one                                                                                                                                                     | `{}`                            |
| `customStartupProbe`                                | Custom startupProbe that overrides the default one                                                                                                                                                       | `{}`                            |
| `resourcesPreset`                                   | Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge). This is ignored if resources is set (resources is recommended for production). | `large`                         |
| `resources`                                         | Set container requests and limits for different resources like CPU or memory (essential for production workloads)                                                                                        | `{}`                            |
| `podSecurityContext.enabled`                        | Enabled Paperless-ngx pods' Security Context                                                                                                                                                             | `true`                          |
| `podSecurityContext.fsGroupChangePolicy`            | Set filesystem group change policy                                                                                                                                                                       | `Always`                        |
| `podSecurityContext.sysctls`                        | Set kernel settings using the sysctl interface                                                                                                                                                           | `[]`                            |
| `podSecurityContext.supplementalGroups`             | Set filesystem extra groups                                                                                                                                                                              | `[]`                            |
| `podSecurityContext.fsGroup`                        | Set Paperless-ngx pod's Security Context fsGroup                                                                                                                                                         | `1000`                          |
| `containerSecurityContext.enabled`                  | Enabled Paperless-ngx containers' Security Context                                                                                                                                                       | `true`                          |
| `containerSecurityContext.seLinuxOptions`           | Set SELinux options in container                                                                                                                                                                         | `{}`                            |
| `containerSecurityContext.runAsUser`                | Set Paperless-ngx containers' Security Context runAsUser                                                                                                                                                 | `1000`                          |
| `containerSecurityContext.runAsGroup`               | Set Paperless-ngx containers' Security Context runAsGroup                                                                                                                                                | `1000`                          |
| `containerSecurityContext.runAsNonRoot`             | Set Paperless-ngx containers' Security Context runAsNonRoot                                                                                                                                              | `true`                          |
| `containerSecurityContext.privileged`               | Set container's Security Context privileged                                                                                                                                                              | `false`                         |
| `containerSecurityContext.readOnlyRootFilesystem`   | Set container's Security Context readOnlyRootFilesystem                                                                                                                                                  | `true`                          |
| `containerSecurityContext.allowPrivilegeEscalation` | Set container's Security Context allowPrivilegeEscalation                                                                                                                                                | `false`                         |
| `containerSecurityContext.capabilities.drop`        | List of capabilities to be dropped                                                                                                                                                                       | `["ALL"]`                       |
| `containerSecurityContext.seccompProfile.type`      | Set container's Security Context seccomp profile                                                                                                                                                         | `RuntimeDefault`                |
| `automountServiceAccountToken`                      | Mount Service Account token in Paperless-ngx pods                                                                                                                                                        | `false`                         |
| `hostAliases`                                       | Paperless-ngx pods host aliases                                                                                                                                                                          | `[]`                            |
| `podLabels`                                         | Extra labels for Paperless-ngx pods                                                                                                                                                                      | `{}`                            |
| `podAnnotations`                                    | Annotations for Paperless-ngx pods                                                                                                                                                                       | `{}`                            |
| `podAffinityPreset`                                 | Pod affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`                                                                                                                      | `""`                            |
| `podAntiAffinityPreset`                             | Pod anti-affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`                                                                                                                 | `soft`                          |
| `nodeAffinityPreset.type`                           | Node affinity preset type. Ignored if `affinity` is set. Allowed values: `soft` or `hard`                                                                                                                | `""`                            |
| `nodeAffinityPreset.key`                            | Node label key to match. Ignored if `affinity` is set                                                                                                                                                    | `""`                            |
| `nodeAffinityPreset.values`                         | Node label values to match. Ignored if `affinity` is set                                                                                                                                                 | `[]`                            |
| `affinity`                                          | Affinity for Paperless-ngx pods assignment                                                                                                                                                               | `{}`                            |
| `nodeSelector`                                      | Node labels for Paperless-ngx pods assignment                                                                                                                                                            | `{}`                            |
| `tolerations`                                       | Tolerations for Paperless-ngx pods assignment                                                                                                                                                            | `[]`                            |
| `topologySpreadConstraints`                         | Topology Spread Constraints for pod assignment spread across your cluster among failure-domains                                                                                                          | `[]`                            |
| `schedulerName`                                     | Alternative scheduler                                                                                                                                                                                    | `""`                            |
| `priorityClassName`                                 | Paperless-ngx pods' priorityClassName                                                                                                                                                                    | `""`                            |
| `terminationGracePeriodSeconds`                     | Seconds Paperless-ngx pod needs to terminate gracefully                                                                                                                                                  | `""`                            |
| `lifecycleHooks`                                    | for the Paperless-ngx container(s) to automate configuration before or after startup                                                                                                                     | `{}`                            |
| `updateStrategy.type`                               | Paperless-ngx deployment strategy type. Recreate is required as the data volume is ReadWriteOnce                                                                                                         | `Recreate`                      |
| `extraVolumes`                                      | Optionally specify extra list of additional volumes for the Paperless-ngx pod(s)                                                                                                                         | `[]`                            |
| `extraVolumeMounts`                                 | Optionally specify extra list of additional volumeMounts for the Paperless-ngx container(s)                                                                                                              | `[]`                            |
| `sidecars`                                          | Add additional sidecar containers to the Paperless-ngx pod(s)                                                                                                                                            | `[]`                            |
| `initContainers`                                    | Add additional init containers to the Paperless-ngx pod(s)                                                                                                                                               | `[]`                            |
| `pdb.create`                                        | Enable a Pod Disruption Budget creation                                                                                                                                                                  | `true`                          |
| `pdb.minAvailable`                                  | Minimum number/percentage of pods that should remain scheduled                                                                                                                                           | `""`                            |
| `pdb.maxUnavailable`                                | Maximum number/percentage of pods that may be made unavailable. Defaults to `1` if both `pdb.minAvailable` and `pdb.maxUnavailable` are empty.                                                           | `""`                            |

### Traffic Exposure Parameters

| Name                                    | Description                                                                                                                      | Value                    |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| `service.type`                          | Paperless-ngx service type                                                                                                       | `ClusterIP`              |
| `service.ports.http`                    | Paperless-ngx service HTTP port                                                                                                  | `80`                     |
| `service.nodePorts.http`                | Node port for HTTP                                                                                                               | `""`                     |
| `service.clusterIP`                     | Paperless-ngx service Cluster IP                                                                                                 | `""`                     |
| `service.loadBalancerIP`                | Paperless-ngx service Load Balancer IP                                                                                           | `""`                     |
| `service.loadBalancerSourceRanges`      | Paperless-ngx service Load Balancer sources                                                                                      | `[]`                     |
| `service.externalTrafficPolicy`         | Paperless-ngx service external traffic policy                                                                                    | `Cluster`                |
| `service.annotations`                   | Additional custom annotations for Paperless-ngx service                                                                          | `{}`                     |
| `service.extraPorts`                    | Extra ports to expose in the Paperless-ngx service (normally used with the `sidecars` value)                                     | `[]`                     |
| `service.sessionAffinity`               | Control where client requests go, to the same pod or round-robin                                                                 | `None`                   |
| `service.sessionAffinityConfig`         | Additional settings for the sessionAffinity                                                                                      | `{}`                     |
| `ingress.enabled`                       | Enable ingress record generation for Paperless-ngx                                                                               | `false`                  |
| `ingress.pathType`                      | Ingress path type                                                                                                                | `ImplementationSpecific` |
| `ingress.hostname`                      | Default host for the ingress record                                                                                              | `paperless-ngx.local`    |
| `ingress.ingressClassName`              | IngressClass that will be used to implement the Ingress                                                                          | `""`                     |
| `ingress.path`                          | Default path for the ingress record                                                                                              | `/`                      |
| `ingress.annotations`                   | Additional annotations for the Ingress resource. To enable certificate autogeneration, place here your cert-manager annotations. | `{}`                     |
| `ingress.tls`                           | Enable TLS configuration for the host defined at `ingress.hostname` parameter                                                    | `false`                  |
| `ingress.extraHosts`                    | The list of additional hostnames to be covered with this ingress record.                                                         | `[]`                     |
| `ingress.extraPaths`                    | Any additional arbitrary paths that may need to be added to the ingress under the main host.                                     | `[]`                     |
| `ingress.extraTls`                      | The tls configuration for additional hostnames to be covered with this ingress record.                                           | `[]`                     |
| `ingress.secrets`                       | Custom TLS certificates as secrets                                                                                               | `[]`                     |
| `ingress.extraRules`                    | Additional rules to be covered with this ingress record                                                                          | `[]`                     |
| `networkPolicy.enabled`                 | Specifies whether a NetworkPolicy should be created                                                                              | `true`                   |
| `networkPolicy.allowExternal`           | Don't require server label for connections                                                                                       | `true`                   |
| `networkPolicy.allowExternalEgress`     | Allow the pod to access any range of port and all destinations.                                                                  | `true`                   |
| `networkPolicy.extraIngress`            | Add extra ingress rules to the NetworkPolicy                                                                                     | `[]`                     |
| `networkPolicy.extraEgress`             | Add extra egress rules to the NetworkPolicy (ignored if allowExternalEgress=true)                                                | `[]`                     |
| `networkPolicy.ingressNSMatchLabels`    | Labels to match to allow traffic from other namespaces                                                                           | `{}`                     |
| `networkPolicy.ingressNSPodMatchLabels` | Pod labels to match to allow traffic from other namespaces                                                                       | `{}`                     |

### Persistence Parameters

| Name                        | Description                                                                                                              | Value               |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------- |
| `persistence.enabled`       | Enable persistence using Persistent Volume Claims                                                                        | `true`              |
| `persistence.storageClass`  | Storage class of backing PVC                                                                                             | `""`                |
| `persistence.annotations`   | Persistent Volume Claim annotations                                                                                      | `{}`                |
| `persistence.labels`        | Persistent Volume Claim labels                                                                                           | `{}`                |
| `persistence.accessModes`   | Persistent Volume Access Modes                                                                                           | `["ReadWriteOnce"]` |
| `persistence.size`          | Size of the data and media volume                                                                                        | `10Gi`              |
| `persistence.existingClaim` | The name of an existing PVC to use for persistence                                                                       | `""`                |
| `persistence.selector`      | Selector to match an existing Persistent Volume for Paperless-ngx data PVC                                               | `{}`                |
| `persistence.dataSource`    | Custom PVC data source                                                                                                   | `{}`                |
| `consume.existingClaim`     | Name of an existing PVC mounted at the consumption directory (PAPERLESS_CONSUMPTION_DIR). An emptyDir is used when empty | `""`                |
| `export.existingClaim`      | Name of an existing PVC mounted at the export directory. An emptyDir is used when empty                                  | `""`                |

### Other Parameters

| Name                                          | Description                                                                          | Value   |
| --------------------------------------------- | ------------------------------------------------------------------------------------ | ------- |
| `serviceAccount.create`                       | Specifies whether a ServiceAccount should be created                                 | `true`  |
| `serviceAccount.name`                         | The name of the ServiceAccount to use.                                               | `""`    |
| `serviceAccount.annotations`                  | Additional Service Account annotations (evaluated as a template)                     | `{}`    |
| `serviceAccount.automountServiceAccountToken` | Automount service account token for the server service account                       | `false` |
| `tests.enabled`                               | Render the `helm test` hooks (checks that Paperless-ngx answers through its Service) | `true`  |

### Database parameters

| Name                                           | Description                                                                                                                                                                          | Value              |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------ |
| `postgresql.enabled`                           | Deploy the PostgreSQL subchart. Disable it to use CloudNativePG or an external database                                                                                              | `true`             |
| `postgresql.auth.username`                     | Name for the database user (also a superuser of the embedded server)                                                                                                                 | `paperless`        |
| `postgresql.auth.password`                     | Password for the database user. Generated randomly and preserved across upgrades if empty                                                                                            | `""`               |
| `postgresql.auth.database`                     | Name for the database                                                                                                                                                                | `paperless`        |
| `postgresql.auth.existingSecret`               | Name of existing secret to use for the PostgreSQL password                                                                                                                           | `""`               |
| `postgresql.auth.secretKeys.passwordKey`       | Name of the key in the existing secret containing the password                                                                                                                       | `password`         |
| `postgresql.service.ports.postgresql`          | PostgreSQL service port                                                                                                                                                              | `5432`             |
| `postgresql.resourcesPreset`                   | Set PostgreSQL container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge). This is ignored if postgresql.resources is set. | `micro`            |
| `cnpg.enabled`                                 | Create a CloudNativePG Cluster for Paperless-ngx (also set `postgresql.enabled=false`)                                                                                               | `false`            |
| `cnpg.instances`                               | Number of PostgreSQL instances (1 primary + replicas)                                                                                                                                | `1`                |
| `cnpg.imageName`                               | PostgreSQL image for the cluster. Empty uses the operator's default image                                                                                                            | `""`               |
| `cnpg.database`                                | Database created by the cluster for Paperless-ngx                                                                                                                                    | `paperless`        |
| `cnpg.owner`                                   | Owner (login role) of the database                                                                                                                                                   | `paperless`        |
| `cnpg.storage.size`                            | Size of each instance's data volume                                                                                                                                                  | `8Gi`              |
| `cnpg.storage.storageClass`                    | StorageClass of the data volumes (falls back to the global default)                                                                                                                  | `""`               |
| `cnpg.resourcesPreset`                         | Set PostgreSQL container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge). This is ignored if cnpg.resources is set.       | `small`            |
| `cnpg.resources`                               | Set PostgreSQL container requests and limits for different resources like CPU or memory                                                                                              | `{}`               |
| `cnpg.annotations`                             | Annotations for the Cluster resource. e.g. `helm.sh/resource-policy: keep` keeps the cluster (and its data) on `helm uninstall`                                                      | `{}`               |
| `cnpg.extraSpec`                               | Additional `spec` fields for the Cluster (backup, monitoring, postgresql.parameters, ...). Takes precedence over the fields above                                                    | `{}`               |
| `externalDatabase.host`                        | Database host. Not needed when `externalDatabase.existingSecretKeys.host` is set                                                                                                     | `""`               |
| `externalDatabase.port`                        | Database port number. Ignored when `externalDatabase.existingSecretKeys.port` is set                                                                                                 | `5432`             |
| `externalDatabase.user`                        | Non-root username for Paperless-ngx. Ignored when `externalDatabase.existingSecretKeys.user` is set                                                                                  | `paperless`        |
| `externalDatabase.password`                    | Password for the non-root username for Paperless-ngx. Ignored when `externalDatabase.existingSecret` is set                                                                          | `""`               |
| `externalDatabase.database`                    | Paperless-ngx database name. Ignored when `externalDatabase.existingSecretKeys.database` is set                                                                                      | `paperless`        |
| `externalDatabase.existingSecret`              | Name of an existing Secret containing the database credentials (e.g. a CloudNativePG `<cluster>-app` Secret)                                                                         | `""`               |
| `externalDatabase.existingSecretKeys.host`     | Key holding the database host                                                                                                                                                        | `""`               |
| `externalDatabase.existingSecretKeys.port`     | Key holding the database port                                                                                                                                                        | `""`               |
| `externalDatabase.existingSecretKeys.user`     | Key holding the database user                                                                                                                                                        | `""`               |
| `externalDatabase.existingSecretKeys.password` | Key holding the database password                                                                                                                                                    | `password`         |
| `externalDatabase.existingSecretKeys.database` | Key holding the database name                                                                                                                                                        | `""`               |
| `redis.enabled`                                | Deploy the Redis subchart. Disable it to use an external Redis                                                                                                                       | `true`             |
| `redis.auth.enabled`                           | Require a password                                                                                                                                                                   | `true`             |
| `redis.auth.password`                          | Redis password. Generated randomly and preserved across upgrades if empty                                                                                                            | `""`               |
| `redis.auth.existingSecret`                    | Name of existing secret to use for the Redis password                                                                                                                                | `""`               |
| `redis.auth.secretKeys.passwordKey`            | Name of the key in the existing secret containing the password                                                                                                                       | `redis-password`   |
| `redis.service.ports.redis`                    | Redis service port                                                                                                                                                                   | `6379`             |
| `redis.resourcesPreset`                        | Set Redis container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge). This is ignored if redis.resources is set.           | `nano`             |
| `externalRedis.host`                           | Redis host                                                                                                                                                                           | `""`               |
| `externalRedis.port`                           | Redis port number                                                                                                                                                                    | `6379`             |
| `externalRedis.database`                       | Redis database index                                                                                                                                                                 | `0`                |
| `externalRedis.tls`                            | Connect with TLS (rediss://)                                                                                                                                                         | `false`            |
| `externalRedis.password`                       | Redis password. Ignored when `externalRedis.existingSecret` is set. Leave empty if the server has no password                                                                        | `""`               |
| `externalRedis.existingSecret`                 | Name of an existing Secret containing the Redis password                                                                                                                             | `""`               |
| `externalRedis.existingSecretPasswordKey`      | Key holding the Redis password in `externalRedis.existingSecret`                                                                                                                     | `redis-password`   |
| `waitForDatabase.enabled`                      | Add an init container that waits for PostgreSQL                                                                                                                                      | `true`             |
| `waitForDatabase.image.registry`               | wait-for-database image registry                                                                                                                                                     | `docker.io`        |
| `waitForDatabase.image.repository`             | wait-for-database image repository                                                                                                                                                   | `library/postgres` |
| `waitForDatabase.image.digest`                 | wait-for-database image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag                                                                    | `""`               |
| `waitForDatabase.image.pullPolicy`             | wait-for-database image pull policy                                                                                                                                                  | `IfNotPresent`     |
| `waitForDatabase.image.pullSecrets`            | wait-for-database image pull secrets                                                                                                                                                 | `[]`               |

## License

Chart code: Apache-2.0. Paperless-ngx itself is GPL-3.0.
