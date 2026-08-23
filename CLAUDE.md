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

### `config.yml` patterns across consumer charts

Most consumer charts (`metric-server`, `frontend-server`, `function-server`,
`function-gateway`, `frontier-server`, `material-tracing-server`, ...) are
built on the shared `@fsarch/server` NestJS framework, which gives every one
of them the same three config sections with the same mutually-exclusive
`type`-selected rendering as `pdf-render-server`'s `auth` above:
- `auth`: `jwt-jwk` (→ `jwkUrl`) / `oidc` (→ `discovery_url`) / `static` (→
  `secret` + `users`). Some apps' own local Joi validation narrows this to
  a subset (e.g. `frontend-server`/`function-node-worker` only accept
  `jwt-jwk`/`static`, no `oidc`) - check the app's `configuration.ts` or
  per-module `ModuleConfiguration.register(...)` validators, don't assume
  all three are accepted just because the framework supports them.
- `uac`: `static` (user id + permissions list) - no other type exists yet.
- `database`: `sqlite` (→ `database` file path) / `postgres`|`cockroachdb`
  (→ `host`/`port`/`database`/`username`/`password`/`ssl`). Some apps only
  accept a subset here too (`image-server` has no plain `postgres`, only
  `sqlite`/`cockroachdb`).

Beyond those three, apps have their own bespoke sections with no `type`
selector to branch on - too shaped-by-use-case for a bespoke values schema.
The convention here is a **freeform passthrough** value rendered verbatim
via `toYaml` (`image-server`'s `config.extra`, `function-server`'s
`config.worker.api`, `dashboard`'s `config.services`/`config.uac.mappings`,
`material-tracing-server`'s `config.customActions`) - default it to
something inert (`{}`/`[]`) rather than guessing at a real deployment's
values, and give a full worked example in the chart's README instead.

Every chart also has a `config.raw` value that bypasses all of the above
and is used verbatim as `config.yml` when non-empty - the universal escape
hatch, keep it on every new chart even once it has structured values for
everything else.

**Before modeling any section as a dedicated values key, verify the app's
own `src` actually reads it** - `grep` for
`ModuleConfiguration.register(...)`/`configService.get(...)` for that
top-level key. These app repos' checked-in example `config.yml`/
`config.template.yml` files get copy-pasted between services a lot, and
routinely carry sections nothing in that particular app's code ever reads
(dead leftovers, not future functionality): `function-node-worker`'s
`uac`/`database`, `function-gateway`'s `function_server`,
`frontier-server`'s `remote-events`/`function_server`/`function_worker`,
`material-tracing-server`'s `pdf_render`/`product_server`. Leave those out
of the structured `config.*` values entirely (don't render them) and note
in the chart's README *why* they're missing - `config.raw` is there for
anyone who wants them anyway.

### Apps that aren't `@fsarch/server`-based

Not every app repo uses the framework above - `dashboard` (Next.js/NextAuth)
and `frontier-worker` (a small standalone Node process, no NestJS/database
at all) are architecturally their own thing. For these:
- Figure out the real config surface from `process.env.*` usage in `src`
  (`grep -rhoE "process\.env\.[A-Z_]+" src`), not from an assumed
  `config.yml` shape.
- `fsarch-common.deployment` hardcodes the env var names it sets to `PORT`
  (from `env.port`) and `CONFIG_FILE_PATH` (from `env.configFilePath`,
  only when `configMap.create` is also true). If the app reads a
  differently-named var for either (e.g. `frontier-worker`'s
  `FRONTIER_WORKER_PORT`), set the corresponding `env.*` value to `""` to
  skip the unused var and add the real one via `extraEnv` instead - the
  ConfigMap volume mount itself still works off `env.configFilePath`
  regardless, so a stray unused `CONFIG_FILE_PATH` env var is harmless if
  you need the mount but not that exact var name.
- If `config.yml` is an optional feature rather than core to the app
  working at all (`frontier-worker`'s single optional `function_worker:`
  key), default `configMap.create: false` instead of `true` - don't force
  a ConfigMap/ENV var/ volume mount on every install for something most
  deployments don't need.
- Pre-populate `extraEnv` with the app's *required* env vars (real-looking
  placeholder values, empty for secrets) instead of leaving it as an empty
  example - `fsarch-common` has no dedicated slot for them, and without
  defaults the chart doesn't describe a working deployment at all
  (`dashboard`'s NextAuth/Keycloak vars, `frontier-worker`'s control-plane
  URL/auth token).

### Monorepos / multi-deployable app repos

`frontier-server` (`fsarch/frontier-server`) is one app repo that builds
**two** separately-deployed apps (`apps/frontier-api`, `apps/frontier-worker`)
- it gets **two** charts (`charts/frontier-server`, `charts/frontier-worker`),
each with its own image repository, `Chart.yaml`, and independent
versioning, exactly as if they were separate app repos. Don't try to share
one image repo with tag suffixes (`:v1-api`/`:v1-worker`) or one chart with
a mode switch - it breaks `bump-chart.yaml`'s naming convention (see below)
and Helm's one-appVersion-per-chart model. The published image/chart name
doesn't have to match the app's own directory name either (frontier-server's
`apps/frontier-api` is intentionally published as `fsarch/frontier-server`/
`charts/frontier-server`, to match the *repo's* name instead) - if an app
repo's image-build workflow needs the same split, decouple the matrix
key used for the Dockerfile path from the one used for the image name/
`repository_dispatch` `event_type` (see `frontier-server`'s
`docker-images.yml` for a worked example) rather than renaming directories.

### Adding a new service chart

Full walkthrough with the exact template names: `charts/fsarch-common/README.md`
("Using it in a new chart"). Short version, using `pdf-render-server` as the
reference example to copy from:

1. `mkdir -p charts/<name>/templates`, add a `Chart.yaml` (`type:
   application`) with a `fsarch-common` entry under `dependencies:` (copy
   `charts/pdf-render-server/Chart.yaml`'s).
2. Symlink the shared chart in rather than vendoring it:
   `ln -s ../../fsarch-common charts/<name>/charts/fsarch-common`.
3. Read the app repo's `Dockerfile` (port, entrypoint), `package.json`
   (framework/deps - `@fsarch/server` or not), `config/config.yml` +
   `config.template.yml` if present, and `src/main.ts`/`app.module.ts` to
   see what's actually wired up. Write `values.yaml` implementing the
   values contract from `charts/fsarch-common/README.md` (copy
   `charts/pdf-render-server/values.yaml` as a starting point and adjust
   image/env/config for the new service) - see "`config.yml` patterns
   across consumer charts" and "Apps that aren't `@fsarch/server`-based"
   above for how to model its config section by section.
4. Add thin wrapper templates that just `include` the shared ones -
   `deployment.yaml`, `service.yaml`, `serviceaccount.yaml`, `namespace.yaml`,
   `ingress.yaml`, `NOTES.txt` (see `charts/pdf-render-server/templates/` for
   the exact one-liners and which `fsarch-common.*` template name each maps
   to). Only add real logic to `templates/` for things that are actually
   app-specific (e.g. a ConfigMap with app-specific content, as
   `pdf-render-server/templates/configmap.yaml` does).
5. Verify: `helm lint charts/<name>`; `helm template charts/<name>` for the
   defaults; then `helm template charts/<name> -f <overrides>` for each
   `type` branch you added (every auth/database type, `config.raw`) to
   confirm each renders valid, correctly-indented YAML - a bad `nindent` or
   a missed `quote` only shows up once you actually exercise that branch.
6. Add the chart to the table in the root `README.md`.
7. Give it its own `version:`/`appVersion:` in `Chart.yaml`; it gets released
   independently by `release-charts.yaml` the next time `main` changes under
   `charts/<name>/**` (see below) - no changes needed to that workflow itself.

**`image.tag` gotcha**: the default (`""`) falls back to `.Chart.AppVersion`
via `fsarch-common.deployment`, which only points at something real once
the app repo actually publishes a matching versioned tag. Check the app
repo's image-build workflow before trusting the default - some
(`function-server`, `function-node-worker`, historically) only ever push
`:latest`, in which case set `image.tag: "latest"` explicitly in the
chart's `values.yaml` (with a comment explaining why) instead, and switch
it back to `""` once/if that workflow adds versioned-tag releases.

**Don't assume the app repo's own image-build workflow is correct** just
because it exists - these get copy-pasted between repos too and the
`IMAGE=`/`event_type` variables are easy to leave pointing at the source
repo (`function-gateway`'s `image.yml` was found pushing to
`fsarch/frontend-server` and dispatching `frontend-server-released`,
apparently copy-pasted from `frontend-server` and never adjusted). Read it
rather than skimming the file name, and flag/fix mismatches with the repo
name before wiring a chart's `image.repository` up to trust it.

If the new service should also auto-bump on its own app repo's releases like
`pdf-render-server` and `metric-server` do, no changes are needed here -
`bump-chart.yaml` is generic across every chart (see below). Just make the
new app repo's image-build workflow send a `repository_dispatch` with
`event_type: "<name>-released"` and `client_payload: {"version": "..."}` on
stable release tags, using the `HELM_CHARTS_DISPATCH_TOKEN` secret (copy
`metric-server`'s `.github/workflows/image.yml` "notify helm-charts of the
new release" step). If you're editing that workflow file, validate it with
`actionlint path/to/workflow.yml` (and `python3 -c "import yaml;
yaml.safe_load(open('...'))"` for a quick syntax check) before considering
it done - and simulate `bump-chart.yaml`'s own bash logic locally (derive
`<name>` by stripping the `-released` suffix from the `event_type`, confirm
`charts/<name>/Chart.yaml` exists) to catch naming mismatches early.

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
