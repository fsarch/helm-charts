# function-gateway

Helm chart for the fsarch `function-gateway` service
([source](https://github.com/fsarch/function-gateway)) - manages and
executes remote functions via worker servers (e.g. `function-node-worker`).

The Deployment/Service/ServiceAccount/Namespace/Ingress templates are just
thin wrappers around the [`fsarch-common`](../fsarch-common) library chart
(see `templates/*.yaml`); only `templates/configmap.yaml` (the `config.yml`
rendering) is specific to this app.

`config.yml` has `auth`/`uac`/`database` (same pattern as `metric-server`/
`frontend-server`, full `jwt-jwk`/`oidc`/`static` auth support) plus a
`function_worker` section - the worker instance this gateway dispatches
function executions to, authenticated via OAuth2 client credentials. The
app's own example config.yml also has a `function_server:` section, but
nothing in its source actually reads it (only `function_worker` is
consumed) - same kind of dead leftover config as `function-node-worker`'s
unused `uac`/`database`, so it's intentionally omitted here (use
`config.raw` if you want to keep it anyway).

## Installing

```sh
helm upgrade --install function-gateway ./charts/function-gateway \
  --namespace function-gateway --create-namespace \
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
| `image.repository` / `image.tag` / `image.pullPolicy` | Container image. | `docker.io/fsarch/function-gateway`, chart `appVersion`, `Always` |
| `imagePullSecrets` | Pull secrets for private registries. | `[]` |
| `podLabels` / `podAnnotations` | Extra labels/annotations on the Pod template. | `{}` |
| `podSecurityContext` / `securityContext` | Pod- / container-level `securityContext`. | `{}` |
| `serviceAccount.create` | Create a dedicated ServiceAccount. | `false` |
| `serviceAccount.name` | ServiceAccount name (generated when empty and `create: true`). | `""` |
| `service.type` / `service.port` / `service.annotations` | Service exposing the app. | `ClusterIP`, `8080`, `{}` |
| `containerPort` | Port the container listens on. | `8080` |
| `env.port` | `PORT` env var (should match `containerPort`). | `"8080"` |
| `env.configFilePath` | Mount path for the rendered `config.yml` (`CONFIG_FILE_PATH`). | `/etc/function-gateway/config.yml` |
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
| `config.functionWorker.url` | Base URL of the `function-node-worker` instance to dispatch to. | `http://function-node-worker.example.com` |
| `config.functionWorker.auth.tokenEndpoint` / `.clientId` / `.clientSecret` | OAuth2 client-credentials this gateway uses to call the worker. `clientSecret` is sensitive - set via `--set` or a non-committed values file. | see `values.yaml` |
| `config.raw` | Literal `config.yml` content; overrides all `config.*` structured values above when set. | `""` |
| `livenessProbe` / `readinessProbe` | Probe definitions (`enabled` toggles them, remaining keys are passed through verbatim). | TCP on `http`, see `values.yaml` |
| `resources` | Container resource requests/limits. | `50m/128Mi` requests, `500m/512Mi` limits |
| `extraVolumes` / `extraVolumeMounts` | Additional volumes / mounts. | `[]` |
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling controls. | `{}` / `[]` / `{}` |
| `ingress.enabled` | Create an Ingress. | `false` |
| `ingress.className` / `ingress.annotations` / `ingress.hosts` / `ingress.tls` | Ingress configuration. | see `values.yaml` |

### Example: pointing at a real function-node-worker

```yaml
config:
  functionWorker:
    url: http://function-node-worker.fsarch.svc.cluster.local:8080
    auth:
      tokenEndpoint: https://login.example.com/realms/fsarch/protocol/openid-connect/token
      clientId: function-gateway
      clientSecret: "<set via --set or a secret values file>"
```

### Example: static auth instead of oidc

```yaml
config:
  auth:
    type: static
    secret: "<set via --set or a secret values file>"
    users:
      - id: "11111111-1111-1111-1111-111111111111"
        username: admin
        password: "<set via --set or a secret values file>"
```

### Example: sqlite instead of postgres/cockroachdb

```yaml
config:
  database:
    type: sqlite
    database: ./example-data/database.sqlite3
```

### Example: bringing your own ConfigMap

```yaml
configMap:
  create: false
env:
  configFilePath: /etc/function-gateway/config.yml
```
