# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A monorepo of Helm charts for fsarch services, published as a classic Helm
chart repo served via GitHub Pages (`https://fsarch.github.io/helm-charts`).
Charts live under `charts/<name>/`.

## Commands

```sh
helm lint charts/pdf-render-server              # lint a chart
helm template charts/pdf-render-server           # render manifests locally
helm template pdf-render-server charts/pdf-render-server --set key=value   # render with overrides
helm upgrade --install <release> ./charts/<chart> --namespace <ns> --create-namespace --values my-values.yaml   # install from a local checkout
```

There is no build/test suite beyond `helm lint`/`helm template` - use those
(with representative `--set` overrides for the thing you changed) to verify
template changes render as expected.

## Architecture

### `fsarch-common`: shared library chart

`charts/fsarch-common` (`type: library`) holds the Deployment / Service /
ServiceAccount / Namespace / Ingress / NOTES schema shared by (most) fsarch
application charts, as named templates (`fsarch-common.*`) in
`templates/_*.tpl`. It produces no manifests on its own.

Consuming charts (e.g. `charts/pdf-render-server`) wire it up as a `type:
application` chart with thin wrapper templates, e.g.
`templates/deployment.yaml` is just `{{ include "fsarch-common.deployment" .
}}`. The named templates read directly from the **calling chart's own**
`.Values` (they're `include`d with `.`, not scoped as a subchart) - so a new
consuming chart must implement the values contract documented in
`charts/fsarch-common/README.md` in its own `values.yaml`. Anything
app-specific (e.g. `pdf-render-server`'s `templates/configmap.yaml`, which
renders `config.yml`) stays in the consuming chart; it reuses
`fsarch-common.configMapName` / `.namespace` / `.labels` helpers so it lines
up with what `fsarch-common.deployment` mounts.

**Dependency wiring**: `pdf-render-server/Chart.yaml` declares `fsarch-common`
under `dependencies:`, but it is **not** vendored via `helm dependency
update`. Instead, `charts/pdf-render-server/charts/fsarch-common` is a
checked-in relative symlink to `../../fsarch-common`, so edits to the shared
chart apply to every consumer immediately with one file tree to keep in
sync. `helm template`/`lint`/`package`/`install` all resolve the symlink
transparently (verified: `helm package` embeds the resolved contents, so
packaged charts are still self-contained). When adding a new chart that
depends on `fsarch-common`, replicate this symlink rather than running `helm
dependency update` (that would overwrite it with a real vendored copy).

### `pdf-render-server`: example consumer

`charts/pdf-render-server` mirrors the raw k8s manifests originally in
`gitlab.com/fsarch-infrastructure/beesblog/pdf-render-server`. Notable
non-obvious bit: `templates/configmap.yaml` renders `config.yml`'s `auth:`
section from `config.auth.type`, which selects between two **mutually
exclusive** upstream schemas - only the field(s) for the active type are
rendered:
- `type: jwt-jwk` → renders `auth.jwkUrl`
- `type: oidc` → renders `auth.discovery_url` (snake_case; note the
  mismatch with the chart's own camelCase `config.auth.discoveryUrl` value)

### Adding a new service chart

Full walkthrough with the exact template names: `charts/fsarch-common/README.md`
("Using it in a new chart"). Short version, using `pdf-render-server` as the
reference example to copy from:

1. `mkdir -p charts/<name>/templates`, add a `Chart.yaml` (`type:
   application`) with a `fsarch-common` entry under `dependencies:` (copy
   `charts/pdf-render-server/Chart.yaml`'s).
2. Symlink the shared chart in rather than vendoring it:
   `ln -s ../../fsarch-common charts/<name>/charts/fsarch-common`.
3. Write `values.yaml` implementing the values contract from
   `charts/fsarch-common/README.md` (copy `charts/pdf-render-server/values.yaml`
   as a starting point and adjust image/env/config for the new service).
4. Add thin wrapper templates that just `include` the shared ones -
   `deployment.yaml`, `service.yaml`, `serviceaccount.yaml`, `namespace.yaml`,
   `ingress.yaml`, `NOTES.txt` (see `charts/pdf-render-server/templates/` for
   the exact one-liners and which `fsarch-common.*` template name each maps
   to). Only add real logic to `templates/` for things that are actually
   app-specific (e.g. a ConfigMap with app-specific content, as
   `pdf-render-server/templates/configmap.yaml` does).
5. Verify with `helm lint charts/<name>` and `helm template
   charts/<name>` (plus a few `--set` overrides touching the new bits).
6. Add the chart to the table in the root `README.md`.
7. Give it its own `version:`/`appVersion:` in `Chart.yaml`; it gets released
   independently by `release-charts.yaml` the next time `main` changes under
   `charts/<name>/**` (see below) - no changes needed to that workflow itself.

If the new service should also auto-bump on its own app repo's releases like
`pdf-render-server` and `metric-server` do, no changes are needed here -
`bump-chart.yaml` is generic across every chart (see below). Just make the
new app repo's image-build workflow send a `repository_dispatch` with
`event_type: "<name>-released"` and `client_payload: {"version": "..."}` on
stable release tags, using the `HELM_CHARTS_DISPATCH_TOKEN` secret (copy
`metric-server`'s `.github/workflows/image.yml` "notify helm-charts of the
new release" step).

### CI/CD: release pipeline

Two workflows in `.github/workflows/`:

- **`release-charts.yaml`** ("Release Charts"): on push to `main` touching
  `charts/**` (or manual `workflow_dispatch`), runs
  `helm/chart-releaser-action` (config in `cr.yaml`) to package any chart
  whose `Chart.yaml` `version` hasn't been released yet, attach the `.tgz`
  to a GitHub Release, and update `index.yaml` on the `gh-pages` branch.
  Chart versions are immutable once released - bump `version:` (and
  `appVersion:` if the app image changed) to publish again.

- **`bump-chart.yaml`**: generic across every chart in this repo - listens
  for **any** `repository_dispatch` event (no `types:` filter; GitHub
  matches every custom `event_type` when it's omitted) sent by an fsarch app
  repo's image-build workflow on stable, non-prerelease release tags, via a
  `HELM_CHARTS_DISPATCH_TOKEN` secret there (e.g.
  `fsarch/pdf-render-server`, `fsarch/metric-server` - see the latter's
  `.github/workflows/image.yml` for the sending side). It derives the chart
  to bump from the event type itself, by convention `<chart-name>-released`
  (e.g. `metric-server-released` → `charts/metric-server`), bumps that
  chart's `Chart.yaml` `version`/`appVersion` to `client_payload.version`,
  and pushes to `main`. Onboarding a new chart to this needs **no edit here**
  - only the new app repo's dispatch call, following the naming convention.

**Two gotchas baked into this pipeline, worth knowing before touching either
workflow:**

1. A push made with a workflow's own `GITHUB_TOKEN` does **not** trigger
   other workflows' `push` events (GitHub's anti-recursion safeguard). So
   `bump-chart.yaml` can't just rely on its push to fire
   `release-charts.yaml` - it explicitly dispatches it via the REST API
   (`.../actions/workflows/release-charts.yaml/dispatches`) after a
   successful push, which is why `release-charts.yaml` also declares
   `workflow_dispatch:` as a trigger.
2. `cr index --push` (inside chart-releaser) stages the generated
   `index.yaml` with `git add` **in the current checkout** (i.e. whatever
   commit triggered the workflow on `main`) before folding it into the
   `gh-pages` branch - it does not use an isolated `gh-pages` worktree for
   this step. That means `index.yaml` must not be gitignored on `main`, or
   `cr` fails with "paths are ignored by one of your .gitignore files".

The `gh-pages` branch itself should only ever contain what `cr` puts there
(chart `index.yaml`); it is not meant to mirror `main`.
