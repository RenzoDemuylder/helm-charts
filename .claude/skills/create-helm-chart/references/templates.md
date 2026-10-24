# Templates

One resource per file in `templates/`; file names: `deployment.yaml` (or `statefulset.yaml`), `service.yaml`,
`ingress.yaml`, `tls-secrets.yaml`, `secret.yaml`, `pvc.yaml`, `pdb.yaml`, `networkpolicy.yaml`,
`serviceaccount.yaml`, `extra-list.yaml`, `hpa.yaml` (if scalable), `NOTES.txt`, `_helpers.tpl`.
Sub-components (database) go in `templates/<component>/`. Copy from `charts/scrob/templates/`.

## Helpers to use (from `charts/common`)

| Need | Helper |
| ---- | ------ |
| names / namespace | `common.names.fullname`, `common.names.name`, `common.names.namespace` |
| metadata labels | `common.labels.standard (dict "customLabels" .Values.commonLabels "context" $)` |
| selectors (immutable!) | `common.labels.matchLabels (dict "customLabels" $podLabels "context" $)` + `app.kubernetes.io/component` |
| image string | `common.images.image (dict "imageRoot" .Values.image "global" .Values.global "chart" .Chart)` |
| pull secrets | `common.images.pullSecrets` (wrap in `<app>.imagePullSecrets`) |
| user templated values | `common.tplvalues.render (dict "value" X "context" $)`, `common.tplvalues.merge` |
| affinity presets | `common.affinities.pods`, `common.affinities.nodes` (see deployment.yaml in scrob) |
| resources preset | `common.resources.preset (dict "type" .Values.resourcesPreset)` |
| security context | `common.security.context (dict "secContext" X "context" $)` (OpenShift aware) |
| storage class | `common.storage.class (dict "persistence" .Values.persistence "global" .Values.global)` |
| API versions | hardcode (`apps/v1`, `networking.k8s.io/v1`, `policy/v1`); charts require Kubernetes >= 1.25 |
| generated secrets | `common.secrets.generate` (see scrob `secret.yaml`) |
| warnings in NOTES | `common.warnings.rollingTag` |

## Patterns

- **Components**: every resource carries `app.kubernetes.io/component: <app|postgresql|...>`; selectors include it so
  the app and its database never select each other.
- **Env**: scalar settings as `value:` (quoted with `| quote`), secrets via `secretKeyRef`. Optional feature blocks
  (`{{- if .Values.oidc.enabled }}`) emit env only when enabled so upstream defaults apply otherwise.
  End with `extraEnvVars` and `envFrom` (`extraEnvVarsCM`, `extraEnvVarsSecret`).
- **Probes**: render `omit .Values.<probe> "enabled"` through `common.tplvalues.render` and append the handler
  (`httpGet`/`exec`/`tcpSocket`) after it; honour `custom*Probe` first; disable all three in `diagnosticMode`.
- **diagnosticMode**: replaces `command`/`args` with `sleep infinity`, removes probes (see scrob deployment).
- **Checksums**: add `checksum/secret` (and `checksum/configmap`) pod annotations so config changes roll pods.
- **Persistence**: PVC created only when `persistence.enabled` and no `existingClaim`; volume falls back to `emptyDir`
  when disabled. Writable paths on a read-only root FS get an `emptyDir` volume (`/tmp`, runtime dirs).
- **Secrets**: `secret.yaml` renders only when `existingSecret` is empty; generated values use
  `common.secrets.generate` with the secret name + key and the `provided` value.
- **Validation**: add `<app>.validateValues.*` helpers in `_helpers.tpl` that `fail` with a clear message for invalid
  combinations (no database configured, replicas > 1 for single-instance apps); include from the main workload.
- **NetworkPolicy**: ingress limited to the container port; `allowExternal=false` requires the
  `<fullname>-client: "true"` pod label; `allowExternalEgress=true` by default. DB gets its own policy
  admitting only app pods.
- **PostgreSQL**: never bundle a StatefulSet in an app chart; depend on `charts/postgresql`
  (`dependencies: {name: postgresql, repository: file://../postgresql, version: 0.x.x, condition: postgresql.enabled}`).
  The subchart owns the StatefulSet, Service, Secret, NetworkPolicy and its helm tests. In the app chart:
  - subchart resource names come from `common.names.dependency.fullname` (`dict "chartName" "postgresql" "chartValues" .Values.postgresql "context" $`),
    wrapped in an `<app>.postgresql.fullname` helper; host, secret name and key are derived from it;
  - label the app pods `<postgresql fullname>-client: "true"` when `postgresql.enabled`, so the subchart NetworkPolicy
    (`allowExternal: false`) admits them; strict egress selects `app.kubernetes.io/{name: postgresql,instance: <release>,component: postgresql}`;
  - the `wait-for-db` init container has its own `waitForDatabase.image.*` (needs `pg_isready`), so it also works with
    CloudNativePG or an external database when the subchart is disabled.
- **Helm test hooks** (`templates/tests/*.yaml`): `Pod` with `helm.sh/hook: test` and
  `hook-delete-policy: before-hook-creation,hook-succeeded`, label `app.kubernetes.io/component: test` (so no selector
  matches it), `automountServiceAccountToken: false`, `nano` resources preset, the `<fullname>-client: "true"` label on
  pods that must reach the app through a strict NetworkPolicy. The health test goes through the Service DNS name, not
  the pod IP or loopback. Gate optional checks on the values that make them meaningful (see scrob `networkpolicy-deny.yaml`).
- **ci values** (`ci/<case>-values.yaml`, file name = case name): small `resourcesPreset`s so runners cope; one file per
  permutation of the database mode and exposure options. Each case installs into its own namespace, so throwaway
  dependencies deployed with `extraDeploy` can use fixed names. Chart values are not templated by default, so
  `externalDatabase.host` cannot contain `{{ .Release.Name }}`.
- **NOTES.txt**: how to reach the app (ingress / NodePort / LoadBalancer / port-forward), first-run hints, warnings
  for risky settings, then the `common.warnings.*` includes at the end.

## Gotchas

- `.helmignore` must not contain `*.tgz` (breaks `file://` dependencies).
- Never change selector labels after release (immutable); bump the chart major if unavoidable.
- `lookup` returns nothing under `helm template`; generated secrets differ per render, so never assert on them in tests.
- helm-unittest only renders the templates listed in the suite's `templates:`. A template that `include`s another one
  (the deployment's `checksum/secret` includes `secret.yaml`) needs that file listed too, plus `template:` on each test
  so assertions hit the intended document.
- Busybox `nslookup` ignores the pod's search domains: use the fully qualified `<svc>.<ns>.svc.<clusterDomain>` in test
  scripts. Alpine/busybox images have `wget`, `nc -z -w` and `nslookup`; do not assume `curl`.
- A test that must fail when a feature breaks needs a control: temporarily add an allow-all NetworkPolicy (policies are
  additive) or similar and check the test goes red. Disabling the feature may simply un-render the test.
- Quote everything that can be numeric/boolean in env (`| quote`), Kubernetes env values must be strings.
- With `Recreate` + RWO PVC do not use `RollingUpdate` (the new pod cannot mount the volume).
- `fsGroup` handles volume ownership; do not add a root `volumePermissions` init container unless the storage backend ignores fsGroup.
