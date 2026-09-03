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

Unraid runs containers from templates, not compose. `unraid/my-wars-relay.xml`
is the template.

1. Copy to the box: `relay/server.ts` -> `/mnt/user/appdata/wars-relay/server.ts`,
   the exported `build/web/*` -> `/mnt/user/appdata/wars-relay/web/`, and the
   template -> `/boot/config/plugins/dockerMan/templates-user/my-wars-relay.xml`.
2. Unraid -> Docker -> Add Container -> Template: **wars-relay**. The defaults
   are the paths above, bridge network, host port 8787. Apply.
3. NPM Plus -> Proxy Hosts -> Add: domain `wars.schmitzplex.com`, scheme http,
   forward host `192.168.1.25`, port `8787`, **Websockets Support on**, SSL as
   for the other hosts. No Authelia on this host: the game code is the
   credential, and the WebSocket upgrade would not follow Authelia's redirect.
   (If NPM Plus is on a custom Docker network, the container can join it
   instead and be forwarded as `wars-relay:8787`.)
4. DNS: `wars` like the other `*.schmitzplex.com` names (done 2026-09-03).
5. `curl https://wars.schmitzplex.com/healthz` -> `ok`; the game at
   `https://wars.schmitzplex.com/`.

`docker-compose.yml` is kept for a non-Unraid host.

## Limits

64 KB per line, 2 clients per room, 100 rooms. In `LIMITS` at the top of
`server.ts`.
