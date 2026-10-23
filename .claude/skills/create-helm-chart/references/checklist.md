# Validation and checklist

Run from the repo root. `helm` is Helm 4 locally; keep charts compatible with Helm 3.8+.

```console
helm dependency update charts/<name>
helm lint --strict charts/<name>

# permutations (each must render): defaults, external database / existingSecret, ingress + tls,
# every optional feature block enabled, diagnosticMode, persistence disabled, networkPolicy strict
helm template t charts/<name> > /tmp/default.yaml
helm template t charts/<name> --set <...> > /tmp/<case>.yaml
# invalid combos must fail with the validateValues message
helm template t charts/<name> --set replicaCount=2

# schema validation of rendered manifests
docker run --rm -v /tmp:/d ghcr.io/yannh/kubeconform:latest -strict -summary -ignore-missing-schemas /d/default.yaml /d/<case>.yaml

# README tables (idempotent: running twice must not change the file)
npx --yes @bitnami/readme-generator-for-helm --values charts/<name>/values.yaml --readme charts/<name>/README.md
```

Smoke-test the real image with the exact security context the chart sets, against throwaway dependencies:

```console
docker run --user <uid>:<gid> --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges \
  -e ... --entrypoint sh <image> -c '<chart command>'
```

Check logs for permission errors and hit the health endpoint(s) with `docker exec`. Clean up containers, networks, volumes.
If a Kubernetes cluster is reachable, also `helm install` it (kind in CI: `ct install`).

## Checklist

- [ ] values.yaml follows `values-conventions.md` section order; every key has `@param`/`@skip`
- [ ] No secret in ConfigMap/plain env; `existingSecret` supported; generated secrets stable across upgrades
- [ ] Image tag pinned and equals `appVersion`; `Chart.yaml` has `annotations.images`, `licenses`, `category`, `icon`, `sources`, `kubeVersion`
- [ ] Non-root, read-only root FS, caps dropped, seccomp RuntimeDefault (proven with Docker smoke test)
- [ ] Probes match real health endpoints (exec when the endpoint is loopback-only)
- [ ] Persistence + `Recreate`/StatefulSet semantics correct; `replicaCount` validated for single-instance apps
- [ ] `diagnosticMode`, `extra*`, `sidecars`, `initContainers`, `extraDeploy` all wired
- [ ] `NOTES.txt` useful; README has TL;DR, install, secrets, external DB, app-specific sections, generated Parameters
- [ ] Chart `version` bumped; root README table updated; `helm lint --strict` clean; CI (`ct lint`) config still valid
