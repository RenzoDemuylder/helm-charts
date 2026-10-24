# values.yaml conventions

Copy `charts/scrob/values.yaml` as the skeleton. Order of sections (use `## @section` headers exactly like this):

1. **Global parameters**: `global.imageRegistry`, `global.imagePullSecrets`, `global.defaultStorageClass`,
   `global.storageClass` (deprecated alias), `global.compatibility.openshift.adaptSecurityContext: auto`.
2. **Common parameters**: `nameOverride`, `fullnameOverride`, `namespaceOverride`, `commonLabels`,
   `commonAnnotations`, `clusterDomain`, `extraDeploy`, `diagnosticMode.{enabled,command,args}`.
3. **`<App> parameters`**, in this order:
   `image.*`; app configuration (grouped by feature, e.g. `oidc.*`, `smtp.*`); `existingSecret`;
   `command`, `args`, `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`; `replicaCount`; `containerPorts.*`;
   `livenessProbe`/`readinessProbe`/`startupProbe` (+ `enabled`, `initialDelaySeconds`, `periodSeconds`,
   `timeoutSeconds`, `failureThreshold`, `successThreshold`) and `customLivenessProbe`/`customReadinessProbe`/`customStartupProbe`;
   `resourcesPreset` + `resources`; `podSecurityContext`; `containerSecurityContext`; `automountServiceAccountToken`;
   `hostAliases`; `podLabels`; `podAnnotations`; `podAffinityPreset`; `podAntiAffinityPreset`; `nodeAffinityPreset.*`;
   `affinity`; `nodeSelector`; `tolerations`; `topologySpreadConstraints`; `schedulerName`; `priorityClassName`;
   `terminationGracePeriodSeconds`; `lifecycleHooks`; `updateStrategy`; `extraVolumes`; `extraVolumeMounts`;
   `sidecars`; `initContainers`; `pdb.{create,minAvailable,maxUnavailable}`; optional `autoscaling.hpa.*`.
4. **Traffic Exposure Parameters**: `service.*` (`type`, `ports.http`, `nodePorts.http`, `clusterIP`,
   `loadBalancerIP`, `loadBalancerSourceRanges`, `externalTrafficPolicy`, `annotations`, `extraPorts`,
   `sessionAffinity`, `sessionAffinityConfig`), `ingress.*` (`enabled`, `pathType`, `apiVersion`, `hostname`,
   `ingressClassName`, `path`, `annotations`, `tls`, `extraHosts`, `extraPaths`, `extraTls`, `secrets`, `extraRules`),
   `networkPolicy.*` (`enabled`, `allowExternal`, `allowExternalEgress`, `extraIngress`, `extraEgress`,
   `ingressNSMatchLabels`, `ingressNSPodMatchLabels`).
5. **Persistence Parameters**: `persistence.{enabled,storageClass,annotations,labels,accessModes,size,existingClaim,selector,dataSource}`.
6. **Other Parameters**: `serviceAccount.{create,name,annotations,automountServiceAccountToken}`, `rbac.*` if needed,
   `tests.enabled` (health `helm test` hook, default `true`) and `tests.networkPolicy.enabled` (default `false`: it needs
   a CNI that enforces NetworkPolicy; the `ci` values switch it on).
7. **Database parameters** (only if the app needs one): `<db>.enabled` (in-chart StatefulSet, same sub-layout as the app:
   `image`, `auth.*`, probes, `resourcesPreset`, security contexts, `service`, `persistence`, `networkPolicy`)
   `cnpg.*` (optional CloudNativePG `Cluster`: `enabled`, `instances`, `imageName`, `storage`, `resourcesPreset`/`resources`, `annotations`, `extraSpec`; mutually exclusive with `<db>.enabled`), and `externalDatabase.{host,port,user,password,database,existingSecret,existingSecretKeys.{host,port,user,password,database}}` (secret keys let users plug in operator-generated Secrets such as CloudNativePG `<cluster>-app`).

## Annotations (readme-generator-for-helm)

Each key is documented with a comment block directly above it:

```yaml
## @section Scrob parameters           # starts a README table section
## @param replicaCount Number of replicas      # documented key (dot path from root)
## @param image.tag ...                         # one @param per leaf
## @skip image.tag Description                  # keep out of the table (use for the image tag so docs stay stable)
## @param foo [object] ...                      # type hints: [array] [object] [string] [nullable] [default: X]
```

- Document nested keys by full path (`containerSecurityContext.capabilities.drop`), not the parent object.
- Empty `{}`/`[]` defaults are fine with no hint; non-empty maps/lists need `[object]`/`[array]` or per-leaf params.
- Generate: `npx @bitnami/readme-generator-for-helm --values charts/<name>/values.yaml --readme charts/<name>/README.md`.
  It rewrites tables under `### <section>` headings that exist in the README, so list every `@section` title as an
  empty `###` heading under `## Parameters` first.
- Comment style: a `##` prefix, a trailing `##` line, links to the upstream docs where useful (see scrob).

## Secure defaults (copy verbatim, change UID/GID only)

```yaml
podSecurityContext:
  enabled: true
  fsGroupChangePolicy: Always
  sysctls: []
  supplementalGroups: []
  fsGroup: 1000
containerSecurityContext:
  enabled: true
  seLinuxOptions: {}
  runAsUser: 1000
  runAsGroup: 1000
  runAsNonRoot: true
  privileged: false
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: "RuntimeDefault"
```

`resourcesPreset` is one of `none nano micro small medium large xlarge` (see `charts/common/templates/_resources.tpl`).
Default to the smallest preset that boots the app comfortably; `resources` overrides it.

## Naming rules

- Camel case keys; booleans named by what they turn on (`enabled`, `create`), never negated (`disableX` only when mirroring upstream).
- App settings mirror upstream env var names in meaning, grouped by feature (`SMTP_ADDRESS` -> `smtp.host`);
  note the env var in the `@param` description when the mapping is not obvious.
- Secret values live next to their feature (`oidc.clientSecret`) and are written into the chart Secret under a
  kebab-case key (`oidc-client-secret`), documented under `existingSecret`.
- Ports: `containerPorts.http`, `service.ports.http`. Add one key per extra port.
