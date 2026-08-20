# function-node-worker

Helm chart for the fsarch `function-node-worker` service
([source](https://github.com/fsarch/function-node-worker)) - a worker that
polls `function-server` for Node.js functions to execute and reports
results back.

The Deployment/Service/ServiceAccount/Namespace/Ingress templates are just
thin wrappers around the [`fsarch-common`](../fsarch-common) library chart
(see `templates/*.yaml`); only `templates/configmap.yaml` (the `config.yml`
rendering) is specific to this app.

**Config differs from every other chart here:**
- `config.auth.type` only supports `jwt-jwk`/`static` - no `oidc` module is
  registered in this app.
- `uac`/`database` are **not** rendered at all, even though this app's
  vendored config types and its own example `config.yml` still mention
  them - its `app.module.ts` only enables the `auth` module
  (`FsarchModule.register({ auth: {} })`), so those sections are dead
  config with zero effect. This chart intentionally leaves them out (use
  `config.raw` if you want to keep them for parity with other services'
  config files anyway).
- Instead it has two sections unique to this app: `worker_auth` (how this
  worker authenticates itself to `function-server` via OAuth2 client
  credentials) and `function_server` (the `function-server` instance to
  poll, `type` is always `"remote"`, plus its own nested client-credentials
  `auth` block - not necessarily the same client as `worker_auth`, the app
  keeps them as two independent config blocks).

## Installing

```sh
helm upgrade --install function-node-worker ./charts/function-node-worker \
  --namespace function-node-worker --create-namespace \
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
| `image.repository` / `image.tag` / `image.pullPolicy` | Container image. | `docker.io/fsarch/function-node-worker`, chart `appVersion`, `Always` |
| `imagePullSecrets` | Pull secrets for private registries. | `[]` |
| `podLabels` / `podAnnotations` | Extra labels/annotations on the Pod template. | `{}` |
| `podSecurityContext` / `securityContext` | Pod- / container-level `securityContext`. | `{}` |
| `serviceAccount.create` | Create a dedicated ServiceAccount. | `false` |
| `serviceAccount.name` | ServiceAccount name (generated when empty and `create: true`). | `""` |
| `service.type` / `service.port` / `service.annotations` | Service exposing the app. | `ClusterIP`, `8080`, `{}` |
| `containerPort` | Port the container listens on. | `8080` |
| `env.port` | `PORT` env var (should match `containerPort`). | `"8080"` |
| `env.configFilePath` | Mount path for the rendered `config.yml` (`CONFIG_FILE_PATH`). | `/etc/function-node-worker/config.yml` |
| `extraEnv` | Additional raw `EnvVar` entries appended to the container. | `[]` |
| `configMap.create` | Whether to render the ConfigMap holding `config.yml`. Disable to bring your own and set `env.configFilePath` accordingly. | `true` |
| `configMap.nameOverride` | Overrides the ConfigMap name (`<fullname>-config` by default). | `""` |
| `config.auth.type` | Auth scheme rendered into `config.yml`'s `auth:` section: `jwt-jwk` or `static`. Only the field(s) for the active type are rendered. | `jwt-jwk` |
| `config.auth.jwkUrl` | JWK endpoint, rendered as `auth.jwkUrl` when `config.auth.type` is `jwt-jwk`. | see `values.yaml` |
| `config.auth.secret` / `config.auth.users` | Shared secret + local user list, rendered when `config.auth.type` is `static`. `secret` is sensitive - set via `--set` or a non-committed values file. | `""` / `[]` |
| `config.workerAuth.tokenEndpoint` / `.clientId` / `.clientSecret` | OAuth2 client-credentials this worker uses to call `function-server`. `clientSecret` is sensitive - set via `--set` or a non-committed values file. | see `values.yaml` |
| `config.functionServer.url` | Base URL of the `function-server` instance to poll. | `http://function-server.example.com` |
| `config.functionServer.auth.tokenEndpoint` / `.clientId` / `.clientSecret` | OAuth2 client-credentials nested under `function_server.auth`. `clientSecret` is sensitive - set via `--set` or a non-committed values file. | see `values.yaml` |
| `config.raw` | Literal `config.yml` content; overrides all `config.*` structured values above when set. | `""` |
| `livenessProbe` / `readinessProbe` | Probe definitions (`enabled` toggles them, remaining keys are passed through verbatim). | TCP on `http`, see `values.yaml` |
| `resources` | Container resource requests/limits. | `50m/128Mi` requests, `500m/512Mi` limits |
| `extraVolumes` / `extraVolumeMounts` | Additional volumes / mounts. | `[]` |
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling controls. | `{}` / `[]` / `{}` |
| `ingress.enabled` | Create an Ingress. | `false` |
| `ingress.className` / `ingress.annotations` / `ingress.hosts` / `ingress.tls` | Ingress configuration. | see `values.yaml` |

### Example: pointing at a real function-server + worker credentials

```yaml
config:
  workerAuth:
    tokenEndpoint: https://login.example.com/realms/fsarch/protocol/openid-connect/token
    clientId: function-node-worker
    clientSecret: "<set via --set or a secret values file>"
  functionServer:
    url: http://function-server.fsarch.svc.cluster.local:8080
    auth:
      tokenEndpoint: https://login.example.com/realms/fsarch/protocol/openid-connect/token
      clientId: function-node-worker
      clientSecret: "<set via --set or a secret values file>"
```

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

### Example: bringing your own ConfigMap

```yaml
configMap:
  create: false
env:
  configFilePath: /etc/function-node-worker/config.yml
```
