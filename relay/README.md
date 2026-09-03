# schmitz-wars relay

A WebSocket relay for head-to-head games (docs/m3-plan.md). It keeps rooms,
forwards each side's lines to the other, stores every line in an append-only
log per room, and replays that log to a client that rejoins. It never runs the
game.

## Run it

```
bun run relay/server.ts              # PORT (8787), DATA_DIR (./data), STATIC_DIR (unset)
bun run relay/test.ts                # two fake clients on a random port
```

`GET /healthz` → `ok`. `GET /rooms` → the open games. Everything else is the
WebSocket at `/ws`.

## The image

`ghcr.io/teejs/wars-relay:latest` - Bun, `server.ts`, and the exported web game
baked in (`relay/Dockerfile`). `.github/workflows/relay-image.yml` builds it on
every push to `main`: it downloads Godot 4.7.1 and the web export templates,
exports the `Web` preset, and pushes `:latest` and `:<sha>` to GHCR. The
package must be **public** once (GitHub -> Packages -> wars-relay -> Package
settings -> Change visibility), or Unraid cannot pull it without a login.

## Deploy (Unraid + NGINX Proxy Manager Plus)

1. Template: `relay/unraid/my-wars-relay.xml` ->
   `/boot/config/plugins/dockerMan/templates-user/my-wars-relay.xml`.
2. Unraid -> Docker -> Add Container -> Template **wars-relay**. Defaults:
   the image above, bridge network, host port 8787, `/mnt/user/appdata/wars-relay/data`
   for the rooms. Apply, then toggle **Autostart** (no Docker restart policy: Unraid
   handles startup). New builds arrive with Unraid's "check for updates".
3. NPM Plus -> Proxy Hosts -> Add: domain `wars.schmitzplex.com`, scheme http,
   forward host `192.168.1.25`, port `8787`, **Websockets Support on**, SSL as
   for the other hosts. No Authelia on this host: the game code is the
   credential, and the WebSocket upgrade would not follow Authelia's redirect.
4. DNS: `wars` like the other `*.schmitzplex.com` names (done 2026-09-03).
5. `curl https://wars.schmitzplex.com/healthz` -> `ok`; the game at
   `https://wars.schmitzplex.com/`.

`docker-compose.yml` is kept for a non-Unraid host; it runs the same image.

## Limits

64 KB per line, 2 clients per room, 100 rooms. In `LIMITS` at the top of
`server.ts`.
