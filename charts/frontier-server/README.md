# frontier-server

Helm chart for the fsarch `frontier-server` API
([source](https://github.com/fsarch/frontier-server) - the app itself lives
at `apps/frontier-api` in that monorepo, but is published as the
`fsarch/frontier-server` image/chart to match the repo's own name) - a
utility service for configuring and managing `frontier-worker` instances
(domain groups, upstream groups, path rules, cache/CORS/log policies - all
managed at runtime via its own API/database, not through `config.yml`).

The Deployment/Service/ServiceAccount/Namespace/Ingress templates are just
thin wrappers around the [`fsarch-common`](../fsarch-common) library chart
(see `templates/*.yaml`); only `templates/configmap.yaml` (the `config.yml`
rendering) is specific to this app.

**The `frontier-server` monorepo has two deployables** - this chart
(`apps/frontier-api`) and the sibling
[`frontier-worker`](../frontier-worker) chart (`apps/frontier-worker`),
each with its own image repository (`fsarch/frontier-server` /
`fsarch/frontier-worker` - note the API app publishes as
`fsarch/frontier-server`, not `fsarch/frontier-api`), one image per chart
like everywhere else in this repo.

`config.yml` has `auth`/`uac`/`database` (same pattern as `metric-server`/
`frontend-server`/`function-gateway`) plus a `workers.websocket` section -
the shared secret and poll interval `frontier-worker` instances use to
authenticate their control-plane connection back to this API. The app
repo's example config.yml also has `remote-events`, `function_server` and
`function_worker` sections, but nothing in the app's source actually
reads them - dead leftover config, intentionally omitted here (use
`config.raw` if you want to keep them anyway).

## Installing

```sh
helm upgrade --install frontier-server ./charts/frontier-server \
  --namespace frontier --create-namespace \
  --values my-values.yaml
```

Or let the chart manage the namespace itself (see `namespace.create` below)
and only pass `--namespace`.

## Configuration

| Key | Description | Default |
| --- | --- | --- |
| `nameOverride` | Overrides the name used to build resource names. | `""` |
| `fullnameOverride` | Overrides the full resource name (`<release>-<chart>` by default). | `""` |
| `namespace.create` | Whether the chart creates the target Namespace. | `false` |
| `namespace.name` | Target namespace; defaults to the release namespace when empty. | `""` |
| `commonLabels` / `commonAnnotations` | Extra labels/annotations merged onto every resource. | `{}` |
| `replicaCount` | Deployment replica count. | `1` |
| `revisionHistoryLimit` | ReplicaSets to retain. | `3` |
| `image.repository` / `image.tag` / `image.pullPolicy` | Container image. | `docker.io/fsarch/frontier-server`, chart `appVersion`, `Always` |
| `imagePullSecrets` | Pull secrets for private registries. | `[]` |
| `podLabels` / `podAnnotations` | Extra labels/annotations on the Pod template. | `{}` |
| `podSecurityContext` / `securityContext` | Pod- / container-level `securityContext`. | `{}` |
| `serviceAccount.create` | Create a dedicated ServiceAccount. | `false` |
| `serviceAccount.name` | ServiceAccount name (generated when empty and `create: true`). | `""` |
| `service.type` / `service.port` / `service.annotations` | Service exposing the app. | `ClusterIP`, `8080`, `{}` |
| `containerPort` | Port the container listens on. | `8080` |
| `env.port` | `PORT` env var (should match `containerPort`). | `"8080"` |
| `env.configFilePath` | Mount path for the rendered `config.yml` (`CONFIG_FILE_PATH`). | `/etc/frontier-server/config.yml` |
| `extraEnv` | Additional raw `EnvVar` entries appended to the container. | `[]` |
| `configMap.create` | Whether to render the ConfigMap holding `config.yml`. Disable to bring your own and set `env.configFilePath` accordingly. | `true` |
| `configMap.nameOverride` | Overrides the ConfigMap name (`<fullname>-config` by default). | `""` |
| `config.auth.type` | Auth scheme rendered into `config.yml`'s `auth:` section: `jwt-jwk`, `oidc` or `static`. Only the field(s) for the active type are rendered. | `oidc` |
| `config.auth.jwkUrl` | JWK endpoint, rendered as `auth.jwkUrl` when `config.auth.type` is `jwt-jwk`. | `""` |
| `config.auth.discoveryUrl` | OIDC discovery URL, rendered as `auth.discovery_url` when `config.auth.type` is `oidc`. | see `values.yaml` |
| `config.auth.secret` / `config.auth.users` | Shared secret + local user list, rendered when `config.auth.type` is `static`. `secret` is sensitive - set via `--set` or a non-committed values file. | `""` / `[]` |
| `config.uac` | Structured `uac:` section (static user/permission list). | see `values.yaml` |
| `config.database.type` | Database scheme rendered into `config.yml`'s `database:` section: `sqlite`, `postgres` or `cockroachdb`. Only the field(s) for the active type are rendered. | `postgres` |
| `config.database.host` / `.port` / `.database` / `.username` / `.password` | Connection settings for `postgres`/`cockroachdb`. `password` is sensitive - set it via `--set` or a non-committed values file. | see `values.yaml` |
| `config.database.database` (sqlite) | SQLite database file path, used instead of the connection settings above when `config.database.type` is `sqlite`. | n/a |
| `config.database.ssl` | TLS settings for `postgres`/`cockroachdb` (`rejectUnauthorized`, `ca`, `cert`, `key`; the latter three also accept `{path: ...}` pointing at a mounted file). | `{rejectUnauthorized: true}` |
| `config.workers.websocket.authToken` | Shared secret `frontier-worker` instances present to authenticate their control-plane websocket connection - **must match** the sibling `frontier-worker` chart's `FRONTIER_WORKER_AUTH_TOKEN`. Sensitive - set via `--set` or a non-committed values file. | `""` |
| `config.workers.websocket.configCheckIntervalMs` | How often (ms) connected workers poll for config changes. | `2000` |
| `config.raw` | Literal `config.yml` content; overrides all `config.*` structured values above when set. | `""` |
| `livenessProbe` / `readinessProbe` | Probe definitions (`enabled` toggles them, remaining keys are passed through verbatim). | TCP on `http`, see `values.yaml` |
| `resources` | Container resource requests/limits. | `50m/128Mi` requests, `500m/512Mi` limits |
| `extraVolumes` / `extraVolumeMounts` | Additional volumes / mounts. | `[]` |
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling controls. | `{}` / `[]` / `{}` |
| `ingress.enabled` | Create an Ingress. | `false` |
| `ingress.className` / `ingress.annotations` / `ingress.hosts` / `ingress.tls` | Ingress configuration. | see `values.yaml` |

### Example: wiring up a frontier-worker's shared secret

```yaml
config:
  workers:
    websocket:
      authToken: "<set via --set or a secret values file, matches frontier-worker's FRONTIER_WORKER_AUTH_TOKEN>"
      configCheckIntervalMs: 2000
```

### Example: cockroachdb with a client CA cert (matches config.template.yml)

```yaml
config:
  database:
    type: cockroachdb
    host: cockroachdb.fsarch.svc.cluster.local
    database: frontier_server
    username: frontier_server
    ssl:
      rejectUnauthorized: false
      ca:
        path: /etc/frontier-server/certs/ca.crt
extraVolumes:
  - name: cockroachdb-ca
    secret:
      secretName: cockroachdb-ca-cert
extraVolumeMounts:
  - name: cockroachdb-ca
    mountPath: /etc/frontier-server/certs
    readOnly: true
```

### Example: bringing your own ConfigMap

```yaml
configMap:
  create: false
env:
  configFilePath: /etc/frontier-server/config.yml
```
