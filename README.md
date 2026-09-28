# persistent-pi-webui

Dockerized Pi coding agent Web UI with persistent settings and workspace.

## What this provides

- Runs Pi + Pi Web UI in a container
- Exposes the web UI on the host (`3000`)
- Persists config/settings across restarts
- Persists workspace files across restarts
- Suitable for detached server mode

## Files

- `Dockerfile` — builds the runtime image

## Build image

```bash
docker build -t pi-agent .
```

## Run (detached + persistent + web ui exposed)

```bash
docker run -d \
  --name pi-agent \
  --restart unless-stopped \
  -p 3000:3000 \
  -v pi-config:/home/pi/.config/pi \
  -v pi-workspace:/home/pi/workspace \
  pi-agent
```

Then open:

- `http://localhost:3000` (local machine), or
- `http://<server-ip>:3000` (remote server)

## Persistence details

- `pi-config` volume stores app config/settings/auth material.
- `pi-workspace` volume stores project files and session workspace.
- Reusing the same volume names keeps data across container restarts and re-creations.

## Optional API key injection

If you need provider keys at runtime, add env vars:

```bash
docker run -d \
  --name pi-agent \
  --restart unless-stopped \
  -p 3000:3000 \
  -v pi-config:/home/pi/.config/pi \
  -v pi-workspace:/home/pi/workspace \
  -e OPENAI_API_KEY=sk-... \
  pi-agent
```

Use whichever provider env variables Pi expects.

## Verify CLI flags for your installed package version

Because package interfaces can change, check inside the running container:

```bash
docker exec -it pi-agent pi-web-ui --help
docker exec -it pi-agent pi-coding-agent --help
```

If needed, adjust `CMD` in `Dockerfile` to match current flags.
