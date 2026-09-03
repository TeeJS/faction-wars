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

host.ws.close(); await new Promise((r) => setTimeout(r, 50));
const left = await guest.next();
check(left.t === "left" && left.side === "host", "the guest is told when the host drops");

const host2 = client("Han"); await host2.opened;
host2.send({ t: "join", code: room.code, player: "Han" });
const back = await host2.next();
check(back.t === "joined" && back.side === "host" && back.lines === 2, "the host rejoins by name and takes its seat back with the log count");

console.log(failures === 0 ? "[relay test] PASS" : `[relay test] ${failures} FAILED`);
relay.stop();
process.exit(failures === 0 ? 0 : 1);
