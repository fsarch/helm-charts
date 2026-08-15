# fsarch-common

Library chart (`type: library`) with the Deployment/Service/ServiceAccount/
Namespace/Ingress schema shared by (most) fsarch application charts: one
container, one HTTP port, an optional single-file ConfigMap mount, TCP
probes, and standard scheduling/scaling knobs.

It produces no manifests on its own - a consuming chart declares it as a
dependency and calls its named templates from its own `templates/*.yaml`.

## Using it in a new chart

1. Add the dependency in the chart's `Chart.yaml`:

   ```yaml
   dependencies:
     - name: fsarch-common
       version: "0.1.0"
       repository: "file://../fsarch-common"
   ```

   then run `helm dependency update charts/<your-chart>` to vendor it.

2. Implement the values contract below in the chart's own `values.yaml`
   (copy `charts/pdf-render-server/values.yaml` as a starting point).

3. Reference the shared templates from thin wrapper files:

   ```yaml
   # templates/deployment.yaml
   {{ include "fsarch-common.deployment" . }}
   ```

   Do the same for `service.yaml` (`fsarch-common.service`),
   `serviceaccount.yaml` (`fsarch-common.serviceaccount`), `namespace.yaml`
   (`fsarch-common.namespace-resource`), `ingress.yaml`
   (`fsarch-common.ingress`), and `NOTES.txt` (`fsarch-common.notes`).

4. If the app needs a ConfigMap, render it in the chart's own
   `templates/configmap.yaml` (app-specific content isn't part of this
   library) but reuse `fsarch-common.configMapName` /
   `fsarch-common.namespace` / `fsarch-common.labels` for its metadata so it
   lines up with what `fsarch-common.deployment` mounts.

## Values contract

The named templates read directly from the *consuming chart's* top-level
`.Values` (they are `include`d with `.`, not scoped as a subchart) - so
these keys must exist in the consuming chart's own `values.yaml`:

| Key | Used for |
| --- | --- |
| `nameOverride` / `fullnameOverride` | Resource naming |
| `namespace.create` / `namespace.name` | Namespace resource + `metadata.namespace` on everything |
| `commonLabels` / `commonAnnotations` | Merged onto every resource |
| `replicaCount` / `revisionHistoryLimit` | Deployment spec |
| `image.repository` / `image.tag` / `image.pullPolicy` | Container image |
| `imagePullSecrets` | Pod spec |
| `podLabels` / `podAnnotations` | Pod template metadata |
| `podSecurityContext` / `securityContext` | Pod / container `securityContext` |
| `serviceAccount.create` / `serviceAccount.name` / `serviceAccount.annotations` | ServiceAccount |
| `service.type` / `service.port` / `service.annotations` | Service |
| `containerPort` | Container port (named `http`) |
| `env.port` | `PORT` env var |
| `env.configFilePath` | `CONFIG_FILE_PATH` env var + ConfigMap mount path (subPath is the file's basename) |
| `extraEnv` | Additional raw `EnvVar` entries |
| `configMap.create` / `configMap.nameOverride` | Whether/how the config volume is mounted (the ConfigMap resource itself is app-specific, see above) |
| `livenessProbe` / `readinessProbe` | Probe blocks (`enabled` toggles them, remaining keys passed through) |
| `resources` | Container resources |
| `extraVolumes` / `extraVolumeMounts` | Additional volumes/mounts |
| `nodeSelector` / `tolerations` / `affinity` | Scheduling |
| `ingress.enabled` / `ingress.className` / `ingress.annotations` / `ingress.hosts` / `ingress.tls` | Ingress |

See `charts/pdf-render-server/values.yaml` for concrete defaults.
