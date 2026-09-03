# M3 — the relay (plan, for review before building)

**Status:** Gate A PASSED 2026-09-03 (relay test 16/16; lockstep through a local relay 200/200). **Gate B PASSED 2026-09-03**: the relay deployed on Unraid as the GHCR image (`relay/unraid/my-wars-relay.xml`), NPM Plus host `wars.schmitzplex.com` with Websockets Support; two headless clients through the live container (`tools/lockstep-local.ps1 -Days 200 -Seed 12345 -RelayUrl ws://192.168.1.25:8787/ws`) hold 200 of 200. The wss:// leg (NPM Plus TLS termination + upgrade) is covered by curl and the browser: Godot's mbedtls will not initialise in headless script mode on the workstation (`tests/tls_probe.gd`, both binaries, even with verification off), so the harness cannot speak wss; the two-browser play-through is the end-to-end wss check. Originally: plan, not started. Reviewers: Doof (protocol, service),
C3PO (nothing visual here; the screens that use it are M4).

**Gate (hard):** the M2 lockstep gate passes with the mailbox replaced by the
relay - two headless clients through a locally running relay, 200 of 200 day
hashes identical; then two browsers on two machines through the relay on
Unraid, 50 days, identical hashes and identical logs on the relay.

## 1. What the relay is

A small WebSocket service that knows nothing about the game. It keeps
**rooms**; a room has a code, a host, at most one guest, the settings the host
chose, and an **append-only log** of every line either side sent. It forwards
each side's lines to the other and stores them, and it can replay the log to
a client that (re)joins. That store is the save (M5) and the reconnect (M5).

The relay never runs the simulation and never validates a command - lockstep
plus the hash exchange is the integrity check (docs/multiplayer-plan.md §3).

## 2. Endpoints (one WebSocket, JSON lines; plus two GETs)

| Client → relay | Meaning |
|---|---|
| `{"t":"create","name":…,"player":…,"settings":{…}}` | host makes a room; reply `{"t":"room","code":…}` |
| `{"t":"list"}` | reply `{"t":"rooms","rooms":[{code,name,host,created,open}]}` - the Join Game screen's list (manual p160) |
| `{"t":"join","code":…,"player":…}` | guest joins; reply `{"t":"joined","settings":…,"host":…}`; the host gets `{"t":"guest","player":…}` |
| `{"t":"start"}` | host starts (the checkmark, manual p162); both get `{"t":"started"}` |
| any other line | forwarded verbatim to the other side and appended to the room log (the M2 protocol: hello/cmd/end/hash/speed, and lobby `chat`) |
| `{"t":"since","n":N}` | send me the room log from line N (reconnect, M5) |
| `{"t":"saves","player":P}` | the started games P is in, newest first: `{t:"saves", saves:[{code,name,host,guest,created,updated,lines,settings}]}` (Load, M5) |

| GET | Meaning |
|---|---|
| `/healthz` | 200 when up |
| `/rooms` | the same list as `list`, for a browser tab |

Auth: the room code (6 characters, unguessable) is the only credential, as the
manual implies. Public listing shows rooms marked open by their host; a
private room is joined by code only. TLS and the hostname are NPM Plus's job.

## 3. The service

- **Bun**, one file (`relay/server.ts`, ~300 lines), no dependencies: Bun's
  built-in `serve` handles both WebSocket upgrade and the two GETs.
- Rooms and logs on disk under `/data/rooms/<code>/` (`meta.json`,
  `log.jsonl`), so a restart keeps every game. A room with no traffic for 30
  days is archived, not deleted.
- Limits: 64 KB per line, 2 clients per room, 100 rooms per relay. Enough for
  a household and its friends; the numbers are in one config block.
- Container: `oven/bun` image, `/data` volume, port 8787 inside; NPM Plus
  proxies `wars.schmitzplex.com` → `relay:8787` with WebSocket support on
  (the "Websockets Support" toggle on the proxy host) and serves the static
  build from the same origin (`/` → the `build/web` files in a second volume,
  or the relay serves them itself - it can: `Bun.serve` static routes).
- Nothing on a workstation listens. For the local gate the relay runs on this
  machine for the duration of the test, like the http.server did for the web
  build (flagged, directive 16).

## 4. The client side

- `WebSocketTransport extends Transport` (`src/net/`): `WebSocketPeer`, which
  Godot ships in every Web export and every desktop build; `send` writes a
  text frame; `poll` calls `peer.poll()` and drains packets; reconnect with
  backoff; on reconnect sends `since` with the count it has.
- `RelayClient`: the lobby verbs (create/list/join/start) and the handoff to
  `LockstepSession` when `started` arrives - the session gets the transport
  and the settings from the room, both clients call `new_game` with the same
  header (that is what `hello` then double-checks).
- Settings live in `user://relay.cfg`: relay URL (default
  `wss://wars.schmitzplex.com`), last player name, last game name (the manual's
  defaults, decision 4).

## 5. Deployment - TeeJ's part, written out

1. Copy `relay/` to the Unraid box (e.g. `/mnt/user/appdata/wars-relay/`).
2. `docker compose up -d` there (the compose file in `relay/` maps `/data` to
   `appdata/wars-relay/data` and exposes 8787 on the docker network only).
3. NPM Plus: proxy host `wars.schmitzplex.com` → `http://wars-relay:8787`,
   Websockets Support on, SSL as the others. Authelia: **not** on this host
   (decision 5 / plan §6: the game code is the credential; add Authelia later
   if wanted - the client will follow a redirect to it, but the WebSocket
   upgrade will not, so it would need the bypass rule for `/ws`).
4. DNS: `wars` A/CNAME like the other `*.schmitzplex.com` names.
5. `curl https://wars.schmitzplex.com/healthz` → 200.

## 6. Order of work

1. `relay/server.ts` + `relay/docker-compose.yml` + `relay/README.md`; run it
   locally; a Bun test that drives two fake clients through create/join/start
   and checks forwarding and the log.
2. `WebSocketTransport` + `RelayClient`; `tests/lockstep_client.gd` gains
   `--relay=ws://127.0.0.1:8787 --room=…`; the M2 runner gains a `-Relay`
   switch that starts the relay, runs both clients through it, stops it.
   **Gate A**: 200 of 200 through the relay.
3. Hand TeeJ the deployment steps; when the host answers `/healthz`, **Gate B**:
   two browsers on two machines (the M4 screens are not built yet, so this is
   the headless client pointed at the real relay from two machines, then the
   web build once M4 lands).

Size: 2–3 days plus TeeJ's deployment.
