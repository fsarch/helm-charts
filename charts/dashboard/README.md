# dashboard

Helm chart for the fsarch `dashboard` service
([source](https://github.com/fsarch/dashboard)) - a Next.js frontend that
federates a set of backend fsarch services (defined in `config.yml`) behind
a single authenticated UI.

The Deployment/Service/ServiceAccount/Namespace/Ingress templates are just
thin wrappers around the [`fsarch-common`](../fsarch-common) library chart
(see `templates/*.yaml`); only `templates/configmap.yaml` (the `config.yml`
rendering) is specific to this app.

**Architecturally different from the other charts in this repo:**
`dashboard` isn't built on `@fsarch/server` - it has no `auth:`/`database:`
section in `config.yml` at all. Auth is [NextAuth](https://next-auth.js.org/)
with a Keycloak provider, configured entirely via env vars
(`values.yaml`'s `extraEnv`, pre-populated below since `fsarch-common` has
no dedicated slot for them). `config.yml` itself mostly holds
`services`/`defaults`/`theme`/`uac` - all freeform (no `type`-selected
mutually-exclusive schema like `auth`/`database` on the other charts), so
those `config.*` keys are rendered via `toYaml` as-is. There's also no
database - the app is stateless.

**Note:** like `ai-server`/`email-sync-server`, the Service defaults to
port **80**, not matching `containerPort` (3000, the Docker image's own
port) - `targetPort` is always the named container port regardless of
`service.port`, so this is a normal remap, not a bug.

## Installing

```sh
helm upgrade --install dashboard ./charts/dashboard \
  --namespace dashboard --create-namespace \
  --values my-values.yaml
```

Or let the chart manage the namespace itself (see `namespace.create` below)
and only pass `--namespace`.

At minimum, override `extraEnv` (real `NEXTAUTH_URL`/Keycloak
issuer+client, and the three secrets) and `config.services`/`config.uac` -
the chart's defaults are intentionally inert (no services wired up, no
permissions granted) rather than guessing at your environment.

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
| `image.repository` / `image.tag` / `image.pullPolicy` | Container image. | `docker.io/fsarch/dashboard`, chart `appVersion`, `Always` |
| `imagePullSecrets` | Pull secrets for private registries. | `[]` |
| `podLabels` / `podAnnotations` | Extra labels/annotations on the Pod template. | `{}` |
| `podSecurityContext` / `securityContext` | Pod- / container-level `securityContext`. | `{}` |
| `serviceAccount.create` | Create a dedicated ServiceAccount. | `false` |
| `serviceAccount.name` | ServiceAccount name (generated when empty and `create: true`). | `""` |
| `service.type` / `service.port` / `service.annotations` | Service exposing the app - `service.port` is **80** here, see note above. | `ClusterIP`, `80`, `{}` |
| `containerPort` | Port the container listens on (the Docker image's own port). | `3000` |
| `env.port` | `PORT` env var (should match `containerPort`, not `service.port`). | `"3000"` |
| `env.configFilePath` | Mount path for the rendered `config.yml` (`CONFIG_FILE_PATH`). | `/etc/dashboard/config.yml` |
| `extraEnv` | NextAuth/Keycloak/HMAC env vars (see above) - pre-populated with placeholders, **must** be overridden for a working deployment. `NEXTAUTH_SECRET`/`AUTH_CLIENT_SECRET`/`CRYPTO_SECRET` are sensitive - set via `--set` or a non-committed values file. | see `values.yaml` |
| `configMap.create` | Whether to render the ConfigMap holding `config.yml`. Disable to bring your own and set `env.configFilePath` accordingly. | `true` |
| `configMap.nameOverride` | Overrides the ConfigMap name (`<fullname>-config` by default). | `""` |
| `config.services` | Federated backend services the UI can talk to. Rendered as-is via `toYaml`. | `[]` |
| `config.defaults` | Default `id` per service `type`. | `{}` |
| `config.theme` | `{primary_color, background_color}` (hex); falls back to the app's built-in defaults when empty. | `{}` |
| `config.uac` | Token-based (Keycloak realm role → permission) access control. Empty `mappings` grants nobody anything. | `{type: token-based, mappings: []}` |
| `config.tracing` | OpenTelemetry tracing (mirrors `@fsarch/server`'s built-in tracing). `null` omits the `tracing:` section entirely (off, matching the app default); set it to enable - `exporter.type` is mutually exclusive (`console`, or `otlp-http`/`otlp-grpc` which also need `url`/`headers`); `sampler` defaults to `parentbased_traceidratio` (recommended for cross-service trace correlation) if omitted. | `null` |
| `config.raw` | Literal `config.yml` content; overrides all `config.*` structured values above when set. | `""` |
| `livenessProbe` / `readinessProbe` | Probe definitions (`enabled` toggles them, remaining keys are passed through verbatim). | TCP on `http`, see `values.yaml` |
| `resources` | Container resource requests/limits. | `50m/128Mi` requests, `500m/512Mi` limits |
| `extraVolumes` / `extraVolumeMounts` | Additional volumes / mounts. | `[]` |
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling controls. | `{}` / `[]` / `{}` |
| `ingress.enabled` | Create an Ingress. | `false` |
| `ingress.className` / `ingress.annotations` / `ingress.hosts` / `ingress.tls` | Ingress configuration. | see `values.yaml` |

### Example: wiring up services, defaults, theme and uac

```yaml
config:
  services:
    - type: metric
      id: metric-main
      name: Metrics
      url: http://metric-server.fsarch.svc.cluster.local:8080
    - type: pdf-render
      id: pdf-render-main
      name: PDF Rendering
      url: http://pdf-render-server.fsarch.svc.cluster.local:3000

  defaults:
    metric:
      id: metric-main
    pdf-render:
      id: pdf-render-main

  theme:
    primary_color: "#ff69b4"

  uac:
    type: token-based
    mappings:
      - path: realm_access.roles
        value: "dashboard:access"
        operator: includes
        permissions:
          - access
      - path: realm_access.roles
        operator: map
        mappings:
          - key: "metric:access"
            permissions:
              - type: app
                value:
                  type: metric
                  id: "*"
```

### Example: enabling tracing

```yaml
config:
  tracing:
    enabled: true
    serviceName: dashboard
    sampler: parentbased_traceidratio # default, see values.yaml
    sampleRatio: 1.0
    exporter:
      type: otlp-http
      url: http://otel-collector.fsarch.svc.cluster.local:4318/v1/traces
      headers:
        Authorization: "Bearer <token>"
```

Traces the Next.js server's incoming requests and outgoing `fetch()` calls
(e.g. every backend call `fetchService` makes) - see the app repo's
`docs/tracing.md`. Uses the exact same `tracing:` schema as
`@fsarch/server`-based charts (`frontier-server` etc.), so a shared
collector correlates traces across the dashboard and the backends it calls.

### Example: real auth wiring

```yaml
extraEnv:
  - name: NEXTAUTH_URL
    value: https://dashboard.beesblog.de
  - name: NEXTAUTH_SECRET
    value: "<set via --set or a secret values file>"
  - name: AUTH_ISSUER
    value: https://login.beesblog.de/realms/beesblog
  - name: AUTH_CLIENT_ID
    value: dashboard
  - name: AUTH_CLIENT_SECRET
    value: "<set via --set or a secret values file>"
  - name: CRYPTO_SECRET
    value: "<set via --set or a secret values file>"
```

(This fully replaces the default `extraEnv` list - Helm doesn't merge
lists, so provide all six entries even if only changing one.)

### Example: bringing your own ConfigMap

```yaml
configMap:
  create: false
env:
  configFilePath: /etc/dashboard/config.yml
```