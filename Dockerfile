# PI WEB (https://github.com/jmfederico/pi-web) + Pi coding agent
# (https://github.com/earendil-works/pi) in a persistent container.
#
# Both npm packages require Node.js >= 22.19, so this image is based on the
# official Node 22 image (the build fails fast if the version is too old).
ARG NODE_IMAGE=node:22-bookworm-slim

FROM ${NODE_IMAGE}

# @jmfederico/pi-web npm version/range. Pi Coding Agent is installed as its
# npm peer dependency (newest compatible version), like the upstream image.
ARG PI_WEB_VERSION=latest

ENV NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false \
    SHELL=/bin/bash \
    TERM=xterm-256color

# Tools the agent and PI WEB shell out to; python3/make/g++ allow native npm
# modules (node-pty) to build when no prebuilt binary is available.
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      g++ \
      make \
      openssh-client \
      procps \
      python3 \
      ripgrep \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    node -e 'const [a,b]=process.versions.node.split(".").map(Number); if (a<22||(a===22&&b<19)) { console.error("Node >= 22.19 required, found " + process.versions.node); process.exit(1); }'; \
    npm install -g --omit=dev --include=peer "@jmfederico/pi-web@${PI_WEB_VERSION}"; \
    global_root="$(npm root -g)"; \
    global_prefix="$(npm prefix -g)"; \
    peer_pi_bin="${global_root}/@jmfederico/pi-web/node_modules/.bin/pi"; \
    if [ -x "${peer_pi_bin}" ]; then ln -sf "${peer_pi_bin}" "${global_prefix}/bin/pi"; fi; \
    command -v pi-web-server; \
    command -v pi-web-sessiond; \
    command -v pi; \
    npm cache clean --force

# Persistent state lives under /data (see docker-compose.yml); project files
# live under /workspace. Both are owned by the image's non-root `node` user
# (UID/GID 1000).
ENV HOME=/data/home \
    XDG_CONFIG_HOME=/data/config \
    PI_WEB_DATA_DIR=/data/pi-web \
    PI_WEB_SESSIOND_SOCKET=/data/pi-web/sessiond.sock \
    PI_CODING_AGENT_DIR=/data/pi-agent \
    PI_WEB_HOST=0.0.0.0 \
    PI_WEB_PORT=8504

RUN mkdir -p /data/home /data/config /data/pi-web /data/pi-agent /workspace \
    && chown -R node:node /data /workspace

USER node
WORKDIR /workspace

EXPOSE 8504

CMD ["pi-web-server"]
