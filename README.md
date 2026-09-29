# persistent-pi-webui

Dockerized Pi coding agent Web UI with persistent settings and workspace.

## What this provides

- Runs Pi + Pi Web UI in a container
- Exposes the web UI on the host (port `3000` by default)
- Persists config/settings across restarts
- Persists workspace files across restarts
- Suitable for detached server mode

## Files

- `Dockerfile` — builds the runtime image
- `docker-compose.yml` — starts the container with persistent volumes and a configurable host port

## Docker Compose (recommended)

From the repository directory, build and start the container in detached mode:

```bash
docker compose up -d --build
```

By default, this publishes the web UI on host port `3000`.

### Custom host port (non-root shell)

To choose a different **host** port in the Compose command, set `PI_WEBUI_PORT` before `docker compose`:

```bash
PI_WEBUI_PORT=8080 docker compose up -d --build
```

### Custom host port when using `sudo`

If you run Docker with `sudo`, the inline variable may not be preserved. Use `env` with `sudo`:

```bash
sudo env PI_WEBUI_PORT=8080 docker compose up -d --build
```

You can verify the resolved mapping before starting:

```bash
sudo env PI_WEBUI_PORT=8080 docker compose config
```

Look for:

```yaml
ports:
  - "8080:3000"
```

This publishes host port `8080` to port `3000` inside the container. Open `http://localhost:8080` on the host, or `http://<server-ip>:8080` from another machine.

### Using a `.env` file

Alternatively, put `PI_WEBUI_PORT=8080` in a `.env` file in the repository directory and run `docker compose up -d --build`.

```env
PI_WEBUI_PORT=8080
```

Do not commit secrets to `.env`.

### Troubleshooting "port is already allocated"

If you see an error like:

```text
Bind for 0.0.0.0:3000 failed: port is already allocated
```

it usually means Compose fell back to default port `3000` or another process is already using that port.

Check what is listening:

```bash
sudo lsof -iTCP:3000 -sTCP:LISTEN -P -n
```

Or check Docker port bindings:

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

Then either:

- pick another host port via `PI_WEBUI_PORT`, or
- stop/remove the conflicting container/process.

To stop and remove the compose container without deleting persistent volumes:

```bash
docker compose down
```

The Compose setup mounts named volumes `pi-config` at `/home/pi/.config/pi` and `pi-workspace` at `/home/pi/workspace`. They survive container restarts and `docker compose down`; do not use `docker compose down -v` if you want to keep data.

## Docker CLI (alternative)

Build the image:

```bash
docker build -t pi-agent .
```

Run it in detached mode with persistent volumes:

```bash
docker run -d \
  --name pi-agent \
  --restart unless-stopped \
  -p 3000:3000 \
  -v pi-config:/home/pi/.config/pi \
  -v pi-workspace:/home/pi/workspace \
  pi-agent
```

Then open `http://localhost:3000` on the host or `http://<server-ip>:3000` from another machine. For a different host port with `docker run`, change the first number in `-p`, for example `-p 8080:3000`.

The `pi-config` volume stores app config/settings/auth material; `pi-workspace` stores project files. Reuse the same volume names when recreating the container to retain data.

## Optional API key injection

If you need provider keys at runtime, add the appropriate environment variable to the `docker run` command, for example `-e OPENAI_API_KEY=...`. For Compose, uncomment and configure the `environment` section in `docker-compose.yml` and supply variables in your shell environment. Use whichever provider variables Pi expects, and avoid committing secrets.

## Verify CLI flags for your installed package version

The Dockerfile's package names and web UI command have not been verified against current upstream releases. If the image fails to build or the service fails to start, check the upstream package names and CLI options before relying on this setup. If the container is running, inspect help with:

```bash
docker exec -it pi-agent pi-web-ui --help
docker exec -it pi-agent pi-coding-agent --help
```

If needed, adjust `CMD` in `Dockerfile` to match the installed version. Do not expose an unauthenticated coding-agent web UI to the public internet; use access controls such as a VPN or authenticated reverse proxy.
