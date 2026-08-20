# frontier-worker

Helm chart for the fsarch `frontier-worker` service
([source](https://github.com/fsarch/frontier-server), `apps/frontier-worker`
in that monorepo) - an HTTP proxy worker that connects out to
`frontier-server` (the app repo's `apps/frontier-api`, published as
`fsarch/frontier-server` - see the sibling chart) over a websocket
control-plane connection, applies the routing/policy snapshot it receives,
and reports request logs back.

The Deployment/Service/ServiceAccount/Namespace/Ingress templates are just
thin wrappers around the [`fsarch-common`](../fsarch-common) library chart
(see `templates/*.yaml`); only `templates/configmap.yaml` is specific to
this app, and even that is optional (see below).

**The `frontier-server` monorepo has two deployables** - this chart
(`apps/frontier-worker`) and the sibling
[`frontier-server`](../frontier-server) chart (`apps/frontier-api`), each
with its own image repository (`fsarch/frontier-worker` /
`fsarch/frontier-server`).

**Architecturally very different from every other chart here:**
- No `@fsarch/server`, no database, not even NestJS - it's a small
  standalone Node process. Almost everything is env vars (`extraEnv`,
  pre-populated with the three required ones below), not `config.yml`.
- `config.yml` only ever holds one optional key, `function_worker:` (a
  function-node-worker instance frontier-worker can additionally dispatch
  to) - the app loads it best-effort and silently continues without it if
  missing, so `configMap.create` defaults to `false` here (unlike every
  other chart, where the ConfigMap is essential). Enable it and add
  `FRONTIER_WORKER_CONFIG_PATH` to `extraEnv` (see the values.yaml comment)
  to wire it up.
- The app reads `FRONTIER_WORKER_PORT`, not `PORT` - `env.port` is left
  empty and the real port var is set via `extraEnv` instead.

## Installing

```sh
helm upgrade --install frontier-worker ./charts/frontier-worker \
  --namespace frontier --create-namespace \
  --values my-values.yaml
```

Or let the chart manage the namespace itself (see `namespace.create` below)
and only pass `--namespace`.

At minimum, override `extraEnv`'s `FRONTIER_CONTROL_PLANE_URL` (pointing at
your `frontier-server` deployment) and `FRONTIER_WORKER_AUTH_TOKEN` (matching
that `frontier-server` release's `config.workers.websocket.authToken`) - the
chart's placeholder defaults won't connect to anything real.

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
| `image.repository` / `image.tag` / `image.pullPolicy` | Container image. | `docker.io/fsarch/frontier-worker`, chart `appVersion`, `Always` |
| `imagePullSecrets` | Pull secrets for private registries. | `[]` |
| `podLabels` / `podAnnotations` | Extra labels/annotations on the Pod template. | `{}` |
| `podSecurityContext` / `securityContext` | Pod- / container-level `securityContext`. | `{}` |
| `serviceAccount.create` | Create a dedicated ServiceAccount. | `false` |
| `serviceAccount.name` | ServiceAccount name (generated when empty and `create: true`). | `""` |
| `service.type` / `service.port` / `service.annotations` | Service exposing the app. | `ClusterIP`, `8080`, `{}` |
| `containerPort` | Port the container listens on. | `8080` |
| `env.port` | `PORT` env var. Left empty - the app doesn't read `PORT`, see `extraEnv`. | `""` |
| `env.configFilePath` | Mount path for the rendered `config.yml`, used only when `configMap.create: true`. | `/etc/frontier-worker/config.yml` |
| `extraEnv` | `FRONTIER_WORKER_PORT` / `FRONTIER_CONTROL_PLANE_URL` / `FRONTIER_WORKER_AUTH_TOKEN` pre-populated with placeholders - **must** be overridden for a working deployment. `FRONTIER_WORKER_AUTH_TOKEN` is sensitive - set via `--set` or a non-committed values file. | see `values.yaml` |
| `configMap.create` | Whether to render the ConfigMap holding the optional `function_worker:` config.yml. | `false` |
| `configMap.nameOverride` | Overrides the ConfigMap name (`<fullname>-config` by default). | `""` |
| `config.functionWorker.url` | Base URL of the function-node-worker instance to additionally dispatch to. | `http://function-node-worker.example.com` |
| `config.functionWorker.auth.tokenEndpoint` / `.clientId` / `.clientSecret` | OAuth2 client-credentials for that dispatch. `clientSecret` is sensitive - set via `--set` or a non-committed values file. | see `values.yaml` |
| `config.raw` | Literal `config.yml` content; overrides `config.functionWorker` when set. | `""` |
| `livenessProbe` / `readinessProbe` | Probe definitions (`enabled` toggles them, remaining keys are passed through verbatim). | TCP on `http`, see `values.yaml` |
| `resources` | Container resource requests/limits. | `50m/128Mi` requests, `500m/512Mi` limits |
| `extraVolumes` / `extraVolumeMounts` | Additional volumes / mounts. | `[]` |
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling controls. | `{}` / `[]` / `{}` |
| `ingress.enabled` | Create an Ingress. | `false` |
| `ingress.className` / `ingress.annotations` / `ingress.hosts` / `ingress.tls` | Ingress configuration. | see `values.yaml` |

### Example: pointing at a real frontier-server

```yaml
extraEnv:
  - name: FRONTIER_WORKER_PORT
    value: "8080"
  - name: FRONTIER_CONTROL_PLANE_URL
    value: ws://frontier-server.frontier.svc.cluster.local:8080/api/workers/websocket
  - name: FRONTIER_WORKER_AUTH_TOKEN
    value: "<set via --set or a secret values file, matches frontier-server's config.workers.websocket.authToken>"
```

(This fully replaces the default `extraEnv` list - Helm doesn't merge
lists, so provide all three entries even if only changing one.)

### Example: enabling the optional function_worker integration

```yaml
configMap:
  create: true
extraEnv:
  - name: FRONTIER_WORKER_PORT
    value: "8080"
  - name: FRONTIER_CONTROL_PLANE_URL
    value: ws://frontier-server.frontier.svc.cluster.local:8080/api/workers/websocket
  - name: FRONTIER_WORKER_AUTH_TOKEN
    value: "<...>"
  - name: FRONTIER_WORKER_CONFIG_PATH
    value: /etc/frontier-worker/config.yml   # must match env.configFilePath
config:
  functionWorker:
    url: http://function-node-worker.fsarch.svc.cluster.local:8080
    auth:
      tokenEndpoint: https://login.example.com/realms/fsarch/protocol/openid-connect/token
      clientId: frontier-worker
      clientSecret: "<set via --set or a secret values file>"
```
