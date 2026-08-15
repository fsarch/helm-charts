# fsarch helm-charts

Helm charts for fsarch services.

## Charts

| Chart | Description |
| --- | --- |
| [`fsarch-common`](charts/fsarch-common) | Library chart with the shared Deployment/Service/ServiceAccount/Namespace/Ingress schema used by (most) fsarch application charts. Not deployable on its own. |
| [`pdf-render-server`](charts/pdf-render-server) | PDF rendering service ([source](https://gitlab.com/fsarch-infrastructure/beesblog/pdf-render-server)) |

New application charts should build on `fsarch-common` rather than duplicating
its Deployment/Service/etc. templates - see
[`charts/fsarch-common/README.md`](charts/fsarch-common/README.md) for how to
wire a chart up to it, and `charts/pdf-render-server` for a working example.

Charts that depend on `fsarch-common` reference it via a relative symlink
under their own `charts/` directory (e.g.
`charts/pdf-render-server/charts/fsarch-common -> ../../fsarch-common`)
instead of `helm dependency update`-vendored copy, so edits to
`fsarch-common` apply to every consuming chart immediately, with one file
tree to keep in sync. `helm template`/`lint`/`package`/`install` all resolve
the symlink transparently.

## Usage

```sh
helm upgrade --install <release-name> ./charts/<chart-name> \
  --namespace <namespace> --create-namespace \
  --values my-values.yaml
```

See each chart's own `README.md` for its configurable values.

## Linting

```sh
helm lint charts/pdf-render-server
helm template charts/pdf-render-server
```
