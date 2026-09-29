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

By default, this publishes the web UI on host port `3000`. To choose a different **host** port in the Compose command, set `PI_WEBUI_PORT` before `docker compose`:

```bash
PI_WEBUI_PORT=8080 docker compose up -d --build
```

This publishes host port `8080` to port `3000` inside the container. Open `http://localhost:8080` on the host, or `http://<server-ip>:8080` from another machine. If you don't set `PI_WEBUI_PORT`, use port `3000` instead.

Alternatively, put `PI_WEBUI_PORT=8080` in a `.env` file in the repository directory and run `docker compose up -d --build`. Do not commit secrets to `.env`.

To stop and remove the container without deleting its volumes:

```bash
docker compose down
```

The Compose setup mounts named volumes `pi-config` at `/home/pi/.config/pi` and `pi-workspace` at `/home/pi/workspace`. They survive container restarts and `docker compose down`; do not use `docker compose down -v` if you want to keep the data.

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

If you need provider keys at runtime, add the appropriate environment variable to the `docker run` command, for example `-e OPENAI_API_KEY=...`. For Compose, uncomment and configure the `environment` section in `docker-compose.yml` and supply the variable in your shell environment. Use whichever provider variables Pi expects, and avoid committing secrets.

## Verify CLI flags for your installed package version

The Dockerfile's package names and web UI command have not been verified against current upstream releases. If the image fails to build or the service fails to start, check the upstream package names and CLI options before relying on this setup. If the container is running, inspect help with:

```bash
docker exec -it pi-agent pi-web-ui --help
docker exec -it pi-agent pi-coding-agent --help
```

If needed, adjust `CMD` in `Dockerfile` to match the installed version. Do not expose an unauthenticated coding-agent web UI to the public internet; use access controls such as a VPN or authenticated reverse proxy.
