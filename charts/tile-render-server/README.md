# tile-render-server

Helm chart for the fsarch `tile-render-server` service
([source](https://github.com/fsarch/tile-render-server)) - an on-demand SVG
tile API backed by a `planet.pmtiles` archive.

The Deployment/Service/ServiceAccount/Namespace/Ingress templates are just
thin wrappers around the [`fsarch-common`](../fsarch-common) library chart
(see `templates/*.yaml`); only `templates/configmap.yaml` (the `config.yml`
rendering) is specific to this app.

## Important: this chart alone does not make the API serve tiles

Two things beyond `helm install` are required, neither of which this chart
can do for you (no management API/CLI exists upstream yet):

1. **A `dataset_versions` row.** The path to `planet.pmtiles` doesn't come
   from `config.yml` at all - it comes exclusively from the one `is_active`
   row of the `dataset_versions` table (`path` resolved relative to
   `config.extra.storage.data`), inserted directly via SQL against the
   Postgres database configured under `config.database`:

   ```sql
   INSERT INTO dataset_versions (id, path, is_active)
   VALUES (gen_random_uuid(), 'planet.pmtiles', true);
   ```

   **Without an active row, the API refuses to start.** Migrations run
   automatically on boot (`migrationsRun: true`), so the `dataset_versions`
   table exists by the time you can run this.

2. **The `planet.pmtiles` file itself**, placed wherever
   `config.extra.storage.data` points (`/data/planet.pmtiles` by default -
   see persistence below) or in the configured S3 bucket.

A template row (optional - only needed to override the hardcoded default
colors) is inserted the same way; see the app repo's `src/database/seeds/`
and its own README for ready-to-run `.sql` files.

## Installing

```sh
helm upgrade --install tile-render-server ./charts/tile-render-server \
  --namespace tile-render-server --create-namespace \
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
| `image.repository` / `image.tag` / `image.pullPolicy` | Container image. | `docker.io/fsarch/tile-render-server`, `latest`, `Always` |
| `imagePullSecrets` | Pull secrets for private registries. | `[]` |
| `podLabels` / `podAnnotations` | Extra labels/annotations on the Pod template. | `{}` |
| `podSecurityContext` / `securityContext` | Pod- / container-level `securityContext`. | `{}` |
| `serviceAccount.create` | Create a dedicated ServiceAccount. | `false` |
| `serviceAccount.name` | ServiceAccount name (generated when empty and `create: true`). | `""` |
| `service.type` / `service.port` / `service.annotations` | Service exposing the app. | `ClusterIP`, `80`, `{}` |
| `containerPort` | Port the container listens on. | `8080` |
| `env.port` | `PORT` env var (should match `containerPort`). | `"8080"` |
| `env.configFilePath` | Mount path for the rendered `config.yml` (`CONFIG_FILE_PATH`). | `/etc/tile-render-server/config.yml` |
| `extraEnv` | Additional raw `EnvVar` entries appended to the container. | `[]` |
| `configMap.create` | Whether to render the ConfigMap holding `config.yml`. Disable to bring your own and set `env.configFilePath` accordingly. | `true` |
| `configMap.nameOverride` | Overrides the ConfigMap name (`<fullname>-config` by default). | `""` |
| `config.auth.type` | Auth scheme rendered into `config.yml`'s `auth:` section: `jwt-jwk`, `oidc`, or `static`. Only the field(s) for the active type are rendered. All routes require a valid token except tile/template rendering endpoints, which are `@Public()`. | `oidc` |
| `config.auth.jwkUrl` | JWK endpoint, rendered as `auth.jwkUrl` when `config.auth.type` is `jwt-jwk`. | `""` |
| `config.auth.discoveryUrl` | OIDC discovery URL, rendered as `auth.discovery_url` when `config.auth.type` is `oidc`. | see `values.yaml` |
| `config.auth.secret` / `config.auth.users` | Shared secret / local user list used when `config.auth.type` is `static`. `secret` is sensitive - set via `--set` or a non-committed values file. | `""` / `[]` |
| `config.database.type` | Database scheme rendered into `config.yml`'s `database:` section: `sqlite`, `postgres`, or `cockroachdb`. Only the field(s) for the active type are rendered. Used solely as a shared, persistent cache for cross-tile label anchor positions - **not** for tile data, which always comes from `config.extra.storage`/`dataset_versions` (see above). Required for `npm start`/this chart; the API's migrations run automatically on boot. | `postgres` |
| `config.database.database` (sqlite) | SQLite database file path. | `tile-render-server` (n/a until switched to `sqlite`) |
| `config.database.host` / `.port` / `.database` / `.username` / `.password` (postgres/cockroachdb) | Connection settings. `password` is sensitive - set it via `--set` or a non-committed values file. | see `values.yaml` |
| `config.database.ssl` | TLS settings for postgres/cockroachdb (`rejectUnauthorized`, `ca`, `cert`, `key`; the latter three also accept `{path: ...}` pointing at a mounted file). | `{rejectUnauthorized: true}` |
| `config.tracing` | OpenTelemetry tracing (`@fsarch/server` built-in). `null` omits the `tracing:` section entirely; set it to enable - `exporter.type` is mutually exclusive (`console`, or `otlp-http`/`otlp-grpc` which also need `url`/`headers`); `sampler` defaults to `parentbased_traceidratio` if omitted. Fully supported from the app repo's first official release onward. | `null` |
| `config.extra` | Freeform passthrough for `tiles`/`storage` (see below) - merged into `config.yml` verbatim via `toYaml`. | see `values.yaml` |
| `config.raw` | Literal `config.yml` content; overrides all `config.*` structured values above when set. | `""` |
| `livenessProbe` / `readinessProbe` | Probe definitions (`enabled` toggles them, remaining keys are passed through verbatim). | TCP on `http`, see `values.yaml` |
| `resources` | Container resource requests/limits. | `50m/128Mi` requests, `500m/512Mi` limits |
| `extraVolumes` / `extraVolumeMounts` | Additional volumes / mounts - e.g. a PVC backing `/data`/`/cache`. | `[]` |
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling controls. | `{}` / `[]` / `{}` |
| `ingress.enabled` | Create an Ingress. | `false` |
| `ingress.className` / `ingress.annotations` / `ingress.hosts` / `ingress.tls` | Ingress configuration. | see `values.yaml` |

Not modeled: `uac`. Unlike most other `@fsarch/server`-based charts in this
repo, this app's `main.ts` only calls `.enableAuth()` - never anything
UAC-related - and neither `config.yaml` nor `config.example.yaml` in the app
repo has a `uac:` section. Use `config.raw` if you need one anyway.

### `config.extra.tiles` / `config.extra.storage`

Both are freeform (too shaped-by-use-case for a bespoke values schema) and
rendered as-is via `toYaml`. Full schema, reproduced from the app repo's own
`README.md`/`config.example.yaml`:

```yaml
config:
  extra:
    tiles:
      cacheControl: "public, max-age=3600" # Cache-Control header on tile responses
      labels: true
      roadLabels: true
      natureLabels: true
      datasetVersion: "" # bump when planet.pmtiles is regenerated, invalidates cached label anchors
      maxZoom: 18 # optional: serve zoom levels beyond the dataset's own max by overzooming

    storage:
      # storage.data: where dataset_versions.path is resolved from. Always a
      # single filesystem-or-S3 backend (no memory layer/layering - a
      # multi-GB pmtiles archive doesn't benefit from it the way small
      # rendered tiles do).
      data: /data
      # data:
      #   type: s3
      #   config:
      #     bucket: my-pmtiles-bucket
      #     region: eu-central-1
      #     accessKeyId: ...          # optional with IAM roles/default AWS credentials
      #     secretAccessKey: ...      # required together with accessKeyId
      #     endpoint: https://...     # optional, for S3-compatible services (MinIO etc.)
      #     prefix: datasets/         # optional

      # storage.cache: rendered (pre-template) SVG tiles, keyed by
      # dataset_version id + z/x/y. Unlike storage.data, also accepts a
      # `memory` backend and layering (an array, checked in order): a hit in
      # a slower layer is copied back into every faster one. Each layer can
      # be restricted to a zoom range (minZoom/maxZoom, inclusive) - e.g. to
      # keep an S3 layer from filling up with deep overzoomed tiles. A zoom
      # outside every layer's range is simply never cached (not an error).
      cache:
        - type: memory
          config:
            maxItems: 1000       # optional, default 1000
            maxBytes: 134217728  # optional, default 128 MiB
        - type: filesystem
          maxZoom: 14
          config:
            path: /cache
        # - type: s3
        #   config:
        #     bucket: my-tile-cache
        #     region: eu-central-1
```

This chart does not provision persistent storage. The defaults use plain
filesystem paths (`/data`, `/cache`) inside the container, which are
**ephemeral** unless backed by a PVC via `extraVolumes`/`extraVolumeMounts`
- or switched to S3 as shown above for a stateless pod.

### Example: persistent filesystem storage via a PVC

```yaml
extraVolumes:
  - name: tile-render-server-data
    persistentVolumeClaim:
      claimName: tile-render-server-data
  - name: tile-render-server-cache
    persistentVolumeClaim:
      claimName: tile-render-server-cache
extraVolumeMounts:
  - name: tile-render-server-data
    mountPath: /data
  - name: tile-render-server-cache
    mountPath: /cache
```

### Example: bringing your own ConfigMap

```yaml
configMap:
  create: false
env:
  configFilePath: /etc/tile-render-server/config.yml
```
