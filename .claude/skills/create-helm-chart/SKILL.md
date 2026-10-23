---
name: create-helm-chart
description: Create or modify a Helm chart in this repository in the style of Bitnami charts, without copying them (consistent values.yaml layout, common library chart, secure defaults, generated README). Use when adding a new chart for an open source application, adding features to an existing chart, or reviewing a chart for consistency.
---

# Creating a Helm chart (Bitnami style)

Every chart in `charts/` must look the same to a user: same `values.yaml` sections, same key names for the
same concept, same template structure. `charts/scrob` is the reference implementation: **open it and copy from it**
instead of writing from memory. `charts/common` is the shared library chart: our own small implementation (not a copy of `bitnami/common`),
e.g. `common.names.fullname`, `common.labels.standard`. Extend it when a second chart needs a helper; keep it minimal and
document each helper in the comment above it. Do not paste code from Bitnami or other charts.

Detailed references (read the one you need):
- `references/values-conventions.md` - values.yaml section order, key names, `@param` annotations, secure defaults
- `references/templates.md` - template files, which `common.*` helper to use, patterns and gotchas
- `references/checklist.md` - validation commands and the pre-merge checklist

## Workflow

1. **Research upstream** before writing anything (use `gh api`, the upstream Dockerfile, compose file, docs). Record:
   official image (registry, repo, latest immutable tag, multi-arch?), UID/GID, ports, every env var (mark secrets),
   persistent paths, required services (database, redis...), health endpoints, whether it needs root or a writable
   root filesystem, license, icon URL. Check whether health endpoints are reachable from outside the pod
   (an app listening on 127.0.0.1 needs an `exec` probe).
2. **Prove the security context in Docker** before committing to it:
   `docker run --user <uid>:<gid> --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges ...`.
   Add emptyDir mounts for each path that must be writable. If the entrypoint needs root (chown, su-exec),
   bypass it with `command`/`args` in values and use `fsGroup` for volume ownership. Only fall back to
   `runAsNonRoot: false` / writable root FS when proven impossible, and say so in the values comments and README.
3. **Scaffold** `charts/<name>/` by copying the layout of `charts/scrob` (Chart.yaml, .helmignore, values.yaml,
   README.md, templates/). Do not use `helm create`. Rename, strip what the app does not need (e.g. postgresql
   subtree), keep the section order of values.yaml.
4. **Write values.yaml first**, then templates that consume it. Every key has a `## @param` annotation.
5. **Dependencies**: `common` via `repository: file://../common`, `version: 1.x.x`. Run `helm dependency update charts/<name>`.
   Never list `*.tgz` in `.helmignore` (Helm then ignores `charts/common-*.tgz` and reports the dependency as missing).
6. **Validate** with everything in `references/checklist.md`: lint --strict, template permutations, kubeconform,
   readme generation, and a Docker smoke test of the image.
7. **Register**: add the chart to the table in the root `README.md`; bump `version` in `Chart.yaml`
   (patch for fixes, minor for new values, major for breaking value changes; `appVersion` = upstream tag).

## Non-negotiables

- One chart = one primary workload. Databases the app needs are an in-chart optional StatefulSet
  (`postgresql.enabled`) plus `externalDatabase.*`; do not depend on Bitnami subcharts or images.
- Image values are always `image.registry/repository/tag/digest/pullPolicy/pullSecrets`, rendered with
  `common.images.image`. Pin an immutable tag (never `latest`); `appVersion` mirrors it.
- Secrets: never put generated or user secrets in a ConfigMap or plain env value. Support `existingSecret`,
  auto-generate with `common.secrets.generate` (survives upgrades via `lookup`), and read them with `secretKeyRef`.
  Do not interpolate passwords into URLs when the app accepts separate variables.
- Secure by default: non-root, `readOnlyRootFilesystem: true` + emptyDir mounts, drop ALL capabilities,
  `seccompProfile: RuntimeDefault`, `allowPrivilegeEscalation: false`, `automountServiceAccountToken: false`.
- Everything user-extensible uses the Bitnami-style hook names (the style we follow): `extraEnvVars`, `extraEnvVarsCM`, `extraEnvVarsSecret`,
  `extraVolumes`, `extraVolumeMounts`, `sidecars`, `initContainers`, `extraDeploy`, `podLabels`, `podAnnotations`,
  `commonLabels`, `commonAnnotations`, `affinity` + presets, `nodeSelector`, `tolerations`, `topologySpreadConstraints`.
- Stateful single-instance apps: `replicas` 1, `updateStrategy.type: Recreate` for Deployments with RWO PVCs, and a
  `scrob.validateValues`-style helper that fails on `replicaCount > 1`.
- `README.md` parameter tables are **generated** from the `@param` comments; never hand edit between the
  `## Parameters` section headers. Chart.yaml `home`/`sources`/`maintainers` point at `github.com/RenzoDemuylder/helm-charts`.
- Do not invent values keys that already have a convention (e.g. use `persistence.size`, not `storage.capacity`;
  `service.ports.http`, not `service.port`; `ingress.hostname`, not `ingress.host`).
