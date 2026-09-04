# calendar-server

Helm chart for the fsarch `calendar-server` service
([source](https://github.com/fsarch/calendar-server)) - a calendar/event
management microservice (calendars, events, recurring event series and
exceptions to them) on Postgres via TypeORM.

The Deployment/Service/ServiceAccount/Namespace/Ingress templates are just
thin wrappers around the [`fsarch-common`](../fsarch-common) library chart
(see `templates/*.yaml`); only `templates/configmap.yaml` (the `config.yml`
rendering) is specific to this app.

`config.yml` has the standard `@fsarch/server` `auth`/`database` sections
(same pattern as `metric-server`/`material-tracing-server`/`frontend-server`,
full `jwt-jwk`/`oidc`/`static` auth support) plus a `deletion` section
specific to this app's use of soft deletion (`.enableSoftDeletion()` in
`main.ts`) and full support for `@fsarch/server`'s OpenTelemetry `tracing`
section.

**Not modeled:** the app repo's own example `config.yml`
(`config/config.yml`) also has a `uac:` section, but `src/main.ts` never
calls `.enableUac(...)` on `FsArchAppBuilder`, so `@fsarch/server` never
registers `UacModule`/`RolesGuard` for this app - the `@Roles(...)`
decorators used throughout its controllers are currently inert and the
`uac:` config key is never read. Same kind of dead leftover config as
`material-tracing-server`'s `pdf_render`/`product_server` sections -
intentionally omitted here; use `config.raw` if you want to keep it for
parity with the app repo's own config.yml anyway.

**No Docker image / release pipeline yet:** at the time this chart was
written, the `calendar-server` app repo has no `Dockerfile` and no
`.github/workflows/` - `image.repository` follows the standard
`docker.io/fsarch/calendar-server` convention used by every other chart in
this repo, but no image has actually been published there yet. Set
`image.tag` explicitly (or point `image.repository` elsewhere) until that
pipeline exists; once the app repo adds an image-build workflow that
dispatches `calendar-server-released` events (see the root `CLAUDE.md`'s
"Adding a new service chart" section), `bump-chart.yaml` will keep this
chart's `appVersion`/`image.tag` default in sync automatically.

## Installing

```sh
helm upgrade --install calendar-server ./charts/calendar-server \
  --namespace calendar-server --create-namespace \
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
| `image.repository` / `image.tag` / `image.pullPolicy` | Container image. | `docker.io/fsarch/calendar-server`, chart `appVersion`, `Always` |
| `imagePullSecrets` | Pull secrets for private registries. | `[]` |
| `podLabels` / `podAnnotations` | Extra labels/annotations on the Pod template. | `{}` |
| `podSecurityContext` / `securityContext` | Pod- / container-level `securityContext`. | `{}` |
| `serviceAccount.create` | Create a dedicated ServiceAccount. | `false` |
| `serviceAccount.name` | ServiceAccount name (generated when empty and `create: true`). | `""` |
| `service.type` / `service.port` / `service.annotations` | Service exposing the app. | `ClusterIP`, `80`, `{}` |
| `containerPort` | Port the container listens on. | `8080` |
| `env.port` | `PORT` env var (should match `containerPort`). | `"8080"` |
| `env.configFilePath` | Mount path for the rendered `config.yml` (`CONFIG_FILE_PATH`). | `/etc/calendar-server/config.yml` |
| `extraEnv` | Additional raw `EnvVar` entries appended to the container. | `[]` |
| `configMap.create` | Whether to render the ConfigMap holding `config.yml`. Disable to bring your own and set `env.configFilePath` accordingly. | `true` |
| `configMap.nameOverride` | Overrides the ConfigMap name (`<fullname>-config` by default). | `""` |
| `config.auth.type` | Auth scheme rendered into `config.yml`'s `auth:` section: `jwt-jwk`, `oidc` or `static`. Only the field(s) for the active type are rendered. | `oidc` |
| `config.auth.jwkUrl` | JWK endpoint, rendered as `auth.jwkUrl` when `config.auth.type` is `jwt-jwk`. | `""` |
| `config.auth.discoveryUrl` | OIDC discovery URL, rendered as `auth.discovery_url` when `config.auth.type` is `oidc`. | see `values.yaml` |
| `config.auth.secret` / `config.auth.users` | Shared secret + local user list, rendered when `config.auth.type` is `static`. `secret` is sensitive - set via `--set` or a non-committed values file. | `""` / `[]` |
| `config.database.type` | Database scheme rendered into `config.yml`'s `database:` section: `sqlite`, `postgres` or `cockroachdb`. Only the field(s) for the active type are rendered. | `postgres` |
| `config.database.host` / `.port` / `.database` / `.username` / `.password` | Connection settings for `postgres`/`cockroachdb`. `password` is sensitive - set it via `--set` or a non-committed values file. | see `values.yaml` |
| `config.database.database` (sqlite) | SQLite database file path, used instead of the connection settings above when `config.database.type` is `sqlite`. | n/a |
| `config.database.ssl` | TLS settings for `postgres`/`cockroachdb` (`rejectUnauthorized`, `ca`, `cert`, `key`; the latter three also accept `{path: ...}` pointing at a mounted file). | `{rejectUnauthorized: true}` |
| `config.deletion.hardDeleteAfterDays` | Days after soft-deletion before a row is eligible for hard deletion, rendered as `deletion.hard_delete_after_days`. | `30` |
| `config.deletion.purgeSchedule.cron` / `.timezone` | Cron schedule (+ timezone) for the purge job, rendered as `deletion.purge_schedule`. | `"0 0 * * *"` / `Europe/Berlin` |
| `config.tracing` | OpenTelemetry tracing (`@fsarch/server` built-in). `null` omits the `tracing:` section entirely; set it to enable - `exporter.type` is mutually exclusive (`console`, or `otlp-http`/`otlp-grpc` which also need `url`/`headers`); `sampler` defaults to `parentbased_traceidratio` if omitted. | `null` |
| `config.raw` | Literal `config.yml` content; overrides all `config.*` structured values above when set. | `""` |
| `livenessProbe` / `readinessProbe` | Probe definitions (`enabled` toggles them, remaining keys are passed through verbatim). | TCP on `http`, see `values.yaml` |
| `resources` | Container resource requests/limits. | `50m/128Mi` requests, `500m/512Mi` limits |
| `extraVolumes` / `extraVolumeMounts` | Additional volumes / mounts. | `[]` |
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling controls. | `{}` / `[]` / `{}` |
| `ingress.enabled` | Create an Ingress. | `false` |
| `ingress.className` / `ingress.annotations` / `ingress.hosts` / `ingress.tls` | Ingress configuration. | see `values.yaml` |

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

### Example: enabling tracing

```yaml
config:
  tracing:
    enabled: true
    serviceName: calendar-server
    sampler: parentbased_traceidratio
    exporter:
      type: otlp-http
      url: http://otel-collector.fsarch.svc.cluster.local:4318/v1/traces
```

### Example: bringing your own ConfigMap

```yaml
configMap:
  create: false
env:
  configFilePath: /etc/calendar-server/config.yml
```
