# fsarch helm-charts

Helm charts for fsarch services.

## Charts

| Chart | Description |
| --- | --- |
| [`pdf-render-server`](charts/pdf-render-server) | PDF rendering service ([source](https://gitlab.com/fsarch-infrastructure/beesblog/pdf-render-server)) |

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
