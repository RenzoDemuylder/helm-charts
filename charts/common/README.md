# common

Library chart (`type: library`) with the template helpers shared by the charts in this repository.
Written for this repository and kept deliberately small: it contains only what the charts here use, with the
`common.<area>.<name>` naming style.

| Helper | Purpose |
| ------ | ------- |
| `common.names.{name,fullname,namespace,chart}` | resource and label names, honouring the `*Override` values |
| `common.labels.{standard,matchLabels}` | metadata labels and immutable selector labels |
| `common.images.{image,pullSecrets}` | image reference (global registry, tag/digest) and `imagePullSecrets` block |
| `common.tplvalues.{render,merge}` | evaluate values containing template expressions, merge maps |
| `common.affinities.{pods,nodes}` | `soft`/`hard` affinity presets |
| `common.resources.preset` | `nano`..`xlarge` requests/limits |
| `common.security.context` | pod/container securityContext (OpenShift aware) |
| `common.storage.class` | `storageClassName` line honouring the global settings |
| `common.secrets.generate` | Secret value that survives upgrades (lookup, provided value, random) |
| `common.warnings.rollingTag` | NOTES.txt warning for mutable tags |

Each helper documents its arguments in the comment above its definition (`templates/_*.tpl`).

Use it from a chart:

```yaml
dependencies:
  - name: common
    repository: file://../common
    version: 1.x.x
```
