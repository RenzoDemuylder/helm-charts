<!--- app-name: Navidrome -->

# Navidrome Helm chart

[Navidrome](https://github.com/navidrome/navidrome) is a self-hosted music server and streamer compatible with the Subsonic API: point your own music collection at it and listen from the web UI or any Subsonic client.

## TL;DR

```console
helm install my-navidrome oci://ghcr.io/renzodemuylder/charts/navidrome
```

## Introduction

This chart deploys Navidrome on a Kubernetes cluster using the Helm package manager. Navidrome stores its state in an embedded SQLite database on the data volume (`/data`), so no external database is needed.

The upstream image has no `USER` and runs as root by default. This chart runs it as non-root UID 1000 with a read-only root filesystem and all capabilities dropped, with writable volumes for `/data` and `/tmp` only.

Values follow the layout and naming conventions popularised by Bitnami charts; shared helpers come from the [`common`](../common) library chart in this repository.

## Prerequisites

- Kubernetes 1.25+
- Helm 3.8+ (4.x supported)
- PV provisioner support in the cluster (for persistence)
- A music library reachable from the cluster (PVC, NFS, ...)

## Installing the chart

```console
helm install my-navidrome oci://ghcr.io/renzodemuylder/charts/navidrome \
  --set music.existingClaim=my-music \
  --set ingress.enabled=true \
  --set ingress.hostname=music.example.com \
  --set ingress.tls=true
```

Open the URL and create the first user: it becomes the administrator. Alternatively set `adminPassword` to bootstrap an `admin` user (upstream marks this setting as development-only).

## Configuration and installation details

### Music library

The library is mounted read-only at `/music`. Use an existing PVC:

```yaml
music:
  existingClaim: my-music
  subPath: albums        # optional
```

or any Kubernetes volume source:

```yaml
music:
  volume:
    nfs:
      server: nas.example.org
      path: /export/music
```

`music.existingClaim` and `music.volume` are mutually exclusive. With neither, an empty directory is mounted. The library is scanned from the UI; set `scanner.schedule` (cron or `@every 1h`) for periodic scans. The default `0` disables them.

The container user is `1000:1000` with `fsGroup: 1000`. Volumes that ignore `fsGroup` (NFS, hostPath) must be readable by that user, or change `containerSecurityContext.runAsUser` / `runAsGroup` and `podSecurityContext.fsGroup`.

### Secrets

`passwordEncryptionKey` is generated on first install and reused on upgrades (via `lookup`). Changing it invalidates the passwords Navidrome stores for external services. To manage secrets yourself, create a Secret and set `existingSecret` (keys: `password-encryption-key`, and as needed `lastfm-api-key`, `lastfm-secret`, `prometheus-password`). Any other `ND_*` setting can be added with `extraEnvVars`, `extraEnvVarsCM` or `extraEnvVarsSecret`, see the [configuration options](https://www.navidrome.org/docs/usage/configuration-options/).

### Usage statistics

Upstream sends anonymous usage statistics by default. This chart disables them (`enableInsightsCollector: false`); set it to `true` to opt in.

### Reverse proxy authentication

```yaml
extAuth:
  trustedSources: 10.0.0.0/8     # CIDRs of the proxies allowed to set the header
  userHeader: Remote-User
networkPolicy:
  allowExternal: false           # only the proxy may reach Navidrome
```

Navidrome trusts the header from the listed sources without further checks, so make sure nothing else can reach it from there.

### Served under a sub path

Set `baseUrl` to the public URL (or just the path, e.g. `/music`) and use the same path in the ingress (`ingress.path`). The probes follow the path of `baseUrl`.

### Strict NetworkPolicy

With `networkPolicy.allowExternalEgress=false` only DNS is allowed out. Last.fm, ListenBrainz and artist metadata lookups need outbound access: add rules through `networkPolicy.extraEgress`.

### Single replica

Navidrome keeps its SQLite database on a local volume. `replicaCount` above 1 is rejected, and the Deployment uses the `Recreate` strategy.

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

### Navidrome parameters

| Name                                                | Description                                                                                                                                                                                              | Value                       |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| `image.registry`                                    | Navidrome image registry                                                                                                                                                                                 | `REGISTRY_NAME`             |
| `image.repository`                                  | Navidrome image repository                                                                                                                                                                               | `REPOSITORY_NAME/navidrome` |
| `image.digest`                                      | Navidrome image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag                                                                                                | `""`                        |
| `image.pullPolicy`                                  | Navidrome image pull policy                                                                                                                                                                              | `IfNotPresent`              |
| `image.pullSecrets`                                 | Navidrome image pull secrets                                                                                                                                                                             | `[]`                        |
| `baseUrl`                                           | Base URL Navidrome is served under, e.g. `https://music.example.org` or just a path such as `/navidrome` (ND_BASEURL). Leave empty when served at the root                                               | `""`                        |
| `logLevel`                                          | Log level: error, warn, info, debug or trace (ND_LOGLEVEL)                                                                                                                                               | `info`                      |
| `sessionTimeout`                                    | How long a login session stays valid, e.g. `24h` (ND_SESSIONTIMEOUT). Empty uses the upstream default                                                                                                    | `""`                        |
| `enableSharing`                                     | Allow users to share albums and playlists through public links (ND_ENABLESHARING)                                                                                                                        | `true`                      |
| `enableInsightsCollector`                           | Send anonymous usage statistics to the Navidrome project (ND_ENABLEINSIGHTSCOLLECTOR). Disabled here, upstream enables it                                                                                | `false`                     |
| `passwordEncryptionKey`                             | Key used to encrypt the passwords stored for external services (ND_PASSWORDENCRYPTIONKEY). Generated randomly and preserved across upgrades if empty. Changing it invalidates stored passwords           | `""`                        |
| `adminPassword`                                     | Password for an `admin` user created on first start (ND_DEVAUTOCREATEADMINPASSWORD). Leave empty to create the first user in the web UI. Stored in the Secret, key `admin-password`                      | `""`                        |
| `existingSecret`                                    | Name of an existing Secret containing the Navidrome credentials (see keys below)                                                                                                                         | `""`                        |
| `scanner.enabled`                                   | Enable the periodic library scanner (ND_SCANNER_ENABLED)                                                                                                                                                 | `true`                      |
| `scanner.schedule`                                  | Scan schedule as a cron expression or duration, e.g. `@every 1h`. `0` disables scheduled scans, scan from the UI instead (ND_SCANNER_SCHEDULE)                                                           | `0`                         |
| `extAuth.trustedSources`                            | CIDR ranges of reverse proxies allowed to authenticate users through a header, e.g. `10.0.0.0/8`. Empty disables reverse proxy authentication (ND_EXTAUTH_TRUSTEDSOURCES)                                | `""`                        |
| `extAuth.userHeader`                                | Request header carrying the authenticated user name (ND_EXTAUTH_USERHEADER)                                                                                                                              | `Remote-User`               |
| `extAuth.logoutUrl`                                 | URL to redirect to after logout (ND_EXTAUTH_LOGOUTURL)                                                                                                                                                   | `""`                        |
| `lastfm.enabled`                                    | Enable the Last.fm integration (ND_LASTFM_ENABLED). The API key and secret are required for scrobbling                                                                                                   | `false`                     |
| `lastfm.apiKey`                                     | Last.fm API key (stored in the Secret, key `lastfm-api-key`)                                                                                                                                             | `""`                        |
| `lastfm.secret`                                     | Last.fm API secret (stored in the Secret, key `lastfm-secret`)                                                                                                                                           | `""`                        |
| `listenbrainz.enabled`                              | Enable the ListenBrainz integration (ND_LISTENBRAINZ_ENABLED)                                                                                                                                            | `false`                     |
| `prometheus.enabled`                                | Expose Prometheus metrics (ND_PROMETHEUS_ENABLED)                                                                                                                                                        | `false`                     |
| `prometheus.metricsPath`                            | Path the metrics are served at (ND_PROMETHEUS_METRICSPATH)                                                                                                                                               | `/metrics`                  |
| `prometheus.password`                               | Password protecting the metrics endpoint (stored in the Secret, key `prometheus-password`)                                                                                                               | `""`                        |
| `backup.schedule`                                   | Backup schedule as a cron expression, e.g. `0 3 * * *`. Empty disables backups (ND_BACKUP_SCHEDULE)                                                                                                      | `""`                        |
| `backup.count`                                      | Number of backups to keep (ND_BACKUP_COUNT)                                                                                                                                                              | `7`                         |
| `command`                                           | Override default container command (useful when using custom images)                                                                                                                                     | `[]`                        |
| `args`                                              | Override default container args (useful when using custom images)                                                                                                                                        | `[]`                        |
| `extraEnvVars`                                      | Array with extra environment variables to add to the Navidrome container                                                                                                                                 | `[]`                        |
| `extraEnvVarsCM`                                    | Name of existing ConfigMap containing extra env vars                                                                                                                                                     | `""`                        |
| `extraEnvVarsSecret`                                | Name of existing Secret containing extra env vars                                                                                                                                                        | `""`                        |
| `replicaCount`                                      | Number of Navidrome replicas to deploy. Navidrome keeps its SQLite database on a local volume: do not scale above 1                                                                                      | `1`                         |
| `containerPorts.http`                               | Navidrome HTTP container port (ND_PORT)                                                                                                                                                                  | `4533`                      |
| `livenessProbe.enabled`                             | Enable livenessProbe on Navidrome containers                                                                                                                                                             | `true`                      |
| `livenessProbe.initialDelaySeconds`                 | Initial delay seconds for livenessProbe                                                                                                                                                                  | `10`                        |
| `livenessProbe.periodSeconds`                       | Period seconds for livenessProbe                                                                                                                                                                         | `20`                        |
| `livenessProbe.timeoutSeconds`                      | Timeout seconds for livenessProbe                                                                                                                                                                        | `5`                         |
| `livenessProbe.failureThreshold`                    | Failure threshold for livenessProbe                                                                                                                                                                      | `6`                         |
| `livenessProbe.successThreshold`                    | Success threshold for livenessProbe                                                                                                                                                                      | `1`                         |
| `readinessProbe.enabled`                            | Enable readinessProbe on Navidrome containers                                                                                                                                                            | `true`                      |
| `readinessProbe.initialDelaySeconds`                | Initial delay seconds for readinessProbe                                                                                                                                                                 | `5`                         |
| `readinessProbe.periodSeconds`                      | Period seconds for readinessProbe                                                                                                                                                                        | `10`                        |
| `readinessProbe.timeoutSeconds`                     | Timeout seconds for readinessProbe                                                                                                                                                                       | `5`                         |
| `readinessProbe.failureThreshold`                   | Failure threshold for readinessProbe                                                                                                                                                                     | `6`                         |
| `readinessProbe.successThreshold`                   | Success threshold for readinessProbe                                                                                                                                                                     | `1`                         |
| `startupProbe.enabled`                              | Enable startupProbe on Navidrome containers (waits for the first start, which migrates the database and scans the library)                                                                               | `true`                      |
| `startupProbe.initialDelaySeconds`                  | Initial delay seconds for startupProbe                                                                                                                                                                   | `5`                         |
| `startupProbe.periodSeconds`                        | Period seconds for startupProbe                                                                                                                                                                          | `5`                         |
| `startupProbe.timeoutSeconds`                       | Timeout seconds for startupProbe                                                                                                                                                                         | `3`                         |
| `startupProbe.failureThreshold`                     | Failure threshold for startupProbe                                                                                                                                                                       | `60`                        |
| `startupProbe.successThreshold`                     | Success threshold for startupProbe                                                                                                                                                                       | `1`                         |
| `customLivenessProbe`                               | Custom livenessProbe that overrides the default one                                                                                                                                                      | `{}`                        |
| `customReadinessProbe`                              | Custom readinessProbe that overrides the default one                                                                                                                                                     | `{}`                        |
| `customStartupProbe`                                | Custom startupProbe that overrides the default one                                                                                                                                                       | `{}`                        |
| `resourcesPreset`                                   | Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge). This is ignored if resources is set (resources is recommended for production). | `small`                     |
| `resources`                                         | Set container requests and limits for different resources like CPU or memory (essential for production workloads)                                                                                        | `{}`                        |
| `podSecurityContext.enabled`                        | Enabled Navidrome pods' Security Context                                                                                                                                                                 | `true`                      |
| `podSecurityContext.fsGroupChangePolicy`            | Set filesystem group change policy                                                                                                                                                                       | `Always`                    |
| `podSecurityContext.sysctls`                        | Set kernel settings using the sysctl interface                                                                                                                                                           | `[]`                        |
| `podSecurityContext.supplementalGroups`             | Set filesystem extra groups                                                                                                                                                                              | `[]`                        |
| `podSecurityContext.fsGroup`                        | Set Navidrome pod's Security Context fsGroup                                                                                                                                                             | `1000`                      |
| `containerSecurityContext.enabled`                  | Enabled Navidrome containers' Security Context                                                                                                                                                           | `true`                      |
| `containerSecurityContext.seLinuxOptions`           | Set SELinux options in container                                                                                                                                                                         | `{}`                        |
| `containerSecurityContext.runAsUser`                | Set Navidrome containers' Security Context runAsUser                                                                                                                                                     | `1000`                      |
| `containerSecurityContext.runAsGroup`               | Set Navidrome containers' Security Context runAsGroup                                                                                                                                                    | `1000`                      |
| `containerSecurityContext.runAsNonRoot`             | Set Navidrome containers' Security Context runAsNonRoot                                                                                                                                                  | `true`                      |
| `containerSecurityContext.privileged`               | Set container's Security Context privileged                                                                                                                                                              | `false`                     |
| `containerSecurityContext.readOnlyRootFilesystem`   | Set container's Security Context readOnlyRootFilesystem                                                                                                                                                  | `true`                      |
| `containerSecurityContext.allowPrivilegeEscalation` | Set container's Security Context allowPrivilegeEscalation                                                                                                                                                | `false`                     |
| `containerSecurityContext.capabilities.drop`        | List of capabilities to be dropped                                                                                                                                                                       | `["ALL"]`                   |
| `containerSecurityContext.seccompProfile.type`      | Set container's Security Context seccomp profile                                                                                                                                                         | `RuntimeDefault`            |
| `automountServiceAccountToken`                      | Mount Service Account token in Navidrome pods                                                                                                                                                            | `false`                     |
| `hostAliases`                                       | Navidrome pods host aliases                                                                                                                                                                              | `[]`                        |
| `podLabels`                                         | Extra labels for Navidrome pods                                                                                                                                                                          | `{}`                        |
| `podAnnotations`                                    | Annotations for Navidrome pods                                                                                                                                                                           | `{}`                        |
| `podAffinityPreset`                                 | Pod affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`                                                                                                                      | `""`                        |
| `podAntiAffinityPreset`                             | Pod anti-affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`                                                                                                                 | `soft`                      |
| `nodeAffinityPreset.type`                           | Node affinity preset type. Ignored if `affinity` is set. Allowed values: `soft` or `hard`                                                                                                                | `""`                        |
| `nodeAffinityPreset.key`                            | Node label key to match. Ignored if `affinity` is set                                                                                                                                                    | `""`                        |
| `nodeAffinityPreset.values`                         | Node label values to match. Ignored if `affinity` is set                                                                                                                                                 | `[]`                        |
| `affinity`                                          | Affinity for Navidrome pods assignment                                                                                                                                                                   | `{}`                        |
| `nodeSelector`                                      | Node labels for Navidrome pods assignment                                                                                                                                                                | `{}`                        |
| `tolerations`                                       | Tolerations for Navidrome pods assignment                                                                                                                                                                | `[]`                        |
| `topologySpreadConstraints`                         | Topology Spread Constraints for pod assignment spread across your cluster among failure-domains                                                                                                          | `[]`                        |
| `schedulerName`                                     | Alternative scheduler                                                                                                                                                                                    | `""`                        |
| `priorityClassName`                                 | Navidrome pods' priorityClassName                                                                                                                                                                        | `""`                        |
| `terminationGracePeriodSeconds`                     | Seconds Navidrome pod needs to terminate gracefully                                                                                                                                                      | `""`                        |
| `lifecycleHooks`                                    | for the Navidrome container(s) to automate configuration before or after startup                                                                                                                         | `{}`                        |
| `updateStrategy.type`                               | Navidrome deployment strategy type. Recreate is required as the data volume is ReadWriteOnce                                                                                                             | `Recreate`                  |
| `extraVolumes`                                      | Optionally specify extra list of additional volumes for the Navidrome pod(s)                                                                                                                             | `[]`                        |
| `extraVolumeMounts`                                 | Optionally specify extra list of additional volumeMounts for the Navidrome container(s)                                                                                                                  | `[]`                        |
| `sidecars`                                          | Add additional sidecar containers to the Navidrome pod(s)                                                                                                                                                | `[]`                        |
| `initContainers`                                    | Add additional init containers to the Navidrome pod(s)                                                                                                                                                   | `[]`                        |
| `pdb.create`                                        | Enable a Pod Disruption Budget creation                                                                                                                                                                  | `true`                      |
| `pdb.minAvailable`                                  | Minimum number/percentage of pods that should remain scheduled                                                                                                                                           | `""`                        |
| `pdb.maxUnavailable`                                | Maximum number/percentage of pods that may be made unavailable. Defaults to `1` if both `pdb.minAvailable` and `pdb.maxUnavailable` are empty.                                                           | `""`                        |

### Traffic Exposure Parameters

| Name                                    | Description                                                                                                                      | Value                    |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| `service.type`                          | Navidrome service type                                                                                                           | `ClusterIP`              |
| `service.ports.http`                    | Navidrome service HTTP port                                                                                                      | `80`                     |
| `service.nodePorts.http`                | Node port for HTTP                                                                                                               | `""`                     |
| `service.clusterIP`                     | Navidrome service Cluster IP                                                                                                     | `""`                     |
| `service.loadBalancerIP`                | Navidrome service Load Balancer IP                                                                                               | `""`                     |
| `service.loadBalancerSourceRanges`      | Navidrome service Load Balancer sources                                                                                          | `[]`                     |
| `service.externalTrafficPolicy`         | Navidrome service external traffic policy                                                                                        | `Cluster`                |
| `service.annotations`                   | Additional custom annotations for Navidrome service                                                                              | `{}`                     |
| `service.extraPorts`                    | Extra ports to expose in the Navidrome service (normally used with the `sidecars` value)                                         | `[]`                     |
| `service.sessionAffinity`               | Control where client requests go, to the same pod or round-robin                                                                 | `None`                   |
| `service.sessionAffinityConfig`         | Additional settings for the sessionAffinity                                                                                      | `{}`                     |
| `ingress.enabled`                       | Enable ingress record generation for Navidrome                                                                                   | `false`                  |
| `ingress.pathType`                      | Ingress path type                                                                                                                | `ImplementationSpecific` |
| `ingress.hostname`                      | Default host for the ingress record                                                                                              | `navidrome.local`        |
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

| Name                        | Description                                                                                           | Value               |
| --------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------- |
| `persistence.enabled`       | Enable persistence using Persistent Volume Claims                                                     | `true`              |
| `persistence.storageClass`  | Storage class of backing PVC                                                                          | `""`                |
| `persistence.annotations`   | Persistent Volume Claim annotations                                                                   | `{}`                |
| `persistence.labels`        | Persistent Volume Claim labels                                                                        | `{}`                |
| `persistence.accessModes`   | Persistent Volume Access Modes                                                                        | `["ReadWriteOnce"]` |
| `persistence.size`          | Size of data volume                                                                                   | `2Gi`               |
| `persistence.existingClaim` | The name of an existing PVC to use for persistence                                                    | `""`                |
| `persistence.selector`      | Selector to match an existing Persistent Volume for Navidrome data PVC                                | `{}`                |
| `persistence.dataSource`    | Custom PVC data source                                                                                | `{}`                |
| `music.existingClaim`       | Name of an existing PVC holding the music library                                                     | `""`                |
| `music.volume`              | Raw volume source for the library, used when `music.existingClaim` is empty (evaluated as a template) | `{}`                |
| `music.subPath`             | Sub directory of the volume to mount at `/music`                                                      | `""`                |
| `music.readOnly`            | Mount the library read-only                                                                           | `true`              |

### Other Parameters

| Name                                          | Description                                                                      | Value   |
| --------------------------------------------- | -------------------------------------------------------------------------------- | ------- |
| `serviceAccount.create`                       | Specifies whether a ServiceAccount should be created                             | `true`  |
| `serviceAccount.name`                         | The name of the ServiceAccount to use.                                           | `""`    |
| `serviceAccount.annotations`                  | Additional Service Account annotations (evaluated as a template)                 | `{}`    |
| `serviceAccount.automountServiceAccountToken` | Automount service account token for the server service account                   | `false` |
| `tests.enabled`                               | Render the `helm test` hooks (checks that Navidrome answers through its Service) | `true`  |

## License

Chart code: Apache-2.0. Navidrome itself is GPL-3.0.
