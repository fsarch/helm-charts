# ai-server

Helm chart for the fsarch `ai-server` service
([source](https://github.com/fsarch/ai-server)) - an LLM/MCP gateway that
proxies chat/tool-call requests to configured AI providers and MCP servers.

The Deployment/Service/ServiceAccount/Namespace/Ingress templates are just
thin wrappers around the [`fsarch-common`](../fsarch-common) library chart
(see `templates/*.yaml`); only `templates/configmap.yaml` (the `config.yml`
rendering) is specific to this app.

`config.yml` has `auth`/`uac`/`database` (same pattern as `metric-server`/
`product-server` - `ai-server` vendors its own local copy of the framework
rather than depending on `@fsarch/server`, but implements the same shape)
plus two freeform sections genuinely read via direct property access
(`src/repositories/mcp-proxy.service.ts` / `openai.service.ts`) rather than
the `ModuleConfiguration.register(...)` pattern used elsewhere:
- `mcp` - MCP servers this app can proxy tool calls to.
- `providers` - LLM providers (only `type: open-ai` is actually
  implemented today).

**Note:** unlike every other chart here, the Service defaults to port
**80**, not matching `containerPort` (8080, the Docker image's own port) -
`targetPort` is always the named container port regardless of
`service.port`, so this is a normal remap, not a bug.

## Installing

```sh
helm upgrade --install ai-server ./charts/ai-server \
  --namespace ai-server --create-namespace \
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
| `image.repository` / `image.tag` / `image.pullPolicy` | Container image. | `docker.io/fsarch/ai-server`, chart `appVersion`, `Always` |
| `imagePullSecrets` | Pull secrets for private registries. | `[]` |
| `podLabels` / `podAnnotations` | Extra labels/annotations on the Pod template. | `{}` |
| `podSecurityContext` / `securityContext` | Pod- / container-level `securityContext`. | `{}` |
| `serviceAccount.create` | Create a dedicated ServiceAccount. | `false` |
| `serviceAccount.name` | ServiceAccount name (generated when empty and `create: true`). | `""` |
| `service.type` / `service.port` / `service.annotations` | Service exposing the app - `service.port` is **80** here, see note above. | `ClusterIP`, `80`, `{}` |
| `containerPort` | Port the container listens on (the Docker image's own port). | `8080` |
| `env.port` | `PORT` env var (should match `containerPort`, not `service.port`). | `"8080"` |
| `env.configFilePath` | Mount path for the rendered `config.yml` (`CONFIG_FILE_PATH`). | `/etc/ai-server/config.yml` |
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
| `config.mcp` | Freeform list of MCP servers to proxy tool calls to. Rendered as-is via `toYaml`. | `[]` |
| `config.providers` | Freeform list of LLM providers (only `type: open-ai` is implemented). Rendered as-is via `toYaml`; `api_key` is sensitive - set via `--set` or a non-committed values file. | `[]` |
| `config.tracing` | OpenTelemetry tracing, matching `@fsarch/server`'s config shape. `null` omits the `tracing:` section entirely; set it to enable - `exporter.type` is mutually exclusive (`console`, or `otlp-http`/`otlp-grpc` which also need `url`/`headers`); `sampler` defaults to `parentbased_traceidratio` if omitted. **Has no effect at all** - ai-server doesn't depend on `@fsarch/server` (its own local framework) and tracing hasn't been ported into it yet, see values.yaml's comment. | `null` |
| `config.raw` | Literal `config.yml` content; overrides all `config.*` structured values above when set. | `""` |
| `livenessProbe` / `readinessProbe` | Probe definitions (`enabled` toggles them, remaining keys are passed through verbatim). | TCP on `http`, see `values.yaml` |
| `resources` | Container resource requests/limits. | `50m/128Mi` requests, `500m/512Mi` limits |
| `extraVolumes` / `extraVolumeMounts` | Additional volumes / mounts. | `[]` |
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling controls. | `{}` / `[]` / `{}` |
| `ingress.enabled` | Create an Ingress. | `false` |
| `ingress.className` / `ingress.annotations` / `ingress.hosts` / `ingress.tls` | Ingress configuration. | see `values.yaml` |

### Example: wiring up an OpenAI provider and an MCP server (matches the app repo's own config.yml)

```yaml
config:
  providers:
    - type: open-ai
      id: open-ai
      api_key: "<set via --set or a secret values file>"
      models:
        - id: gpt-4
          name: GPT-4
  mcp:
    - id: material-tracing
      url: http://material-tracing-server.fsarch.svc.cluster.local:8080/.ai
      auth:
        type: credential-propagation
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

### Example: bringing your own ConfigMap

```yaml
configMap:
  create: false
env:
  configFilePath: /etc/ai-server/config.yml
```
