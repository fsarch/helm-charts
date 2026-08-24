# fsarch helm-charts

Helm charts for fsarch services.

## Charts

| Chart | Description |
| --- | --- |
| [`fsarch-common`](charts/fsarch-common) | Library chart with the shared Deployment/Service/ServiceAccount/Namespace/Ingress schema used by (most) fsarch application charts. Not deployable on its own. |
| [`pdf-render-server`](charts/pdf-render-server) | PDF rendering service ([source](https://gitlab.com/fsarch-infrastructure/beesblog/pdf-render-server)) |
| [`metric-server`](charts/metric-server) | Metrics storage/query service ([source](https://github.com/fsarch/metric-server)) |
| [`image-server`](charts/image-server) | Image resizing/caching service ([source](https://github.com/michael-braun/image-server)) |
| [`frontend-server`](charts/frontend-server) | Authenticated file-storage/serving service ([source](https://github.com/fsarch/frontend-server)) |
| [`dashboard`](charts/dashboard) | Next.js frontend federating fsarch backend services behind one authenticated UI ([source](https://github.com/fsarch/dashboard)) |
| [`function-server`](charts/function-server) | Worker-function dispatch service ([source](https://github.com/fsarch/function-server)) |
| [`function-node-worker`](charts/function-node-worker) | Node.js worker that executes functions dispatched by `function-server` ([source](https://github.com/fsarch/function-node-worker)) |
| [`function-gateway`](charts/function-gateway) | Manages and executes remote functions via worker servers ([source](https://github.com/fsarch/function-gateway)) |
| [`frontier-server`](charts/frontier-server) | Config/management API for frontier-worker fleets (monorepo app apps/frontier-api, published as fsarch/frontier-server; [source](https://github.com/fsarch/frontier-server)) |
| [`frontier-worker`](charts/frontier-worker) | HTTP proxy worker driven by frontier-server's control plane ([source](https://github.com/fsarch/frontier-server)) |
| [`material-tracing-server`](charts/material-tracing-server) | Material/parts traceability service ([source](https://github.com/fsarch/material-tracing-server)) |
| [`product-server`](charts/product-server) | Product catalog service ([source](https://github.com/fsarch/product-server)) |

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

Once published (see below), add the repo once and install from it like any
other Helm repo:

```sh
helm repo add fsarch https://fsarch.github.io/helm-charts
helm repo update
helm install <release-name> fsarch/<chart-name> \
  --namespace <namespace> --create-namespace \
  --values my-values.yaml
```

For local development against a checkout of this repo, install straight from
the chart directory instead:

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

## Releasing / publishing

Charts are published to a classic Helm repo served via GitHub Pages, using
[`helm/chart-releaser-action`](https://github.com/helm/chart-releaser-action)
(`.github/workflows/release-charts.yaml`, configured via `cr.yaml`). On every
push to `main` that touches `charts/**`, it packages each chart whose
`Chart.yaml` `version` hasn't been released yet, attaches the `.tgz` to a
GitHub Release, and updates `index.yaml` on the `gh-pages` branch.

**One-time setup** (not yet done for this repo):

1. Push this repo to `origin` (`git push -u origin main`).
2. In GitHub repo Settings → Actions → General → Workflow permissions, make
   sure "Read and write permissions" is selected (needed for the action to
   push the `gh-pages` branch and create releases via the default
   `GITHUB_TOKEN`).
3. Push once so the workflow runs and creates the `gh-pages` branch.
4. In GitHub repo Settings → Pages, set Source to "Deploy from a branch" and
   pick the `gh-pages` branch, `/ (root)` folder. The repo then becomes
   reachable at `https://fsarch.github.io/helm-charts`.

**Every release after that**: bump `version:` in the chart's `Chart.yaml`
(and `appVersion:` if the app image changed) and push/merge to `main` - the
workflow does the rest. Chart versions are immutable once released; a
version that was already published is skipped, not overwritten.
