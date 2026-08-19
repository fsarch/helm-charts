# frontend-server

Helm chart for the fsarch `frontend-server` service
([source](https://github.com/fsarch/frontend-server) - published as Docker
image `fsarch/frontend-server`; the repo's `package.json` still calls it
`static-file-server` internally, that's what it is: an authenticated
file-storage/serving service, not a UI frontend).

The Deployment/Service/ServiceAccount/Namespace/Ingress templates are just
thin wrappers around the [`fsarch-common`](../fsarch-common) library chart
(see `templates/*.yaml`); only `templates/configmap.yaml` (the `config.yml`
rendering) is specific to this app.

`config.yml` has `auth`/`uac`/`database`/`storage` sections, no
`images`/`naming`/`caching`/`signed_urls` like `image-server` (those aren't
part of this app's config schema) and no `partition`/`deletion` like
`metric-server`. Notable difference from the other charts: this app's own
config validation only accepts `auth.type: jwt-jwk` or `static` - **not**
`oidc`.

This chart does not provision persistent storage. The default config
(`storage.data: /var/sfs/data`, a plain filesystem path) is **ephemeral**
unless you back it with a PVC via `extraVolumes`/`extraVolumeMounts`, or
switch to S3 storage (see example below) for a stateless pod.

## Installing

```sh
helm upgrade --install frontend-server ./charts/frontend-server \
  --namespace frontend-server --create-namespace \
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
| `image.repository` / `image.tag` / `image.pullPolicy` | Container image. | `docker.io/fsarch/frontend-server`, chart `appVersion`, `Always` |
| `imagePullSecrets` | Pull secrets for private registries. | `[]` |
| `podLabels` / `podAnnotations` | Extra labels/annotations on the Pod template. | `{}` |
| `podSecurityContext` / `securityContext` | Pod- / container-level `securityContext`. | `{}` |
| `serviceAccount.create` | Create a dedicated ServiceAccount. | `false` |
| `serviceAccount.name` | ServiceAccount name (generated when empty and `create: true`). | `""` |
| `service.type` / `service.port` / `service.annotations` | Service exposing the app. | `ClusterIP`, `8080`, `{}` |
| `containerPort` | Port the container listens on. | `8080` |
| `env.port` | `PORT` env var (should match `containerPort`). | `"8080"` |
| `env.configFilePath` | Mount path for the rendered `config.yml` (`CONFIG_FILE_PATH`). | `/etc/frontend-server/config.yml` |
| `extraEnv` | Additional raw `EnvVar` entries appended to the container. | `[]` |
| `configMap.create` | Whether to render the ConfigMap holding `config.yml`. Disable to bring your own and set `env.configFilePath` accordingly. | `true` |
| `configMap.nameOverride` | Overrides the ConfigMap name (`<fullname>-config` by default). | `""` |
| `config.auth.type` | Auth scheme rendered into `config.yml`'s `auth:` section: `jwt-jwk` or `static` (no `oidc` - see above). Only the field(s) for the active type are rendered. | `jwt-jwk` |
| `config.auth.jwkUrl` | JWK endpoint, rendered as `auth.jwkUrl` when `config.auth.type` is `jwt-jwk`. | see `values.yaml` |
| `config.auth.secret` / `config.auth.users` | Shared secret + local user list, rendered when `config.auth.type` is `static`. `secret` is sensitive - set via `--set` or a non-committed values file. | `""` / `[]` |
| `config.uac` | Structured `uac:` section (static user/permission list; valid permissions: `manage_claims`, `manage_images`, `manage_projects`). | see `values.yaml` |
| `config.database.type` | Database scheme rendered into `config.yml`'s `database:` section: `sqlite`, `postgres` or `cockroachdb`. Only the field(s) for the active type are rendered. | `postgres` |
| `config.database.host` / `.port` / `.database` / `.username` / `.password` | Connection settings for `postgres`/`cockroachdb`. `password` is sensitive - set it via `--set` or a non-committed values file. | see `values.yaml` |
| `config.database.database` (sqlite) | SQLite database file path, used instead of the connection settings above when `config.database.type` is `sqlite`. | n/a |
| `config.database.ssl` | TLS settings for `postgres`/`cockroachdb` (`rejectUnauthorized`, `ca`, `cert`, `key`; the latter three also accept `{path: ...}` pointing at a mounted file). | `{rejectUnauthorized: true}` |
| `config.storage.data` | `storage.data` from `config.yml` - a plain filesystem path (string) or `{type: filesystem\|s3, config: {...}}`. Rendered as-is via `toYaml`. | `/var/sfs/data` |
| `config.raw` | Literal `config.yml` content; overrides all `config.*` structured values above when set. | `""` |
| `livenessProbe` / `readinessProbe` | Probe definitions (`enabled` toggles them, remaining keys are passed through verbatim). | TCP on `http`, see `values.yaml` |
| `resources` | Container resource requests/limits. | `50m/128Mi` requests, `500m/512Mi` limits |
| `extraVolumes` / `extraVolumeMounts` | Additional volumes / mounts - e.g. a PVC backing `storage.data`. | `[]` |
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling controls. | `{}` / `[]` / `{}` |
| `ingress.enabled` | Create an Ingress. | `false` |
| `ingress.className` / `ingress.annotations` / `ingress.hosts` / `ingress.tls` | Ingress configuration. | see `values.yaml` |

### Example: persistent filesystem storage via a PVC

```yaml
extraVolumes:
  - name: frontend-server-data
    persistentVolumeClaim:
      claimName: frontend-server-data
extraVolumeMounts:
  - name: frontend-server-data
    mountPath: /var/sfs/data
```

(`config.storage.data` already points at `/var/sfs/data` by default, so
this alone makes it durable.)

### Example: S3 storage instead of the filesystem

```yaml
config:
  storage:
    data:
      type: s3
      config:
        bucket: prod-frontend-server
        region: eu-central-1
```

Since `config.storage.data` defaults to a plain string but this overrides
it with an object, `helm template`/`install` prints a harmless
`coalesce.go: ... destination is a table. Ignoring non-table value`
warning - the override still wins and renders correctly, it's just Helm
noting the type change (same as `image-server`'s equivalent `storage`
values).

### Example: static auth instead of jwt-jwk

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
    database: /var/sfs/data/frontend-server.sqlite3
```

### Example: bringing your own ConfigMap

```yaml
configMap:
  create: false
env:
  configFilePath: /etc/frontend-server/config.yml
```