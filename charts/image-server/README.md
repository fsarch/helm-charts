# image-server

Helm chart for the fsarch `image-server` service
([source](https://github.com/michael-braun/image-server)).

The Deployment/Service/ServiceAccount/Namespace/Ingress templates are just
thin wrappers around the [`fsarch-common`](../fsarch-common) library chart
(see `templates/*.yaml`); only `templates/configmap.yaml` (the `config.yml`
rendering) is specific to this app.

Unlike `pdf-render-server`/`metric-server`, `image-server`'s `config.yml`
has several more sections (`images.presets`, `naming`, `storage`,
`caching`, `signed_urls`). Only `auth`/`uac`/`database` - the parts with a
mutually-exclusive schema per selected `type`, same as the other charts -
are modeled as dedicated `values.yaml` keys; everything else is a single
freeform `config.extra` map rendered as-is (see `values.yaml` and
[`STORAGE.md`](https://github.com/michael-braun/image-server/blob/main/STORAGE.md)
in the app repo for the full `storage.data`/`storage.cache` schema).

This chart does not provision persistent storage. The default config uses
`sqlite` + filesystem storage under `/data` and `/cache` in the container,
which is **ephemeral** unless you back it with a PVC via
`extraVolumes`/`extraVolumeMounts` - or switch `config.database.type` to
`cockroachdb` and `config.extra.storage` to `s3` for a stateless pod.

## Installing

```sh
helm upgrade --install image-server ./charts/image-server \
  --namespace image-server --create-namespace \
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
| `image.repository` / `image.tag` / `image.pullPolicy` | Container image. | `docker.io/fsarch/image-server`, chart `appVersion`, `Always` |
| `imagePullSecrets` | Pull secrets for private registries. | `[]` |
| `podLabels` / `podAnnotations` | Extra labels/annotations on the Pod template. | `{}` |
| `podSecurityContext` / `securityContext` | Pod- / container-level `securityContext`. | `{}` |
| `serviceAccount.create` | Create a dedicated ServiceAccount. | `false` |
| `serviceAccount.name` | ServiceAccount name (generated when empty and `create: true`). | `""` |
| `service.type` / `service.port` / `service.annotations` | Service exposing the app. | `ClusterIP`, `8080`, `{}` |
| `containerPort` | Port the container listens on. | `8080` |
| `env.port` | `PORT` env var (should match `containerPort`). | `"8080"` |
| `env.configFilePath` | Mount path for the rendered `config.yml` (`CONFIG_FILE_PATH`). | `/etc/image-server/config.yml` |
| `extraEnv` | Additional raw `EnvVar` entries appended to the container. | `[]` |
| `configMap.create` | Whether to render the ConfigMap holding `config.yml`. Disable to bring your own and set `env.configFilePath` accordingly. | `true` |
| `configMap.nameOverride` | Overrides the ConfigMap name (`<fullname>-config` by default). | `""` |
| `config.auth.type` | Auth scheme rendered into `config.yml`'s `auth:` section: `jwt-jwk` or `oidc`. Only the field(s) for the active type are rendered. | `jwt-jwk` |
| `config.auth.jwkUrl` | JWK endpoint, rendered as `auth.jwkUrl` when `config.auth.type` is `jwt-jwk`. | see `values.yaml` |
| `config.auth.discoveryUrl` | OIDC discovery URL, rendered as `auth.discovery_url` when `config.auth.type` is `oidc`. | `""` |
| `config.uac` | Structured `uac:` section (static user/permission list; the only permission currently defined upstream is `manage_images`). | see `values.yaml` |
| `config.database.type` | Database scheme rendered into `config.yml`'s `database:` section: `sqlite` or `cockroachdb` (no plain `postgres`, unlike `metric-server`). Only the field(s) for the active type are rendered. | `sqlite` |
| `config.database.database` (sqlite) | SQLite database file path. | `/data/image-server.sqlite3` |
| `config.database.host` / `.port` / `.database` / `.username` / `.password` (cockroachdb) | Connection settings for `cockroachdb`. `password` is sensitive - set it via `--set` or a non-committed values file. | see `values.yaml` |
| `config.database.ssl` | TLS settings for `cockroachdb` (`rejectUnauthorized`, `ca`, `cert`, `key`; the latter three also accept `{path: ...}` pointing at a mounted file). | `{rejectUnauthorized: true}` |
| `config.extra` | Freeform passthrough for `images`, `naming`, `storage`, `caching`, `signed_urls` - merged into `config.yml` verbatim via `toYaml`. | see `values.yaml` |
| `config.raw` | Literal `config.yml` content; overrides all `config.*` structured values above when set. | `""` |
| `livenessProbe` / `readinessProbe` | Probe definitions (`enabled` toggles them, remaining keys are passed through verbatim). | TCP on `http`, see `values.yaml` |
| `resources` | Container resource requests/limits. | `50m/128Mi` requests, `500m/512Mi` limits |
| `extraVolumes` / `extraVolumeMounts` | Additional volumes / mounts - e.g. a PVC backing `/data`/`/cache`. | `[]` |
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling controls. | `{}` / `[]` / `{}` |
| `ingress.enabled` | Create an Ingress. | `false` |
| `ingress.className` / `ingress.annotations` / `ingress.hosts` / `ingress.tls` | Ingress configuration. | see `values.yaml` |

### Example: persistent filesystem storage via a PVC

```yaml
extraVolumes:
  - name: image-server-data
    persistentVolumeClaim:
      claimName: image-server-data
extraVolumeMounts:
  - name: image-server-data
    mountPath: /data
```

(`config.database.database: /data/image-server.sqlite3` and
`config.extra.storage.data: /data` already point at `/data` by default, so
this alone makes both durable; add a second volume/mount pair at `/cache`
too if you want the image cache to survive restarts as well.)

### Example: S3 storage instead of the filesystem

```yaml
config:
  extra:
    storage:
      data:
        type: s3
        config:
          bucket: prod-images
          region: eu-central-1
      cache:
        type: s3
        config:
          bucket: prod-cache
          region: eu-central-1
```

Since `storage.data`/`storage.cache` default to a plain string (filesystem
path) but this overrides them with an object, `helm template`/`install`
prints a harmless `coalesce.go: ... destination is a table. Ignoring
non-table value` warning for each - the override still wins and renders
correctly (verified), it's just Helm noting the type change.

### Example: cockroachdb instead of sqlite

```yaml
config:
  database:
    type: cockroachdb
    host: cockroachdb.fsarch.svc.cluster.local
    database: image_server
    username: image_server
    password: "<set via --set or a secret values file>"
```

### Example: bringing your own ConfigMap

```yaml
configMap:
  create: false
env:
  configFilePath: /etc/image-server/config.yml
```