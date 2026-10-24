# helm-charts

Public repository of Helm charts for open source software, written in the style of Bitnami charts
(layout and naming only, no copied code) with one consistent values layout across all charts.

- Adding or changing a chart: follow the `create-helm-chart` skill (`.claude/skills/create-helm-chart/SKILL.md`).
- `charts/common` is the shared library chart (our own helpers). Charts depend on it via `file://../common`.
- `charts/postgresql` is the shared database chart: application charts depend on it (`file://../postgresql`, `condition: postgresql.enabled`) instead of bundling a StatefulSet.
- `charts/scrob` is the reference chart: copy its structure and values layout.
- GitHub owner is `RenzoDemuylder` (repo `RenzoDemuylder/helm-charts`); charts are published to `oci://ghcr.io/renzodemuylder/charts`.
