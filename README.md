# helm-charts

Helm charts for open source software, written in the style of Bitnami charts (layout and naming conventions only) with a consistent
`values.yaml` layout (`global`, common parameters, app parameters, traffic exposure, persistence, ...).
Charts are published as OCI artifacts to GHCR.

| Chart | App | Description |
| ----- | --- | ----------- |
| [scrob](charts/scrob) | [ellite/scrob](https://github.com/ellite/scrob) | Self-hosted media tracker |
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

## License

Apache-2.0 (see `LICENSE`). Each packaged application keeps its own license.
