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

# So `docker ps` reports healthy/unhealthy (the post-deploy check in the
# unraid-image-publishing skill); Unraid itself ignores it.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD bun -e "fetch('http://127.0.0.1:'+(process.env.PORT||8787)+'/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["bun", "run", "/app/server.ts"]
