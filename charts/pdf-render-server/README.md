# pdf-render-server

Helm chart for the fsarch `pdf-render-server` service, derived from the raw
Kubernetes manifests in the
[pdf-render-server](https://gitlab.com/fsarch-infrastructure/beesblog/pdf-render-server)
repository (`k8s/namespace.yaml`, `configmap.yaml`, `deployment.yaml`, `service.yaml`).

The Deployment/Service/ServiceAccount/Namespace/Ingress templates are just
thin wrappers around the [`fsarch-common`](../fsarch-common) library chart
(see `templates/*.yaml`); only `templates/configmap.yaml` (the `config.yml`
auth/uac rendering) is specific to this app.

## Installing

```sh
helm upgrade --install pdf-render-server ./charts/pdf-render-server \
  --namespace pdf-render-server --create-namespace \
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
| `image.repository` / `image.tag` / `image.pullPolicy` | Container image. | `docker.io/fsarch/pdf-render-server`, chart `appVersion`, `Always` |
| `imagePullSecrets` | Pull secrets for private registries. | `[]` |
| `podLabels` / `podAnnotations` | Extra labels/annotations on the Pod template. | `{}` |
| `podSecurityContext` / `securityContext` | Pod- / container-level `securityContext`. | `{}` |
| `serviceAccount.create` | Create a dedicated ServiceAccount. | `false` |
| `serviceAccount.name` | ServiceAccount name (generated when empty and `create: true`). | `""` |
| `service.type` / `service.port` / `service.annotations` | Service exposing the app. | `ClusterIP`, `3000`, `{}` |
| `containerPort` | Port the container listens on. | `3000` |
| `env.port` | `PORT` env var (should match `containerPort`). | `"3000"` |
| `env.configFilePath` | Mount path for the rendered `config.yml` (`CONFIG_FILE_PATH`). | `/etc/pdf-render-server/config.yml` |
| `extraEnv` | Additional raw `EnvVar` entries appended to the container. | `[]` |
| `configMap.create` | Whether to render the ConfigMap holding `config.yml`. Disable to bring your own and set `env.configFilePath` accordingly. | `true` |
| `configMap.nameOverride` | Overrides the ConfigMap name (`<fullname>-config` by default). | `""` |
| `config.auth.type` | Auth scheme rendered into `config.yml`'s `auth:` section: `jwt-jwk` or `oidc`. Only the field(s) for the active type are rendered. | `jwt-jwk` |
| `config.auth.jwkUrl` | JWK endpoint, rendered as `auth.jwkUrl` when `config.auth.type` is `jwt-jwk`. | see `values.yaml` |
| `config.auth.discoveryUrl` | OIDC discovery URL, rendered as `auth.discovery_url` when `config.auth.type` is `oidc`. | `""` |
| `config.uac` | Structured `uac:` section (static user/permission list) rendered into `config.yml`. | see `values.yaml` |
| `config.raw` | Literal `config.yml` content; overrides `config.auth`/`config.uac` when set. | `""` |
| `livenessProbe` / `readinessProbe` | Probe definitions (`enabled` toggles them, remaining keys are passed through verbatim). | TCP on `http`, see `values.yaml` |
| `resources` | Container resource requests/limits. | `50m/128Mi` requests, `500m/512Mi` limits |
| `extraVolumes` / `extraVolumeMounts` | Additional volumes / mounts. | `[]` |
| `nodeSelector` / `tolerations` / `affinity` | Standard scheduling controls. | `{}` / `[]` / `{}` |
| `ingress.enabled` | Create an Ingress. | `false` |
| `ingress.className` / `ingress.annotations` / `ingress.hosts` / `ingress.tls` | Ingress configuration. | see `values.yaml` |

### Example: overriding name, namespace and auth users

```yaml
fullnameOverride: pdf-render-server
namespace:
  create: true
  name: beesblog

config:
  auth:
    type: jwt-jwk
    jwkUrl: https://login.example.com/protocol/openid-connect/certs
  uac:
    type: static
    users:
      - user_id: "11111111-1111-1111-1111-111111111111"
        permissions:
          - render_pdf
```

### Example: using OIDC discovery instead of a static JWK URL

```yaml
config:
  auth:
    type: oidc
    discoveryUrl: https://login.example.com/.well-known/openid-configuration
```

renders:

```yaml
auth:
  type: "oidc"
  discovery_url: "https://login.example.com/.well-known/openid-configuration"
```

### Example: bringing your own ConfigMap

```yaml
configMap:
  create: false
env:
  configFilePath: /etc/pdf-render-server/config.yml
```