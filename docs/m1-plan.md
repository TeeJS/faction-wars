# M1 — the command layer (plan, for review before building)

**Status:** plan, 2026-09-03. Not started. Reviewers: Doof (schema and applier),
C3PO (every UI call site, and the single-player experience must not change).
TeeJ decided (#89 item 7) that single player also goes through the command log.

**Gate (hard):** a recorded 200-day single-player session replays from its log
to identical day hashes; the seed-12345 self-regression still passes 101/101;
the M0 gate still passes; every window smoke test still passes.

## 1. What a command is

```
Command
  Day: int          # the day it applies on (the tick it is applied before)
  Seq: int          # order within the day, per issuing faction
  Faction: String   # who issued it (faction id)
  Kind: String      # one of the kinds below
  Args: Dictionary  # entity ids and plain values only - never object references
```

Serialised as one JSON line; the log is one file, one line per command,
prefixed by a header line `{"seed":…, "humans":[…], "host":…, "size":…,
"difficulty":…, "hq_only":…}` so a log alone can rebuild the game.

Entity ids, all already deterministic on every client (M0):

| Entity | Id in Args |
|---|---|
| Planet, Sector | name |
| Faction | id |
| Character | name |
| Fleet | serial (`Fleet.Serial`) |
| Unit | `Unit.Serial` |
| Facility | `Facility.Serial` |
| Mission | `Mission.Serial` |
| GameMessage | `GameMessage.Serial` |

`EntityIndex` resolves ids to objects by scanning the live galaxy and roster
(150 planets, a few hundred units; a scan per command is microseconds and needs
no bookkeeping that could drift).

## 2. The kinds — one per UI mutation entry point today

| Kind | Args | Applier calls |
|---|---|---|
| `move_fleets` | fleets[], destination | `OrderManager.MoveFleets` |
| `move_units` | units[], destination | `OrderManager.MoveUnits` (after `run_blockade` if the UI confirmed it) |
| `move_characters` | characters[], destination | `OrderManager.MoveCharacters` |
| `board_fleet` | characters[], fleet | `OrderManager.BoardFleet` |
| `load_aboard` | units[], fleet | `OrderManager.LoadAboard` |
| `unload` / `unload_units` / `disembark` | fleet / units[] / characters[] | the three `OrderManager` verbs |
| `run_blockade` | units[], from, destination | `OrderManager.RunBlockade` then `MoveUnits` with the survivors |
| `queue_facility` | planet, type, tier, destination, count | `Planet.TryQueueMany` |
| `queue_units` | planet, rule name, destination, count | `Planet.TryQueueManyUnits` |
| `cancel_build` | planet, producer | `Planet.CancelCurrentBuild` |
| `scrap_facility` / `scrap_unit` | facility / unit | `Planet.ScrapFacility` / `ScrapUnit` |
| `retire` | characters[] | the Retire block in `DraggableWindow` |
| `take_command` | character, rank | `Character.TryTakeCommand` |
| `launch_mission` | type, team[], origin, target, decoys[], victim, object | `MissionManager.Launch` |
| `abort_mission` | mission | `MissionManager.Abort` |
| `bombard` | fleet, planet, mode | `BombardmentManager.Bombard` |
| `assault` | fleet, planet | `AssaultManager.Resolve` |
| `battle_answer` | report (where + day), answer: simulate / retreat | `FleetBattleManager.SimulateResults` / `Retreat(r, day, faction)` |
| `droid` | manage: production / garrisons, on | `AgentDroid.SetManage…` |
| `delete_messages` | messages[] | `EventBus.DeleteMessage` |
| `chat` | text | a `GameMessage` in the Chat category, addressed to the other side |
| `set_speed` | level 0–4 | the shared speed (M2 applies min of both) |
| `pause` / `resume` | — | M2 |

Reads (CanTarget, TravelDays, HasRoomFor…) stay direct calls: they do not
change state and the UI needs them synchronously to grey out menu items.

## 3. Where commands go

```
UI  ──issue(cmd)──►  CommandBus  ──►  CommandLog (append)  ──►  CommandApplier.apply(cmd)  ──►  backend
                                          │
                                          └──► (M2) relay send
```

- **Single player:** `CommandBus.issue` logs the command and applies it
  immediately, on the same frame, so the UI behaves exactly as today
  (TeeJ's decision 7). `Day` is `StrategicTickManager.Today`.
- **Head-to-head (M2):** `issue` logs, sends, and applies at the next tick,
  after the opponent's batch for that day has arrived, both batches in faction
  order then `Seq`.
- **Replay:** `GameSession.replay(log_path)` rebuilds the game from the header
  and feeds each day's commands to the applier before `AdvanceDay`, then
  compares day hashes with the log's own hash lines (the log also records the
  day hash after each tick, so a replay checks itself).
- **The AI** does not go through the bus. It runs inside `AdvanceDay` on every
  client identically; logging its moves would only duplicate the seed.

## 4. The UI change

Every `OrderManager.X(...)` / `planet.TryQueue…` / `MissionManager.Launch` /
`FleetBattleManager.SimulateResults` … call in `src/ui/` becomes
`CommandBus.issue(Command.new(kind, args))`. The dialogs stay where they are:
a confirmation still asks first and issues on OK; the refusal dialogs read the
applier's `Result` the same way they read the backend's today. About 30 call
sites across DraggableWindow, UIManager, FleetWindow, DefenseWindow,
EconomyWindow, MissionWindow, MessageWindow, BattleAlertWindow, DebugKeys.

C3PO owns the review that nothing the player sees changes in single player.

## 5. Order of work

1. `Command`, `CommandLog`, `EntityIndex`, `CommandApplier` with every kind, and
   `CommandBus` in immediate mode. No UI change yet. Unit test: apply a hand-made
   command of each kind on the seed-12345 galaxy - same effect as the direct call.
2. Switch the UI call sites to the bus, one window per commit; window smoke
   tests after each.
3. `--record=path` on the game (GameManager) and on the soak; `tests/replay.gd
   --log=path`. The gate above.
4. `docs/BACKPORT-LOG.md` entry: plumbing, no rule effect.

Size: 4–6 agent days (the plan's estimate stands).
