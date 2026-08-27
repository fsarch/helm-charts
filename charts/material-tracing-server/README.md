# material-tracing-server

Helm chart for the fsarch `material-tracing-server` service
([source](https://github.com/fsarch/material-tracing-server)).

The Deployment/Service/ServiceAccount/Namespace/Ingress templates are just
thin wrappers around the [`fsarch-common`](../fsarch-common) library chart
(see `templates/*.yaml`); only `templates/configmap.yaml` (the `config.yml`
rendering) is specific to this app.

`config.yml` has `auth`/`uac`/`database` (same pattern as `metric-server`/
`frontend-server`/`function-gateway`, full `jwt-jwk`/`oidc`/`static` auth
support) plus two sections unique to this app: `images` (the image-server
instance used for admin/user-facing image links) and `custom_actions`
(deployment-specific action buttons that dispatch to function-server
functions). The app repo's example config.yml also has `pdf_render` and
`product_server` sections, but nothing in the app's source actually reads
them - dead leftover config, intentionally omitted here (use `config.raw`
if you want to keep them anyway).

The app also serves an MCP endpoint (`/.ai/mcp`) on the same port/process
as the regular HTTP API - no separate Service or port is needed for it.

## Installing

```sh
helm upgrade --install material-tracing-server ./charts/material-tracing-server \
  --namespace material-tracing-server --create-namespace \
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
| `image.repository` / `image.tag` / `image.pullPolicy` | Container image. | `docker.io/fsarch/material-tracing-server`, chart `appVersion`, `Always` |
| `imagePullSecrets` | Pull secrets for private registries. | `[]` |
| `podLabels` / `podAnnotations` | Extra labels/annotations on the Pod template. | `{}` |
| `podSecurityContext` / `securityContext` | Pod- / container-level `securityContext`. | `{}` |
| `serviceAccount.create` | Create a dedicated ServiceAccount. | `false` |
| `serviceAccount.name` | ServiceAccount name (generated when empty and `create: true`). | `""` |
| `service.type` / `service.port` / `service.annotations` | Service exposing the app. | `ClusterIP`, `8080`, `{}` |
| `containerPort` | Port the container listens on. | `8080` |
| `env.port` | `PORT` env var (should match `containerPort`). | `"8080"` |
| `env.configFilePath` | Mount path for the rendered `config.yml` (`CONFIG_FILE_PATH`). | `/etc/material-tracing-server/config.yml` |
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
| `config.images.adminUrl` / `.userUrl` | Admin/user-facing base URLs of the image-server instance to link to. | `http://image-server.example.com` (both) |
| `config.customActions` | Freeform list of deployment-specific action buttons dispatching to function-server functions. Rendered as-is via `toYaml`. | `[]` |
| `config.tracing` | OpenTelemetry tracing (`@fsarch/server` built-in as of `^0.1.6`). `null` omits the `tracing:` section entirely; set it to enable - `exporter.type` is mutually exclusive (`console`, or `otlp-http`/`otlp-grpc` which also need `url`/`headers`); `sampler` defaults to `parentbased_traceidratio` if omitted. **Not yet effective here** - this app repo's pinned `@fsarch/server` version predates tracing, see values.yaml's comment. | `null` |
| `config.raw` | Literal `config.yml` content; overrides all `config.*` structured values above when set. | `""` |
| `livenessProbe` / `readinessProbe` | Probe definitions (`enabled` toggles them, remaining keys are passed through verbatim). | TCP on `http`, see `values.yaml` |
| `resources` | Container resource requests/limits. | `50m/128Mi` requests, `500m/512Mi` limits |
| `extraVolumes` / `extraVolumeMounts` | Additional volumes / mounts. | `[]` |
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling controls. | `{}` / `[]` / `{}` |
| `ingress.enabled` | Create an Ingress. | `false` |
| `ingress.className` / `ingress.annotations` / `ingress.hosts` / `ingress.tls` | Ingress configuration. | see `values.yaml` |

### Example: wiring up a custom action (matches the app repo's own config.yml)

```yaml
config:
  customActions:
    - id: create_gpsr_pdf
      name: "GPSR PDF erstellen"
      action:
        type: function
        id: "54f803e1-c5b7-4497-a11e-811cec4c7c56"
        server_url: http://function-gateway.fsarch.svc.cluster.local:8080
        auth:
          type: credential-propagation
      resources:
        - part
```

(Valid `resources` values per the app's own validation: `part`,
`part_type`, `material`, `material_type`, `manufacturer`, `short_code`.)

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
  configFilePath: /etc/material-tracing-server/config.yml
```
