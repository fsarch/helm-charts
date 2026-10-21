# aio-server

Helm chart for [`fsarch/aio-server`](https://github.com/fsarch/aio-server):
one process that mounts several fsarch services side by side via
`@fsarch/server`'s `FsArchAppBuilder.addService()`. Built on
[`fsarch-common`](../fsarch-common).

## Install

```sh
helm repo add fsarch https://fsarch.github.io/helm-charts
helm upgrade --install aio fsarch/aio-server -n fsarch --create-namespace -f my-values.yaml
```

## Configuration

`config.yml` consists of a `services` list plus an optional root-level
`tracing` section. There are no top-level `auth`/`database`/`uac` sections:
each mount carries its own, inside `services[].config`, in exactly the shape
that service's standalone `config.yml` uses (see the matching single-service
chart in this repo for the options per section).

| Value | Description |
| --- | --- |
| `config.services` | Freeform list of mounts, rendered verbatim. Each entry: `id` (route prefix + TypeORM connection name, unique), `type` (service package, see below), `config` (that service's own config). Must not be empty. |
| `config.tracing` | Root-level OpenTelemetry config, shared by all mounts. `null` omits it. |
| `config.raw` | Used verbatim as `config.yml` when non-empty; bypasses everything above. |

Known `type`s: `calendar-server`, `metric-server`, `function-gateway`,
`function-server`, `function-node-worker`, `image-editor-server`,
`image-server`, `frontier-api`. The same `type` can be mounted more than once
under different `id`s.

### Example

```yaml
config:
  services:
    - id: calendar
      type: calendar-server
      config:
        auth:
          type: oidc
          discovery_url: https://login.example.com/realms/fsarch/.well-known/openid-configuration
        database:
          type: postgres
          host: postgres.fsarch.svc.cluster.local
          port: 5432
          database: calendar
          username: calendar
          password: "<secret>"
        deletion:
          hard_delete_after_days: 30
          purge_schedule:
            cron: "0 0 * * *"
            timezone: Europe/Berlin

    - id: metric
      type: metric-server
      config:
        auth:
          type: oidc
          discovery_url: https://login.example.com/realms/fsarch/.well-known/openid-configuration
        database:
          type: postgres
          host: postgres.fsarch.svc.cluster.local
          port: 5432
          database: metric
          username: metric
          password: "<secret>"
        uac:
          type: static
          users:
            - user_id: "<user id>"
              permissions: ["manage_metrics", "read_metrics", "write_measurements"]
```

### Notes

- Every mount gets its own TypeORM connection, even services without entities
  of their own (`function-node-worker`), so each entry needs a `database`
  section.
- With `database.type: sqlite` (or `image-server`'s filesystem storage), the
  paths have to point at a writable volume - add one via `extraVolumes` /
  `extraVolumeMounts`; the image's working directory isn't writable for the
  `node` user.
- The image includes Chromium for `image-editor-server`'s html-layer
  rendering, and the default `resources` are sized for several mounts in one
  pod - adjust both to what you actually mount.
- `image.tag` defaults to `latest` until the first versioned aio-server
  release; from then on `bump-chart.yaml` pins it on every stable release.
