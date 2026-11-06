<!--- app-name: Redis -->

# Redis Helm chart

[Redis](https://redis.io/) is an in-memory data store used as cache and message broker. This chart deploys a single-instance Redis
(official `redis` image) with secure defaults. It can be installed on its own or used as a dependency of an application chart.

## TL;DR

```console
helm install my-redis oci://ghcr.io/renzodemuylder/charts/redis
```

## Introduction

The chart creates a StatefulSet (one replica, `volumeClaimTemplates` for the data, append-only file enabled), a Service, a Secret with a
generated password and a NetworkPolicy. The pod runs as UID 999 with a read-only root filesystem and all capabilities dropped. For
replication, Sentinel or Cluster use an operator instead.

Values follow the layout and naming conventions popularised by Bitnami charts; shared helpers come from the [`common`](../common) library chart in this repository.

## Prerequisites

- Kubernetes 1.25+
- Helm 3.8+ (4.x supported)
- PV provisioner support in the cluster (for persistence)

## Configuration and installation details

### Credentials

The password is generated on first install and reused on upgrades (via `lookup`). Set `auth.password`, or create a Secret and set
`auth.existingSecret` (key `auth.secretKeys.passwordKey`, default `redis-password`). The server is started with `--requirepass`
taken from the environment, so the password never appears in the pod spec. `auth.enabled=false` turns authentication off.

### NetworkPolicy

By default only pods labelled `<release>-redis-client: "true"` can connect (`networkPolicy.allowExternal=false`). Allow whole
namespaces with `networkPolicy.ingressNSMatchLabels`, or everyone with `networkPolicy.allowExternal=true`.

### Using the chart as a dependency

```yaml
# Chart.yaml
dependencies:
  - name: redis
    repository: file://../redis   # or oci://ghcr.io/renzodemuylder/charts
    version: 0.x.x
    condition: redis.enabled
```

The parent chart can compute the resource names with `common.names.dependency.fullname`, label its pods
`<release>-redis-client: "true"` and read the password from the `<release>-redis` Secret (key `redis-password`).
See [`charts/paperless-ngx`](../paperless-ngx).

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

| Name                | Description                                       | Value           |
| ------------------- | ------------------------------------------------- | --------------- |
| `nameOverride`      | String to partially override common.names.name    | `""`            |
| `fullnameOverride`  | String to fully override common.names.fullname    | `""`            |
| `namespaceOverride` | String to fully override common.names.namespace   | `""`            |
| `commonLabels`      | Labels to add to all deployed objects             | `{}`            |
| `commonAnnotations` | Annotations to add to all deployed objects        | `{}`            |
| `clusterDomain`     | Kubernetes cluster domain name                    | `cluster.local` |
| `extraDeploy`       | Array of extra objects to deploy with the release | `[]`            |

### Redis parameters

| Name                                                | Description                                                                                                                                                                                              | Value                   |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| `image.registry`                                    | Redis image registry                                                                                                                                                                                     | `REGISTRY_NAME`         |
| `image.repository`                                  | Redis image repository                                                                                                                                                                                   | `REPOSITORY_NAME/redis` |
| `image.digest`                                      | Redis image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag                                                                                                    | `""`                    |
| `image.pullPolicy`                                  | Redis image pull policy                                                                                                                                                                                  | `IfNotPresent`          |
| `image.pullSecrets`                                 | Redis image pull secrets                                                                                                                                                                                 | `[]`                    |
| `auth.enabled`                                      | Require a password (requirepass). Disable only on a trusted, isolated network                                                                                                                            | `true`                  |
| `auth.password`                                     | Redis password. Generated randomly and preserved across upgrades if empty                                                                                                                                | `""`                    |
| `auth.existingSecret`                               | Name of existing secret to use for the Redis password                                                                                                                                                    | `""`                    |
| `auth.secretKeys.passwordKey`                       | Name of the key in the secret containing the password                                                                                                                                                    | `redis-password`        |
| `containerPorts.redis`                              | Redis container port                                                                                                                                                                                     | `6379`                  |
| `extraEnvVars`                                      | Array with extra environment variables to add to the Redis container                                                                                                                                     | `[]`                    |
| `livenessProbe.enabled`                             | Enable livenessProbe on Redis containers                                                                                                                                                                 | `true`                  |
| `livenessProbe.initialDelaySeconds`                 | Initial delay seconds for livenessProbe                                                                                                                                                                  | `30`                    |
| `livenessProbe.periodSeconds`                       | Period seconds for livenessProbe                                                                                                                                                                         | `10`                    |
| `livenessProbe.timeoutSeconds`                      | Timeout seconds for livenessProbe                                                                                                                                                                        | `5`                     |
| `livenessProbe.failureThreshold`                    | Failure threshold for livenessProbe                                                                                                                                                                      | `6`                     |
| `livenessProbe.successThreshold`                    | Success threshold for livenessProbe                                                                                                                                                                      | `1`                     |
| `readinessProbe.enabled`                            | Enable readinessProbe on Redis containers                                                                                                                                                                | `true`                  |
| `readinessProbe.initialDelaySeconds`                | Initial delay seconds for readinessProbe                                                                                                                                                                 | `5`                     |
| `readinessProbe.periodSeconds`                      | Period seconds for readinessProbe                                                                                                                                                                        | `10`                    |
| `readinessProbe.timeoutSeconds`                     | Timeout seconds for readinessProbe                                                                                                                                                                       | `5`                     |
| `readinessProbe.failureThreshold`                   | Failure threshold for readinessProbe                                                                                                                                                                     | `6`                     |
| `readinessProbe.successThreshold`                   | Success threshold for readinessProbe                                                                                                                                                                     | `1`                     |
| `resourcesPreset`                                   | Set container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge). This is ignored if resources is set (resources is recommended for production). | `nano`                  |
| `resources`                                         | Set container requests and limits for different resources like CPU or memory (essential for production workloads)                                                                                        | `{}`                    |
| `podSecurityContext.enabled`                        | Enabled Redis pods' Security Context                                                                                                                                                                     | `true`                  |
| `podSecurityContext.fsGroupChangePolicy`            | Set filesystem group change policy                                                                                                                                                                       | `Always`                |
| `podSecurityContext.fsGroup`                        | Set Redis pod's Security Context fsGroup                                                                                                                                                                 | `1000`                  |
| `containerSecurityContext.enabled`                  | Enabled Redis containers' Security Context                                                                                                                                                               | `true`                  |
| `containerSecurityContext.seLinuxOptions`           | Set SELinux options in container                                                                                                                                                                         | `{}`                    |
| `containerSecurityContext.runAsUser`                | Set Redis containers' Security Context runAsUser                                                                                                                                                         | `999`                   |
| `containerSecurityContext.runAsGroup`               | Set Redis containers' Security Context runAsGroup                                                                                                                                                        | `1000`                  |
| `containerSecurityContext.runAsNonRoot`             | Set Redis containers' Security Context runAsNonRoot                                                                                                                                                      | `true`                  |
| `containerSecurityContext.privileged`               | Set container's Security Context privileged                                                                                                                                                              | `false`                 |
| `containerSecurityContext.readOnlyRootFilesystem`   | Set container's Security Context readOnlyRootFilesystem                                                                                                                                                  | `true`                  |
| `containerSecurityContext.allowPrivilegeEscalation` | Set container's Security Context allowPrivilegeEscalation                                                                                                                                                | `false`                 |
| `containerSecurityContext.capabilities.drop`        | List of capabilities to be dropped                                                                                                                                                                       | `["ALL"]`               |
| `containerSecurityContext.seccompProfile.type`      | Set container's Security Context seccomp profile                                                                                                                                                         | `RuntimeDefault`        |
| `podLabels`                                         | Extra labels for Redis pods                                                                                                                                                                              | `{}`                    |
| `podAnnotations`                                    | Annotations for Redis pods                                                                                                                                                                               | `{}`                    |
| `nodeSelector`                                      | Node labels for Redis pods assignment                                                                                                                                                                    | `{}`                    |
| `tolerations`                                       | Tolerations for Redis pods assignment                                                                                                                                                                    | `[]`                    |
| `affinity`                                          | Affinity for Redis pods assignment                                                                                                                                                                       | `{}`                    |
| `priorityClassName`                                 | Redis pods' priorityClassName                                                                                                                                                                            | `""`                    |
| `terminationGracePeriodSeconds`                     | Seconds Redis pod needs to terminate gracefully                                                                                                                                                          | `""`                    |
| `updateStrategy.type`                               | Redis statefulset strategy type                                                                                                                                                                          | `RollingUpdate`         |
| `extraVolumes`                                      | Optionally specify extra list of additional volumes for the Redis pod                                                                                                                                    | `[]`                    |
| `extraVolumeMounts`                                 | Optionally specify extra list of additional volumeMounts for the Redis container                                                                                                                         | `[]`                    |

### Traffic Exposure Parameters

| Name                                    | Description                                                | Value       |
| --------------------------------------- | ---------------------------------------------------------- | ----------- |
| `service.type`                          | Redis service type                                         | `ClusterIP` |
| `service.ports.redis`                   | Redis service port                                         | `6379`      |
| `service.clusterIP`                     | Redis service Cluster IP                                   | `""`        |
| `service.annotations`                   | Additional custom annotations for the Redis service        | `{}`        |
| `networkPolicy.enabled`                 | Specifies whether a NetworkPolicy should be created        | `true`      |
| `networkPolicy.allowExternal`           | Don't require client label for connections                 | `false`     |
| `networkPolicy.extraIngress`            | Add extra ingress rules to the NetworkPolicy               | `[]`        |
| `networkPolicy.ingressNSMatchLabels`    | Labels to match to allow traffic from other namespaces     | `{}`        |
| `networkPolicy.ingressNSPodMatchLabels` | Pod labels to match to allow traffic from other namespaces | `{}`        |

### Persistence Parameters

| Name                        | Description                             | Value               |
| --------------------------- | --------------------------------------- | ------------------- |
| `persistence.enabled`       | Enable Redis data persistence using PVC | `true`              |
| `persistence.storageClass`  | PVC Storage Class for Redis volume      | `""`                |
| `persistence.accessModes`   | PVC Access Mode for Redis volume        | `["ReadWriteOnce"]` |
| `persistence.size`          | PVC Storage Request for Redis volume    | `1Gi`               |
| `persistence.existingClaim` | Name of an existing PVC to use          | `""`                |
| `persistence.annotations`   | Annotations for the PVC                 | `{}`                |
| `persistence.labels`        | Labels for the PVC                      | `{}`                |

### Other Parameters

| Name                          | Description                                                                                                                                          | Value   |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| `tests.enabled`               | Render the `helm test` hooks (checks that Redis answers through its Service)                                                                         | `true`  |
| `tests.networkPolicy.enabled` | Also check that the NetworkPolicy blocks pods that are not labelled as clients (needs a CNI that enforces NetworkPolicy and `networkPolicy.enabled`) | `false` |

## License

Chart code: Apache-2.0. Redis itself is released under the AGPL-3.0 (see the upstream project for details).
