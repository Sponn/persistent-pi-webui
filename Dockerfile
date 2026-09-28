FROM node:20-slim

# Install system deps that pi's tools commonly shell out to
# (git for repo ops, python3/make/g++ for native npm builds, curl for healthchecks)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    python3 \
    make \
    g++ \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install the pi coding agent CLI and its web UI globally
RUN npm install -g @earendil-works/pi-coding-agent @earendil-works/pi-web-ui

# Create a dedicated non-root user and persistent config/workspace dirs
RUN useradd -m -s /bin/bash pi \
    && mkdir -p /home/pi/.config/pi /home/pi/workspace \
    && chown -R pi:pi /home/pi

USER pi
WORKDIR /home/pi/workspace

# Default config/data location pi should persist to
ENV PI_CONFIG_DIR=/home/pi/.config/pi
ENV HOME=/home/pi

# Web UI port
EXPOSE 3000

VOLUME ["/home/pi/.config/pi", "/home/pi/workspace"]

# Launch the web UI
CMD ["pi-web-ui", "--host", "0.0.0.0", "--port", "3000", "--config-dir", "/home/pi/.config/pi"]
