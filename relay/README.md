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

## Deploy (Unraid + NGINX Proxy Manager Plus)

1. Copy this folder to `/mnt/user/appdata/wars-relay/` and put the exported
   `build/web/*` files in `wars-relay/web/`.
2. `docker compose up -d` in that folder. The compose file joins the `proxy`
   network NPM Plus uses; change the network name if yours differs.
3. NPM Plus → Proxy Hosts → Add: domain `wars.schmitzplex.com`, scheme http,
   forward host `wars-relay`, port `8787`, **Websockets Support on**, SSL as
   for the other hosts. No Authelia on this host: the game code is the
   credential, and the WebSocket upgrade would not follow Authelia's redirect.
4. DNS: `wars` like the other `*.schmitzplex.com` names.
5. `curl https://wars.schmitzplex.com/healthz` → `ok`; the game at
   `https://wars.schmitzplex.com/`.

## Limits

64 KB per line, 2 clients per room, 100 rooms. In `LIMITS` at the top of
`server.ts`.
