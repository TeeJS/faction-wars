// Two fake clients through a relay on a random port: create, list, join,
// start, forward a line each way, and replay the log with `since`.
//   bun run relay/test.ts
import { startRelay } from "./server";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const dataDir = mkdtempSync(join(tmpdir(), "relay-test-"));
const relay = startRelay({ port: 0, dataDir });
const url = `ws://127.0.0.1:${relay.port}/ws`;

function client(name: string) {
  const ws = new WebSocket(url);
  const inbox: any[] = [];
  const waiters: Array<(m: any) => void> = [];
  ws.onmessage = (e) => { const m = JSON.parse(String(e.data)); const w = waiters.shift(); if (w) w(m); else inbox.push(m); };
  const next = () => new Promise<any>((res) => { const m = inbox.shift(); if (m) res(m); else waiters.push(res); });
  const send = (o: unknown) => ws.send(JSON.stringify(o));
  const opened = new Promise<void>((res) => { ws.onopen = () => res(); });
  return { name, ws, send, next, opened };
}

let failures = 0;
const check = (cond: boolean, what: string) => { console.log(`${cond ? "ok  " : "FAIL"} ${what}`); if (!cond) failures++; };

const host = client("Han"); const guest = client("Luke");
await host.opened; await guest.opened;

host.send({ t: "create", name: "The End of the Empire", player: "Han", settings: { size: 1, hq_only: false } });
const room = await host.next();
check(room.t === "room" && typeof room.code === "string" && /^[ACDEFGHJKLMNPQRTUVWXY34679]{6}$/.test(room.code), "host creates a room and gets a 6-character code without look-alike characters");

guest.send({ t: "list" });
const list = await guest.next();
check(list.t === "rooms" && list.rooms.length === 1 && list.rooms[0].name === "The End of the Empire", "the guest sees the open game in the list");

guest.send({ t: "join", code: room.code, player: "Luke" });
const joined = await guest.next();
check(joined.t === "joined" && joined.side === "guest" && joined.host === "Han", "the guest joins and learns the host and settings");
const notice = await host.next();
check(notice.t === "guest" && notice.player === "Luke", "the host is told who joined");

guest.send({ t: "start" });
const refused = await guest.next();
check(refused.t === "error", "only the host may start");

host.send({ t: "start" });
const s1 = await host.next(); const s2 = await guest.next();
check(s1.t === "started" && s2.t === "started", "start reaches both sides");

host.send({ t: "cmd", day: 1, seq: 1, faction: "alliance", kind: "move_fleets", args: { fleets: ["Rebel Alliance Fleet_0002"], destination: "Xyquine" } });
const fwd = await guest.next();
check(fwd.t === "cmd" && fwd.kind === "move_fleets" && fwd.args.destination === "Xyquine", "a command from the host is forwarded to the guest verbatim");

guest.send({ t: "hash", day: 2, hash: "ABC" });
const h = await host.next();
check(h.t === "hash" && h.hash === "ABC", "a hash from the guest is forwarded to the host");

guest.send({ t: "since", n: 0 });
const l1 = await guest.next(); const l2 = await guest.next(); const done = await guest.next();
check(l1.t === "cmd" && l2.t === "hash" && done.t === "caught_up" && done.lines === 2, "since replays the room log in order and reports the count");

guest.send({ t: "list" });
const list2 = await guest.next();
check(list2.rooms.length === 0, "a started game is no longer listed");

guest.send({ t: "lookup", code: room.code.toLowerCase() });
const info = await guest.next();
check(info.t === "room_info" && info.found === true && info.name === "The End of the Empire" && info.host === "Han" && info.started === true, "a typed code finds its game even when it is not listed");
guest.send({ t: "lookup", code: "ZZZZZZ" });
const none = await guest.next();
check(none.t === "room_info" && none.found === false, "an unknown code is reported as not found");

host.ws.close(); await new Promise((r) => setTimeout(r, 50));
const left = await guest.next();
check(left.t === "left" && left.side === "host", "the guest is told when the host drops");

const host2 = client("Han"); await host2.opened;
host2.send({ t: "join", code: room.code, player: "Han" });
const back = await host2.next();
check(back.t === "joined" && back.side === "host" && back.lines === 2, "the host rejoins by name and takes its seat back with the log count");

host2.send({ t: "saves", player: "Han" });
const sv = await host2.next();
check(sv.t === "saves" && sv.saves.length === 1 && sv.saves[0].code === room.code && sv.saves[0].guest === "Luke" && sv.saves[0].lines === 2 && sv.saves[0].day === 0, "a started game is a save for the players in it, with the day both sides reached");
host2.send({ t: "saves", player: "Lando" });
const sv2 = await host2.next();
check(sv2.saves.length === 0, "a player not in the game has no save of it");

// seat_info: the guest's game - build, pack, pack hash - reaches the host for
// its check before Start, is kept on the room for a host that (re)joins, and
// is never written to the game log (the lockstep replay).
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
const h3 = client("Leia"); const g3 = client("Wedge"); await h3.opened; await g3.opened;
h3.send({ t: "create", name: "Seat check", player: "Leia", settings: {} });
const room3 = await h3.next();
g3.send({ t: "join", code: room3.code, player: "Wedge" });
await g3.next(); await h3.next();   // joined; the host's guest notice
g3.send({ t: "seat_info", build: "2026-09-26 abc1234" + "x".repeat(40), pack: "star-wars-rebellion", pack_hash: "f".repeat(64), extra: "not passed on" });
const seat = await h3.next();
check(seat.t === "seat_info" && seat.build === ("2026-09-26 abc1234" + "x".repeat(40)).slice(0, 32) && seat.pack === "star-wars-rebellion" && seat.pack_hash === "f".repeat(64) && !("extra" in seat),
  "the guest's seat_info reaches the host: its three fields only, the build cut to 32 characters");
h3.send({ t: "seat_info", build: "host's own", pack: "p", pack_hash: "h" });   // only the guest's counts
g3.send({ t: "since", n: 0 });
const noLines = await g3.next();
check(noLines.t === "caught_up" && noLines.lines === 0, "seat_info is not a game line: nothing is logged, and the host's own is ignored");
h3.ws.close(); await sleep(50);
check((await g3.next()).t === "left", "the guest is told the host dropped");
const h4 = client("Leia"); await h4.opened;
h4.send({ t: "join", code: room3.code, player: "Leia" });
const back4 = await h4.next(); const seat4 = await h4.next();
check(back4.t === "joined" && back4.side === "host" && seat4.t === "seat_info" && seat4.pack === "star-wars-rebellion" && seat4.build.startsWith("2026-09-26 abc1234"),
  "a host back at the table gets the guest's seat_info at once");
const hostBack = await g3.next();
check(hostBack.t === "host" && hostBack.player === "Leia", "and the guest is told the host is back (it sends its seat_info again)");
h4.ws.close(); g3.ws.close(); await sleep(50);

// Strangers (strangers plan PR 4): the open-games list shows strangers only
// what they may see; a peeking guest does not close a game; a game whose host
// has gone is not offered; settings have a size; abandoned games expire.
const h5 = client("Han"); const g5 = client("Peek"); const g6 = client("Late");
await h5.opened; await g5.opened; await g6.opened;
h5.send({ t: "create", name: "N".repeat(100), player: "H".repeat(50), settings: {
  pack: "my-pack", pack_title: "T".repeat(80), pack_version: "1.2.3.4.5.6.7.8.9.10", pack_hash: "A".repeat(64),
  pack_url: "https://example.com/" + "a".repeat(400), build: "2026-09-26 abc1234", side: "alliance", secret: "not for strangers" } });
const room5 = await h5.next();
g5.send({ t: "list" });
const row5 = ((await g5.next()).rooms as any[]).find((x) => x.code === room5.code);
check(row5 && row5.name.length === 64 && row5.host.length === 32, "the list cuts a game's name to 64 and its host's to 32");
check(row5 && row5.settings.pack === "my-pack" && row5.settings.pack_title.length === 64 && row5.settings.pack_version.length === 16
  && row5.settings.pack_hash === "a".repeat(64) && row5.settings.build === "2026-09-26 abc1234",
  "the list shows the pack's id, title (64), version (16), hash (lower case) and the build");
check(row5 && !("pack_url" in row5.settings) && !("side" in row5.settings) && !("secret" in row5.settings),
  "... and nothing else: a link too long to be whole is dropped, not cut; other settings stay between the players");
g5.send({ t: "lookup", code: room5.code });
const info5 = await g5.next();
check(info5.found === true && !("secret" in info5.settings) && info5.settings.pack === "my-pack", "a code's lookup shows the same, no more");
g5.send({ t: "join", code: room5.code, player: "Peek" });
check((await g5.next()).t === "joined" && (await h5.next()).t === "guest", "a stranger joins");
g6.send({ t: "list" });
check(!((await g6.next()).rooms as any[]).some((x) => x.code === room5.code), "a game with its seat taken is not listed");
g5.ws.close(); await sleep(50);
check((await h5.next()).t === "left", "the stranger leaves: the host is told");
g6.send({ t: "list" });
check(((await g6.next()).rooms as any[]).some((x) => x.code === room5.code), "... the seat is free again, and the game is listed again");
g6.send({ t: "join", code: room5.code, player: "Late" });
const late = await g6.next();
check(late.t === "joined" && late.side === "guest" && late.settings.secret === "not for strangers", "another player takes the seat, and the players' own settings reach them");
await h5.next();   // the guest notice
g6.ws.close(); await sleep(50); await h5.next();   // left
h5.ws.close(); await sleep(50);
g6 === g6;
const g7 = client("Look"); await g7.opened;
g7.send({ t: "list" });
check(!((await g7.next()).rooms as any[]).some((x) => x.code === room5.code), "a game whose host has gone is not listed");
g7.send({ t: "lookup", code: room5.code });
check((await g7.next()).found === true, "... though its code still finds it");
g7.send({ t: "create", name: "Big", player: "Big", settings: { note: "x".repeat(5000) } });
const big = await g7.next();
check(big.t === "error" && big.error === "settings too large", "settings over 4 KB are refused");
g7.send({ t: "create", name: "Private", player: "Priv", settings: {}, open: false });
const priv = await g7.next();
g7.send({ t: "list" });
check(!((await g7.next()).rooms as any[]).some((x) => x.code === priv.code), "a game created with open:false is not listed");
g7.send({ t: "settings", settings: { note: "y".repeat(5000) } });
const big2 = await g7.next();
check(big2.t === "error" && big2.error === "settings too large", "... nor are its settings changed to over 4 KB");
g7.ws.close(); await sleep(50);

// Expiry: an unstarted room whose host has been gone abandonedMs is deleted
// (an hour in production; 150 ms on this relay).
{
  const dir3 = mkdtempSync(join(tmpdir(), "relay-expiry-"));
  const relay3 = startRelay({ port: 0, dataDir: dir3, abandonedMs: 150, sweepMs: 25 });
  const ws = new WebSocket(`ws://127.0.0.1:${relay3.port}/ws`);
  const got: any[] = [];
  ws.onmessage = (e) => got.push(JSON.parse(String(e.data)));
  await new Promise<void>((res) => { ws.onopen = () => res(); });
  ws.send(JSON.stringify({ t: "create", name: "Gone", player: "Ghost", settings: {} }));
  await sleep(50);
  const code = got.find((m) => m.t === "room").code;
  const { existsSync: ex2 } = await import("node:fs");
  const hadDir = ex2(join(dir3, "rooms", code));
  ws.close(); await sleep(60);
  const stillThere = relay3.rooms.has(code);
  await sleep(300);
  check(hadDir && stillThere && !relay3.rooms.has(code) && !ex2(join(dir3, "rooms", code)), "an unstarted room abandoned by its host is deleted after abandonedMs, and its folder with it");
  relay3.stop();
}

// relay was started without a FEEDBACK_TOKEN: the reports cannot be read at all.
const closed = await fetch(`http://127.0.0.1:${relay.port}/feedback`);
check(closed.status === 401, "with no FEEDBACK_TOKEN on the relay the reports are closed to everyone");

// The relay restarted: the room and its log come back from disk.
relay.stop(); await new Promise((r) => setTimeout(r, 50));
const relay2 = startRelay({ port: 0, dataDir, heartbeatMs: 40, feedbackToken: "the-token" });
const auth = { Authorization: "Bearer the-token" };
const url2 = `ws://127.0.0.1:${relay2.port}/ws`;
const ws3 = new WebSocket(url2); const inbox3: any[] = [];
await new Promise<void>((res) => { ws3.onopen = () => res(); });
const next3 = () => new Promise<any>((res) => { const m = inbox3.shift(); if (m) res(m); else ws3.onmessage = (e) => res(JSON.parse(String(e.data))); });
ws3.send(JSON.stringify({ t: "join", code: room.code, player: "Luke" }));
const back3 = await next3();
check(back3.t === "joined" && back3.side === "guest" && back3.started === true && back3.lines === 2, "after a relay restart the guest rejoins the game from disk with the log count");
ws3.send(JSON.stringify({ t: "since", n: 0 }));
const r1 = await next3(); const r2 = await next3(); const r3 = await next3();
check(r1.t === "cmd" && r2.t === "hash" && r3.t === "caught_up", "and the log replays from disk");
// The heartbeat: relay2 pings every 40 ms here (25 s in production), and the
// client's automatic pongs come back - what keeps a proxy's idle timer, and
// Bun's own, from closing a quiet lobby.
await new Promise((r) => setTimeout(r, 300));
check(relay2.pongs() >= 3, "the relay pings every open socket and the client's pongs come back");
// Tester feedback: POST /feedback writes the report and its log; junk is refused.
const fbBase = `http://127.0.0.1:${relay2.port}`;
const fb = await fetch(`${fbBase}/feedback`, { method: "POST", headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ player: "Han Solo", game: "ABC123", day: 12, message: "cannot target the shield", log: "{\"t\":\"header\"}\n{\"t\":\"cmd\"}\n" }) });
const fbReply: any = await fb.json();
check(fb.status === 200 && fbReply.ok === true && /Han_Solo$/.test(fbReply.id), "feedback is accepted and named after the player");
const { readFileSync: rf, existsSync: ex } = await import("node:fs");
const fbJson = JSON.parse(rf(join(dataDir, "feedback", fbReply.id + ".json"), "utf8"));
check(fbJson.message === "cannot target the shield" && fbJson.day === 12 && fbJson.log_lines === 2 && ex(join(dataDir, "feedback", fbReply.id + ".jsonl")), "the report and its session log are written under feedback/");
const noAuth = await fetch(`${fbBase}/feedback`);
const wrongAuth = await fetch(`${fbBase}/feedback/${fbReply.id}.jsonl`, { headers: { Authorization: "Bearer not-the-token" } });
const noAuthDone = await fetch(`${fbBase}/feedback/${fbReply.id}/complete`, { method: "POST" });
check(noAuth.status === 401 && wrongAuth.status === 401 && noAuthDone.status === 401 && noAuth.headers.get("www-authenticate") === "Bearer", "the listing, a report's files and complete all refuse a missing or wrong token");
const bad = await fetch(`${fbBase}/feedback`, { method: "POST", body: "{" });
check(bad.status === 400, "junk feedback is refused");
const empty = await fetch(`${fbBase}/feedback`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ message: "   " }) });
check(empty.status === 400, "an empty note is refused");
const listing: any = await (await fetch(`${fbBase}/feedback`, { headers: auth })).json();
check(listing.count === 1 && listing.feedback[0].id === fbReply.id && listing.feedback[0].message === "cannot target the shield" && listing.feedback[0].log_lines === 2 && !("log" in listing.feedback[0]), "GET /feedback lists the reports without their logs");
const oneLog = await fetch(`${fbBase}/feedback/${fbReply.id}.jsonl`, { headers: auth });
const oneLogText = await oneLog.text();
check(oneLog.status === 200 && oneLogText.split("\n").filter((l) => l).length === 2, "GET /feedback/<id>.jsonl returns the report's session log");
const oneJson: any = await (await fetch(`${fbBase}/feedback/${fbReply.id}.json`, { headers: auth })).json();
check(oneJson.message === "cannot target the shield", "GET /feedback/<id>.json returns the report");
const escape = await fetch(`${fbBase}/feedback/..%2Fserver.json`, { headers: auth });
check(escape.status === 404, "a report id cannot reach outside feedback/");
const completed: any = await (await fetch(`${fbBase}/feedback/${fbReply.id}/complete`, { method: "POST", headers: auth })).json();
const open: any = await (await fetch(`${fbBase}/feedback`, { headers: auth })).json();
const all: any = await (await fetch(`${fbBase}/feedback?all=1`, { headers: auth })).json();
check(completed.ok === true && completed.moved === 2 && open.count === 0 && all.count === 1 && all.feedback[0].completed === true, "a completed report moves to feedback/completed/ and leaves the open listing");

console.log(failures === 0 ? "[relay test] PASS" : `[relay test] ${failures} FAILED`);
relay2.stop();
process.exit(failures === 0 ? 0 : 1);
