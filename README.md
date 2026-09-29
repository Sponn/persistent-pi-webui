# persistent-pi-webui

Docker Compose setup for [PI WEB](https://github.com/jmfederico/pi-web) (`@jmfederico/pi-web`), the web UI for the
[Pi coding agent](https://github.com/earendil-works/pi) (`@earendil-works/pi-coding-agent`). Settings, credentials, sessions, and
workspace files persist across restarts.

## What this provides

It follows the split layout used by [PI WEB's own Docker setup](https://github.com/jmfederico/pi-web/tree/main/docker), but is much smaller:

| Service       | Command           | Purpose                                                                                     |
| ------------- | ----------------- | ------------------------------------------------------------------------------------------- |
| `volume-init` | one-shot (root)   | Creates the data directories and fixes ownership, then exits with code `0`. |
| `sessiond`    | `pi-web-sessiond` | Long-running session daemon that owns the Pi agent sessions. |
| `web`         | `pi-web-server`   | Web UI and API on container port `8504`. It connects to `sessiond` through a Unix socket on the shared volume. |

- Image: `node:22-bookworm-slim`. Both packages require Node.js >= 22.19, and the build fails if the version is too old.
- Pi Coding Agent gets installed as PI WEB's npm peer dependency, and the `pi` CLI is on `PATH`.
- Services run as the non-root `node` user (UID/GID `1000`).
- Healthchecks: `sessiond` is healthy once its socket exists. `web` is healthy once `GET /api/pi-web/runtime` succeeds.
- The web UI is published on **host port `3000`** by default. It's bound to **`127.0.0.1` (loopback)** by default. See [Remote access](#remote-access).

## Quick start

From the repository directory:

```bash
docker compose up -d --build
docker compose ps -a
```

Open <http://127.0.0.1:3000> on the Docker host. In the UI, choose **Actions → Add Project** and enter a folder under
`/workspace`, for example `/workspace/myproject`. Then start a session with **+**.

## Custom host port

Set `PI_WEBUI_PORT` to choose the host port. The container always listens on `8504`.

```bash
PI_WEBUI_PORT=3004 docker compose up -d --build
```

### With `sudo`

`sudo` drops variables that you set before it (for example, `PI_WEBUI_PORT=3004 sudo docker compose ...`). Compose then
falls back to port `3000`. Put `env` **after** `sudo` instead:

```bash
# Preflight: check the resolved port mapping first
sudo env PI_WEBUI_PORT=3004 docker compose config

# Build and start
sudo env PI_WEBUI_PORT=3004 docker compose up -d --build
```

In the `config` output, the `web` service should show:

```yaml
    ports:
      - mode: ingress
        host_ip: 127.0.0.1
        target: 8504
        published: "3004"
```

### Using a `.env` file

You can also create a `.env` file next to `docker-compose.yml`. Compose reads it automatically, including under `sudo`.

```env
PI_WEBUI_PORT=3004
# PI_WEBUI_BIND_ADDR=127.0.0.1
# PI_WEB_VERSION=latest
```

Do not commit secrets to `.env`.

## Remote access

PI WEB lets anyone who can reach it run commands and edit files as the agent. It **has no built-in login**, so the port
is only published on `127.0.0.1` by default. Do not expose it directly to the public internet. Pick one of these options
for remote access:

- **SSH tunnel** (recommended). From your laptop, run the command below, then open <http://127.0.0.1:3004>:

  ```bash
  ssh -L 3004:127.0.0.1:3004 user@server
  ```

- **VPN/private network** (Tailscale, WireGuard, …). Bind to that private interface address:

  ```bash
  sudo env PI_WEBUI_PORT=3004 PI_WEBUI_BIND_ADDR=100.x.y.z docker compose up -d --build
  ```

- **Authenticated reverse proxy** (with TLS) that you operate. Keep the default loopback binding and point the proxy at
  `127.0.0.1:${PI_WEBUI_PORT}`. The proxy must forward WebSocket traffic.

`PI_WEBUI_BIND_ADDR=0.0.0.0` publishes the UI on every interface, with no authentication. Use it only when a firewall or
another trusted layer restricts access.

## Provider login / API keys

Pi stores its credentials in the persistent `/data/pi-agent` directory. You can log in in either of two ways:

- from the PI WEB UI; or
- with the Pi CLI inside the session daemon container. Run `/login` inside Pi:

  ```bash
  sudo docker compose exec -it sessiond pi
  ```

If you'd rather use environment variables, uncomment and adapt the example in the `x-pi-environment` block of
`docker-compose.yml`. Then recreate the services with `docker compose up -d`.

## Persistence

| Volume         | Mounted at   | Contents                                                                                            |
| -------------- | ------------ | --------------------------------------------------------------------------------------------------- |
| `pi-data`      | `/data`      | `HOME` (`/data/home`), `XDG_CONFIG_HOME` (`/data/config`), PI WEB state (`/data/pi-web`), Pi agent auth/settings/sessions (`PI_CODING_AGENT_DIR=/data/pi-agent`) |
| `pi-workspace` | `/workspace` | Your project files                                                                                  |
| `pi-config`    | —            | Legacy volume from the previous setup. It's kept but not used. See [Migrating](#migrating-from-the-previous-single-container-setup). |

The volumes survive restarts, rebuilds, and `docker compose down`. **Do not run `docker compose down -v`**, because that
deletes them.

To put existing code into the workspace, you can either `git clone` it from the PI WEB terminal, or copy it in:

```bash
sudo docker compose cp ./myproject web:/workspace/myproject
# docker cp keeps the host file owner; hand the files to the container user (UID 1000)
sudo docker compose exec -u 0 web chown -R 1000:1000 /workspace/myproject
```

## Updating

The image installs `@jmfederico/pi-web@latest` by default. To pin a version, set `PI_WEB_VERSION`, for example
`PI_WEB_VERSION=1.202609.1`. To pick up a new release, rebuild without cache:

```bash
sudo docker compose build --pull --no-cache
sudo env PI_WEBUI_PORT=3004 docker compose up -d
```

Recreating `sessiond` stops agent runs that are still active, so update while sessions are idle.

## Migrating from the previous single-container setup

The earlier version of this repository never worked and got stuck in a restart loop. It had these problems:

- it installed `@earendil-works/pi-web-ui`, a library with **no `pi-web-ui` executable**, so the container exited immediately;
- it used Node 20, while Pi and PI WEB require Node >= 22.19;
- it used made-up CLI flags and a made-up config path.

To switch over **without deleting data**:

```bash
cd persistent-pi-webui
git pull
sudo docker compose down --remove-orphans      # removes the old pi-agent container; volumes are kept (no -v!)
sudo docker rm -f pi-agent 2>/dev/null || true # only if an old pi-agent container is still around
sudo env PI_WEBUI_PORT=3004 docker compose config
sudo env PI_WEBUI_PORT=3004 docker compose up -d --build --remove-orphans
```

- The existing `pi-workspace` volume is reused at `/workspace`. On first start, `volume-init` changes its owner from the
  old image's `pi` user (UID 1001) to UID 1000.
- The old `pi-config` volume was mounted at a path that neither Pi nor PI WEB reads, so it most likely holds nothing
  useful. It's kept anyway and mounted read-only in `volume-init` at `/legacy/pi-config`. To inspect it:

  ```bash
  sudo docker compose run --rm volume-init ls -la /legacy/pi-config
  ```

## Healthcheck / smoke test

```bash
sudo docker compose ps -a    # sessiond and web: "Up ... (healthy)"; volume-init: "Exited (0)"
curl -fsS http://127.0.0.1:3004/api/pi-web/health   # {"ok":true}
curl -fsS http://127.0.0.1:3004/api/pi-web/runtime  # web and sessiond both "available": true
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3004/   # 200
```

Replace `3004` with your `PI_WEBUI_PORT` (default `3000`).

## Troubleshooting

When reporting a problem, include the output of:

```bash
sudo docker compose ps -a
sudo docker compose logs --tail=100
```

### "port is already allocated"

```text
Bind for 127.0.0.1:3000 failed: port is already allocated
```

This means Compose used the default port `3000`, often because a variable set before `sudo` was dropped, or that
another process already holds the port. Check the resolved mapping with `sudo env PI_WEBUI_PORT=3004 docker compose config`.
Then find what is listening:

```bash
sudo lsof -iTCP:3000 -sTCP:LISTEN -P -n
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

### Container keeps restarting

Check `sudo docker compose logs --tail=100 sessiond web`. Only one session daemon may use `/data/pi-web` at a time, so
don't run a second copy of this stack against the same volumes. After a crash, `sessiond` normally recovers its stale
owner marker automatically. If it still refuses to start, stop the stack with `docker compose down` (without `-v`) and
start it again.
