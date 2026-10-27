# helm-charts

Helm charts for open source software, written in the style of Bitnami charts (layout and naming conventions only) with a consistent
`values.yaml` layout (`global`, common parameters, app parameters, traffic exposure, persistence, ...).
Charts are published as OCI artifacts to GHCR.

| Chart | App | Description |
| ----- | --- | ----------- |
| [scrob](charts/scrob) | [ellite/scrob](https://github.com/ellite/scrob) | Self-hosted media tracker |
| [navidrome](charts/navidrome) | [navidrome/navidrome](https://github.com/navidrome/navidrome) | Self-hosted music server |
| [postgresql](charts/postgresql) | [PostgreSQL](https://www.postgresql.org/) | Single-instance PostgreSQL, standalone or as a dependency of other charts |
| [common](charts/common) | - | Library chart with shared helpers (own helpers) |

## Usage

```console
helm install my-scrob oci://ghcr.io/renzodemuylder/charts/scrob
```

## Development

```console
helm dependency build charts/scrob
helm lint --strict charts/scrob
helm template test charts/scrob
npx @bitnami/readme-generator-for-helm --values charts/scrob/values.yaml --readme charts/scrob/README.md
```

See `.claude/skills/create-helm-chart/SKILL.md` for the conventions when adding a chart.

## Testing

Everything runs through one `Makefile`, locally and in CI. Needs `helm` and `docker`; the other tools run from pinned
container images. `make e2e` additionally needs `kind` and `kubectl`.

| Command | What it checks |
| ------- | -------------- |
| `make lint` | `helm lint --strict` with the defaults and with every `charts/*/ci/*-values.yaml` |
| `make unit` | [helm-unittest](https://github.com/helm-unittest/helm-unittest) suites in `charts/*/tests` (database modes, validation errors, NetworkPolicy shape, stable selectors) |
| `make schema` | [kubeconform](https://github.com/yannh/kubeconform) `-strict` on the rendered manifests, CRDs (CloudNativePG) validated against the [CRDs catalog](https://github.com/datreeio/CRDs-catalog) |
| `make policy` | [Kyverno](https://kyverno.io) CLI applies the house style in `test/policies` (restricted security contexts, labels, resources, pinned images, `Recreate` for PVC-backed Deployments) to every rendered permutation |
| `make test` | all of the above |
| `make e2e` | creates a hardened [kind](https://kind.sigs.k8s.io) cluster (PodSecurity `restricted` enforced, NetworkPolicy enforced, CloudNativePG operator), installs every `ci/*-values.yaml` permutation of every chart, runs `helm test`, then upgrades from the last published release |

`make e2e E2E_CHARTS=scrob` narrows the run, `KEEP=1 make e2e` keeps the failed namespaces for debugging and
`make cluster-delete` removes the cluster. A new chart gets the policy checks for free; it only has to ship `tests/`,
`ci/` and `templates/tests/` (copy them from `charts/scrob`).

## License

Apache-2.0 (see `LICENSE`). Each packaged application keeps its own license.
