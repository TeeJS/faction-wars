# The schmitz-wars relay image: Bun, the one-file relay, and the exported web
# game baked in, so a host pulls one image and mounts only /data.
# Built and published by .github/workflows/relay-image.yml as
# ghcr.io/teejs/wars-relay. Build context is the repo root, after the web
# export has produced build/web.
FROM oven/bun:1-slim

WORKDIR /app
COPY relay/server.ts /app/server.ts
COPY build/web /web

ENV PORT=8787 \
    DATA_DIR=/data \
    STATIC_DIR=/web

VOLUME ["/data"]
EXPOSE 8787

CMD ["bun", "run", "/app/server.ts"]
