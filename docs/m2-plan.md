# M2 — lockstep, locally (plan, for review before building)

**Revised 2026-09-03 (phases, BACKPORT-LOG #18):** the lockstep unit is a PHASE (~300 ms), not the day; both apply each phase's merged batch in the canonical order as soon as both ends are in, and the day ticks at the phase whose end line from the host carries advance:true. Day hashes, desync detection, resync, rejoin and load are unchanged in meaning. **Status:** DONE 2026-09-03 - steps 1-3 landed and gated (`tools/lockstep-local.ps1`); step 4, the UI pieces, is C3PO's design and follows M3. Originally: plan, not started. Reviewers: Doof (protocol, ordering),
C3PO (the clock and the "Waiting for Opponent" surface, which is UI).

**Gate (hard):** two headless clients, one Alliance and one Empire, each issuing
its own scripted orders, exchange batches through a local transport for 200
days and print identical day hashes every day; a forced desync is detected and
repaired by replaying the log.

## 1. One process is one client

Every manager is a `class_name` static (GameState, EventBus, the catalogs), so
two clients cannot share a process. The gate therefore runs **two Godot
processes** and a transport between them. M2 uses a **mailbox transport**: each
client appends its outbound lines to `<dir>/<side>.out` and polls the other's
file - no sockets, deterministic, trivially inspectable. M3 swaps in the
WebSocket relay behind the same `Transport` interface (`send(dict)`,
`poll() -> Array[dict]`).

## 2. The protocol - JSON lines

| Line | Meaning |
|---|---|
| `{"t":"cmd", …Command}` | one order (the M1 line, unchanged) |
| `{"t":"end","day":D,"n":N}` | my batch for day D is complete and has N commands |
| `{"t":"hash","day":D,"hash":H}` | my day hash after the tick into D |
| `{"t":"speed","level":L}` | I set my speed (0 = pause) |
| `{"t":"hello","side":…,"seed":…,"humans":…,"host":…,"size":…,"difficulty":…,"hq_only":…}` | the header; the guest checks it against its own |

Chat is a `cmd` of kind `chat` - it is game state (the message log is hashed).

## 3. The lockstep clock (`LockstepSession`, `src/net/`)

Per client: `local_side`, `day`, `batch[day]` (my commands this day),
`remote[day]` (theirs), `remote_end[day]`, `remote_hash[day]`, `my_speed`,
`remote_speed`.

- **Issue** (from the UI, via `CommandBus` in non-immediate mode): append to
  `batch[day]`, send the `cmd` line. Nothing applies yet.
- **Tick request** (the clock fires at the effective speed): if my `end` for
  `day` is not sent, send it and freeze the batch - anything issued after that
  goes to `day+1`. Then, if `remote_end[day]` has arrived: merge both batches,
  sort (retreat battle answers first, then faction order, then `Seq`), apply,
  `AdvanceDay`, compute the hash, send it, `day += 1`. If not arrived: the
  clock waits; the UI shows **Waiting for Opponent** (manual p163) after a
  grace period, and clears it when the batch lands.
- **Hash check**: when `remote_hash[day]` arrives, compare with mine for that
  day. Mismatch → `desync` state: the clock stops, both sides get a message
  naming the day, and the client offers **Resync**: replay its own log from the
  header (M1's `tests/replay.gd` logic, in-process) and compare again. If the
  replayed hash matches the remote, the local state was corrupted and the
  replay stands; if it still differs, the logs differ - the bug report is the
  two logs.
- **Speed**: `set_speed` is both a `cmd` (logged, so a replay reproduces the
  pacing) and a `speed` line applied at once; effective speed =
  min(mine, theirs); 0 pauses both. **Pause** = speed 0; the other side sees
  "Waiting for Opponent" immediately (no grace).
- **Battle answers**: each human side in a battle answers with a
  `battle_answer` command for its own fleet; retreats sort first so "any
  Retreat wins" holds on both clients (manual p152). A day whose tick raised a
  battle the local human is in does not advance until the local answer is
  issued (the Battle Alert is modal, as today).

## 4. What the UI needs (C3PO)

- `GameManager`'s clock reads the effective speed from the session instead of
  its own `_speed`; `SetSpeed` issues `set_speed`.
- A **Waiting for Opponent** box (manual p163): same shape as the pause box,
  not dismissable by the waiting side; text is the manual's three words.
- A **Desync** dialog with **Resync** and the day number. Not in the manual;
  ours, plainly labelled.
- The Battle Alert already issues `battle_answer`; nothing else changes.

## 5. Order of work

1. `Transport` interface + `MailboxTransport`; `LockstepSession` with the tick
   rule and hash exchange; `CommandBus` non-immediate mode wired to it.
2. `tests/lockstep_client.gd --side=… --mailbox=… --days=200`: the scripted
   order generator of `tests/command_apply.gd` per side, driven by the session
   instead of a free-running loop; a runner script starts two of them and diffs
   the two hash logs. The gate.
3. Forced desync test: one client flips a support value on day 50; expect
   detection on day 51 and a successful resync.
4. The UI pieces (section 4), then the browser: two tabs of the web build with
   the mailbox replaced by the M3 relay.

Size: 3–4 agent days.
