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
check(room.t === "room" && typeof room.code === "string" && room.code.length === 6, "host creates a room and gets a 6-character code");

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

// The relay restarted: the room and its log come back from disk.
relay.stop(); await new Promise((r) => setTimeout(r, 50));
const relay2 = startRelay({ port: 0, dataDir });
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
relay2.stop();

console.log(failures === 0 ? "[relay test] PASS" : `[relay test] ${failures} FAILED`);
process.exit(failures === 0 ? 0 : 1);
