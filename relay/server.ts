// The schmitz-wars relay (docs/m3-plan.md). A WebSocket service that knows
// nothing about the game: rooms, one host and one guest each, an append-only
// log of every line either side sends, forwarding, and replay of the log to a
// client that (re)joins. It never runs the simulation and never validates a
// command - the two clients' lockstep hash exchange is the integrity check.
//
//   bun run relay/server.ts            (PORT, DATA_DIR, STATIC_DIR from the environment)
//   bun run relay/test.ts              (two fake clients through a relay on a random port)

import { mkdirSync, existsSync, readdirSync, readFileSync, appendFileSync, writeFileSync, statSync } from "node:fs";
import { join, resolve, sep } from "node:path";

const LIMITS = {
  lineBytes: 64 * 1024,   // one JSON line
  clientsPerRoom: 2,      // a host and a guest - "two players" (manual p156)
  rooms: 100,             // more than a household needs
  feedbackBytes: 4 * 1024 * 1024,   // one report with its session log
  feedbackBytes: 4 * 1024 * 1024,   // one report with its session log
  codeLength: 6,
};

type Side = "host" | "guest";
type Peer = { player: string; ws: any | null };
type Room = {
  code: string;
  name: string;
  settings: Record<string, unknown>;
  created: number;
  open: boolean;      // listed for anyone to join
  started: boolean;
  host: Peer;
  guest: Peer | null;
  lines: number;      // lines in the log
};
type Data = { room: Room | null; side: Side | null };

// No look-alikes: 0/O, 1/I, S/5, Z/2, B/8 are all out (TeeJ, room #103).
const ALPHABET = "ACDEFGHJKLMNPQRTUVWXY34679";

export function startRelay(opts: { port?: number; dataDir?: string; staticDir?: string } = {}) {
  const port = opts.port ?? Number(process.env.PORT ?? 8787);
  const dataDir = opts.dataDir ?? process.env.DATA_DIR ?? "./data";
  const staticDir = opts.staticDir ?? process.env.STATIC_DIR ?? "";
  const roomsDir = join(dataDir, "rooms");
  mkdirSync(roomsDir, { recursive: true });
  const feedbackDir = join(dataDir, "feedback");
  mkdirSync(feedbackDir, { recursive: true });

  const rooms = new Map<string, Room>();

  // --- persistence: meta.json + log.jsonl per room ---
  const roomDir = (code: string) => join(roomsDir, code);
  const saveMeta = (r: Room) => {
    const { host, guest, ...rest } = r;
    const meta = { ...rest, host: host.player, guest: guest?.player ?? null };
    writeFileSync(join(roomDir(r.code), "meta.json"), JSON.stringify(meta, null, 2));
  };
  const appendLog = (r: Room, line: string) => {
    appendFileSync(join(roomDir(r.code), "log.jsonl"), line + "\n");
    r.lines += 1;
  };
  const readLog = (r: Room, since: number): string[] => {
    const p = join(roomDir(r.code), "log.jsonl");
    if (!existsSync(p)) return [];
    return readFileSync(p, "utf8").split("\n").filter((l) => l.length > 0).slice(since);
  };
  for (const code of existsSync(roomsDir) ? readdirSync(roomsDir) : []) {
    const mp = join(roomDir(code), "meta.json");
    if (!existsSync(mp)) continue;
    try {
      const m = JSON.parse(readFileSync(mp, "utf8"));
      rooms.set(code, {
        code, name: m.name, settings: m.settings ?? {}, created: m.created, open: !!m.open, started: !!m.started,
        host: { player: m.host, ws: null }, guest: m.guest ? { player: m.guest, ws: null } : null,
        lines: readLog({ code } as Room, 0).length,
      });
    } catch { /* a broken room is skipped, not fatal */ }
  }

  const newCode = () => {
    let code = "";
    do {
      code = Array.from({ length: LIMITS.codeLength }, () => ALPHABET[Math.floor(Math.random() * ALPHABET.length)]).join("");
    } while (rooms.has(code));
    return code;
  };
  const listing = () => Array.from(rooms.values())
    .filter((r) => r.open && !r.started && !r.guest)
    .map((r) => ({ code: r.code, name: r.name, host: r.host.player, created: r.created, settings: r.settings }));
  // The saves of one player: every started game they are in, newest first.
  // "Load" on the Multiplayer Options (manual p161) offers the games both
  // players are in; the client intersects two of these.
  // The day a save resumes at: the last day BOTH sides sent a hash for
  // (LockstepSession.rebuild_from_log resumes there). Protocol, not game.
  const dayOf = (r: Room): number => {
    const sides = new Map<number, Set<string>>();
    for (const l of readLog(r, 0)) {
      let m: any; try { m = JSON.parse(l); } catch { continue; }
      if (m?.t !== "hash") continue;
      const d = Number(m.day ?? 0);
      if (!sides.has(d)) sides.set(d, new Set());
      sides.get(d)!.add(String(m.side ?? ""));
    }
    let best = 0;
    for (const [d, s] of sides) if (s.size >= 2 && d > best) best = d;
    return best;
  };
  const saves = (player: string) => Array.from(rooms.values())
    .filter((r) => r.started && (r.host.player === player || r.guest?.player === player))
    .map((r) => {
      const p = join(roomDir(r.code), "log.jsonl");
      const updated = existsSync(p) ? statSync(p).mtimeMs : r.created;
      return { code: r.code, name: r.name, host: r.host.player, guest: r.guest?.player ?? null, created: r.created, updated, lines: r.lines, day: dayOf(r), settings: r.settings };
    })
    .sort((a, b) => b.updated - a.updated);
  const send = (ws: any, obj: unknown) => { try { ws?.send(JSON.stringify(obj)); } catch { /* gone */ } };
  const other = (r: Room, side: Side): Peer | null => (side === "host" ? r.guest : r.host);

  const server = Bun.serve<Data>({
    port,
    async fetch(req, server) {
      const url = new URL(req.url);
      // Tester feedback (room AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #80): a note plus the
      // facts that reproduce it - day, seed, settings, client, the session log.
      // Written as feedback/<utc time>-<player>.json (+ .jsonl for the log).
      if (url.pathname === "/feedback" && req.method === "POST") {
        const declared = Number(req.headers.get("content-length") ?? 0);
        if (declared > LIMITS.feedbackBytes) return new Response("too large", { status: 413 });
        const text = await req.text();
        if (text.length > LIMITS.feedbackBytes) return new Response("too large", { status: 413 });
        let report: any;
        try { report = JSON.parse(text); } catch { return new Response("not json", { status: 400 }); }
        if (!report || typeof report.message !== "string" || report.message.trim() === "") return new Response("no message", { status: 400 });
        const who = String(report.player ?? "player").replace(/[^A-Za-z0-9_-]/g, "_").slice(0, 32) || "player";
        const stamp = new Date().toISOString().replace(/[:.]/g, "-");
        const id = `${stamp}-${who}`;
        const { log, ...meta } = report;
        meta.received_at = new Date().toISOString();
        meta.log_lines = typeof log === "string" ? log.split("\n").filter((l: string) => l.length > 0).length : 0;
        writeFileSync(join(feedbackDir, `${id}.json`), JSON.stringify(meta, null, 2));
        if (typeof log === "string" && log.length > 0) writeFileSync(join(feedbackDir, `${id}.jsonl`), log);
        return Response.json({ ok: true, id });
      }
      if (url.pathname === "/ws" || req.headers.get("upgrade")?.toLowerCase() === "websocket") {
        if (server.upgrade(req, { data: { room: null, side: null } })) return undefined as any;
        return new Response("websocket only", { status: 426 });
      }
      if (url.pathname === "/healthz") return new Response("ok");
      // The reports, newest first, without their logs (TeeJ, room #155).
      if (url.pathname === "/feedback" && req.method === "GET") {
        const items: any[] = [];
        for (const f of readdirSync(feedbackDir)) {
          if (!f.endsWith(".json")) continue;
          try {
            const r = JSON.parse(readFileSync(join(feedbackDir, f), "utf8"));
            items.push({ id: f.slice(0, -5), player: r.player, game: r.game, day: r.day, seed: r.seed, received_at: r.received_at, message: String(r.message ?? "").slice(0, 2000), log_lines: r.log_lines ?? 0, client: r.client ?? {} });
          } catch { /* a broken file is skipped */ }
        }
        items.sort((a, b) => String(b.received_at ?? "").localeCompare(String(a.received_at ?? "")));
        return Response.json({ count: items.length, feedback: items });
      }
      if (url.pathname === "/rooms") return Response.json({ rooms: listing() });
      if (staticDir) {
        const path = url.pathname === "/" ? "/index.html" : url.pathname;
        // Stay inside STATIC_DIR whatever the path says (review note, Qwen).
        const root = resolve(staticDir);
        const target = resolve(root, "." + path);
        if (target !== root && !target.startsWith(root + sep)) return new Response("not found", { status: 404 });
        const file = Bun.file(target);
        // no-cache: the browser revalidates on every plain reload, so a new
        // image's files arrive without a forced refresh (the game canvas eats
        // Ctrl+F5 - TeeJ, room #100).
        return file.size > 0 ? new Response(file, { headers: { "Cache-Control": "no-cache" } }) : new Response("not found", { status: 404 });
      }
      return new Response("schmitz-wars relay", { status: 200 });
    },
    websocket: {
      maxPayloadLength: LIMITS.lineBytes,
      open(ws) { /* nothing until the first line */ },
      message(ws, raw) {
        const line = typeof raw === "string" ? raw : new TextDecoder().decode(raw);
        if (line.length > LIMITS.lineBytes) { send(ws, { t: "error", error: "line too long" }); return; }
        let msg: any;
        try { msg = JSON.parse(line); } catch { send(ws, { t: "error", error: "not json" }); return; }
        const d = ws.data;
        switch (msg.t) {
          case "create": {
            if (rooms.size >= LIMITS.rooms) { send(ws, { t: "error", error: "relay full" }); return; }
            const r: Room = {
              code: newCode(), name: String(msg.name ?? "Game"), settings: msg.settings ?? {}, created: Date.now(),
              open: msg.open !== false, started: false, host: { player: String(msg.player ?? "Player"), ws }, guest: null, lines: 0,
            };
            mkdirSync(roomDir(r.code), { recursive: true });
            rooms.set(r.code, r); saveMeta(r);
            d.room = r; d.side = "host";
            send(ws, { t: "room", code: r.code });
            return;
          }
          case "list": send(ws, { t: "rooms", rooms: listing() }); return;
          case "saves": send(ws, { t: "saves", saves: saves(String(msg.player ?? "")) }); return;
          case "lookup": {   // a typed game code finds its game, listed or not (manual p159: the host's address)
            const r = rooms.get(String(msg.code ?? "").toUpperCase());
            if (!r) { send(ws, { t: "room_info", code: String(msg.code ?? "").toUpperCase(), found: false }); return; }
            send(ws, { t: "room_info", code: r.code, found: true, name: r.name, host: r.host.player, created: r.created, settings: r.settings, started: r.started, full: !!(r.guest && r.guest.ws) });
            return;
          }
          case "join": {
            const r = rooms.get(String(msg.code ?? "").toUpperCase());
            if (!r) { send(ws, { t: "error", error: "no such game" }); return; }
            const player = String(msg.player ?? "Player");
            // A returning host or guest takes its seat back (reconnect, M5).
            if (r.host.player === player && !r.host.ws) { r.host.ws = ws; d.room = r; d.side = "host"; }
            else if (r.guest && r.guest.player === player && !r.guest.ws) { r.guest.ws = ws; d.room = r; d.side = "guest"; }
            else if (!r.guest) { r.guest = { player, ws }; d.room = r; d.side = "guest"; saveMeta(r); }
            else { send(ws, { t: "error", error: "game is full" }); return; }
            send(ws, { t: "joined", code: r.code, name: r.name, side: d.side, host: r.host.player, guest: r.guest?.player ?? null, settings: r.settings, started: r.started, lines: r.lines });
            const o = other(r, d.side!);
            if (o?.ws) send(o.ws, { t: d.side === "guest" ? "guest" : "host", player });
            return;
          }
          case "settings": {   // the host changes the Multiplayer Options (manual p161)
            const r = d.room; if (!r || d.side !== "host") return;
            r.settings = msg.settings ?? r.settings; saveMeta(r);
            if (r.guest?.ws) send(r.guest.ws, { t: "settings", settings: r.settings });
            return;
          }
          case "start": {
            const r = d.room; if (!r || d.side !== "host") { send(ws, { t: "error", error: "only the host starts" }); return; }
            r.started = true; r.open = false; saveMeta(r);
            for (const p of [r.host, r.guest]) if (p?.ws) send(p.ws, { t: "started", settings: r.settings });
            return;
          }
          case "since": {
            const r = d.room; if (!r) return;
            for (const l of readLog(r, Number(msg.n ?? 0))) { try { ws.send(l); } catch { break; } }
            send(ws, { t: "caught_up", lines: r.lines });
            return;
          }
          default: {
            // Everything else is the game's own protocol: store and forward.
            const r = d.room; if (!r || !d.side) { send(ws, { t: "error", error: "join a game first" }); return; }
            appendLog(r, line);
            const o = other(r, d.side);
            if (o?.ws) { try { o.ws.send(line); } catch { /* they will catch up with since */ } }
            return;
          }
        }
      },
      close(ws) {
        const d = ws.data; const r = d.room; if (!r || !d.side) return;
        const me = d.side === "host" ? r.host : r.guest;
        if (me && me.ws === ws) me.ws = null;
        const o = other(r, d.side);
        if (o?.ws) send(o.ws, { t: "left", side: d.side });
      },
    },
  });
  return { server, port: server.port, rooms, stop: () => server.stop(true) };
}

if (import.meta.main) {
  const r = startRelay();
  console.log(`[relay] listening on :${r.port}`);
}
