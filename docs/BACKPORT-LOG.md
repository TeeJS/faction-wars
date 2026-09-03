# Backport log — changes made in the port that the C# source does not have

**Since 2026-09-03 the port is the game** (TeeJ, room #104). Rule and behaviour
changes land here first and only; this file is the record that lets someone
apply them back to `sol-conflict-revolution` later. One entry per change, added
in the same commit as the change. Multiplayer plumbing and UI are listed only
when they touch a simulation rule.

The parity gate (`tests/soak.gd --expect`) is now a **self-regression** test: the
fixtures in `tests/fixtures/` are the port's own last-known-good outputs, not the
C# source's. When an entry below intentionally changes the day hashes, the same
commit regenerates the fixtures from the port (see HANDOFF, step 2) and says so
in its **Hashes** line. The last fixtures that came from the C# were generated
at source commit `6da9451`.

Entry shape:

```
## N. <title>                                      port commit <sha>
Kind:      rule | behaviour | bug fix | plumbing-with-rule-effect
Files:     port files touched
Source:    the C# files/methods that would change, and how
Hashes:    unchanged | changed (fixtures regenerated) - and why
Sources:   manual page / table / community reference that justifies the rule
```

---

## 1. Only a pre-placed CORE world costs its side a starting slot     port `c50c6fd`, source `6da9451`
Kind:      rule (bug fix)
Files:     `src/game/day_zero_generator.gd`
Source:    **already applied** to `backend/DayZeroGenerator.cs` (commit 6da9451) - the last change mirrored before the port became the game.
Hashes:    changed, fixtures regenerated from the C# at 6da9451
Sources:   manual p067 (Easy: four loyal systems each); SDPRTB entries 30/31; TheArchitect2018 `seed.js` (Coruscant decrements the Empire strong bucket; Yavin and the Alliance HQ are rim worlds outside the buckets)

## 2. Deterministic serials on Unit, Facility, Mission, GameMessage     port `e3a5976`
Kind:      plumbing (no rule effect)
Files:     `src/game/unit.gd`, `facility.gd`, `mission.gd`, `game_message.gd`, `game_session.gd`
Source:    not needed for single player. If the C# ever wants command replay: a static counter per class, reset with the game, assigned in the constructor, excluded from Snapshot and GameSignature - the pattern of `Fleet.NextSerial`.
Hashes:    unchanged

## 3. HumanFactions / IsHuman / LocalFaction; the AI skips every human side     port `e3a5976`
Kind:      plumbing (rule effect only when two humans exist)
Files:     `src/game/game_settings.gd`, `game_session.gd`, `ai_manager.gd`, `src/data/snapshot_loader.gd`
Source:    `GameSettings.HumanFactions` + `IsHuman(f)`; `AiManager.ProcessDay` skips `IsHuman(f)` instead of `f == PlayerFaction`. Identical with one human.
Hashes:    unchanged

## 4. Messages addressed to the human side they concern     port `f6f7f15`
Kind:      plumbing (rule effect only when two humans exist)
Files:     `src/game/event_bus.gd` (Tell, Visible, VisibleMessages), `game_message.gd` (For, Copy), the 27 gates in assault/blockade/captivity/character/fleet_battle/force/informant/military_catalog/mission/planet/repair/research/smuggling/story/victory managers, `src/ui/message_window.gd`, `src/ui/ui_manager.gd`
Source:    `GameMessage.For` + `EventBus.Tell(audience, msg)`; each `if x != PlayerFaction return` gate becomes `if !IsHuman(x) return` and the broadcast becomes `Tell(x, ...)`; two-audience events (blockade begun, battle report, victory) loop over the human sides with a copy each; the UI filters the log by the local side.
Hashes:    unchanged (one human = one copy of every message, as before)

## 5. Exploration is per faction; the AI no longer sees through the human's fog     port (M0 step 4)
Kind:      rule (bug fix) + plumbing
Files:     `src/game/planet.gd` (`ExploredBy`, `SetExplored`, `SetExploredForAll`; `IsExplored` is now the LOCAL side's chart, UI only), `day_zero_generator.gd`, `assault_manager.gd`, `intel_manager.gd`, `loyalty_manager.gd`, `mission_manager.gd`, `ai_manager.gd`, `game_signature.gd`, `src/data/snapshot_loader.gd`, `tests/soak.gd`, `tests/bench_1b.gd`
Source:    `Planet.IsExplored` was one bool meaning "known to the player"; `AiManager` (view.Unexplored) read it, so the AI saw the human's chart. Give `Planet` a per-faction set; day zero charts core worlds and the pack's charted starts for everyone, a rim claim and a hidden HQ only for their owner; assault/intel capture/reconnaissance chart for the acting faction; `LoyaltyManager` sums galaxy-wide support over the faction's own chart; `GameSignature` writes one bit per side; `Snapshot` would need one chart per faction (the C# snapshot carries only the human's - the port loads it for every human side).
Hashes:    changed (fixtures regenerated from the port): the signature format changed, and the AI now acts on its own chart.
Sources:   commit 7d55237 "cannot see through fog" (intent); manual p072/p100 (exploration is what YOUR side has charted)

## 6. SDPRTB: the fourth-column pairs are `dev` and `mp`, not per-player-side "mp"     port (M0)
Kind:      data relabel + rule (head-to-head only)
Files:     `data/side_lottery.json` (each entry: `by_faction.{alliance,empire}.{easy,medium,hard}` + top-level `dev` and `mp` pairs), `src/data/dto/catalog_dtos.gd` (`SideRuleData.Dev/Mp`), `src/game/side_lottery_manager.gd` (`Difficulty.Multiplayer` reads `Mp[side]`, no player-side row)
Source:    `data/parse_side_lottery.py` labels slots 3-4 as the Alliance-player "mp" pair and slots 17-18 as the Empire-player "mp" pair. The manual (p067) has THREE campaigns - Easy, Medium, Hard - so the fourth column is not a difficulty; open-rebellion's `dat-dumper` (`side_params.rs`) labels slots 3-4 `dev_*` and 17-18 `multiplayer_*`, the same reading `parse_rules.py` chose for GNPRTB columns 3 and 10 ("a choice, not a finding" - only the loader settles it). The port follows that reading so a head-to-head game reads one pair on both clients. C# change: `SideLotteryManager.GetProbability` for `Difficulty.Multiplayer` returns the entry's shared pair; the parser writes `dev`/`mp` at top level.
Hashes:    unchanged in single player (the three difficulties are untouched)
Sources:   manual p067 (three difficulties); open-rebellion `tools/dat-dumper/src/types/side_params.rs`; `data/parse_rules.py` header (GNPRTB precedent); Deep-Dive wiki SDPRTB ("8 x 2 x u32"). Confidence: single-source for the labelling - the SDPRTB consumer in REBEXE is not in any published decompilation.

## 7. Battle reports are oriented by pack order, not by the local human     port (M0)
Kind:      rule (bug fix) + plumbing
Files:     `src/game/fleet_battle_manager.gd` (`Engage`: Ours = the fleet of the faction first in pack order; `BattleReport.Mine/Enemy/Lost/MyStrength/EnemyStrength/MyLosses/EnemyLosses(viewer)`; `TheirsLost`; `Retreat(r, day, side)`), `src/ui/battle_alert_window.gd`, `src/ui/battle_results_window.gd`
Source:    `TacticalBattle` is order-sensitive (side 0 vs side 1 - seed 12345 day 12 at Denab resolved "both broken" one way round and "Empire beaten" the other), and `Engage` put the human's fleet at side 0, so a battle's outcome depended on which side the human played. Orient by pack order; the windows and `Retreat` take the viewer. Any human side in the battle now raises the alert (was: the human side only), and the retreating side is the one that answered - manual p152, "until one side withdraws".
Hashes:    changed for an Empire-side single player (the Alliance-side seed-12345 baseline is unaffected in orientation but was regenerated with #5)
Sources:   manual p151-p152 (Withdraw from Battle; "until one side withdraws"); the day-12 divergence log in docs/m0-audit.md

## 8. The command layer (M1 step 1): Command, CommandLog, EntityIndex, CommandApplier, CommandBus     port (M1)
Kind:      plumbing (no rule effect)
Files:     `src/command/*.gd`, `src/game/game_session.gd` (bus reset), `tests/command_apply.gd`, `tests/replay.gd`, `tests/ui_compile.gd`
Source:    not needed for single player. Shape if ever wanted: one command per UI mutation entry point, args by entity id (names for planets/sectors/characters/fleets, the M0 serials for units/facilities/missions/messages), a JSON-lines log with a header that rebuilds the game and the day hash after every tick, an applier that calls the same backend verb the UI called. Gate: a recorded 100-day scripted session replays to 100/100 identical hashes.
Hashes:    unchanged. M1 step 2 (commits 30acf59..c3d9a23) switched every UI call site to `CommandBus.issue`; GameManager opens the session log and hashes every tick.

## 9. Lockstep between two clients (M2): Transport, MailboxTransport, LockstepSession, Replayer     port (M2)
Kind:      plumbing (no rule effect)
Files:     `src/net/transport.gd`, `mailbox_transport.gd`, `lockstep_session.gd`, `src/command/replayer.gd`, `command_bus.gd` (Session hook; retreat answers sort first), `command_log.gd` (Reopen), `tests/lockstep_client.gd`, `tools/lockstep-local.ps1`
Source:    not needed for single player. The one rule-shaped choice: within a day's batch, Retreat answers apply before everything else, so "until one side withdraws" (manual p152) holds on both clients whichever side answered first.
Hashes:    unchanged. Gates: two processes over a mailbox, 200 of 200 day hashes identical; a forced corruption on one side is detected on the next day's hash, the honest side identifies the opponent, the drifted side rebuilds from the shared log and both continue.

## 10. The relay and the WebSocket transport (M3)     port (M3)
Kind:      plumbing (no rule effect)
Files:     `relay/server.ts`, `relay/test.ts`, `relay/docker-compose.yml`, `relay/README.md`, `src/net/websocket_transport.gd`, `src/net/relay_client.gd`, `tests/lockstep_client.gd` (--relay), `tools/lockstep-local.ps1` (-Relay)
Source:    not needed for single player.
Hashes:    unchanged. Gate A: the lockstep gate through a locally running relay, 200 of 200 day hashes identical; the relay's own test, 12 of 12.


## 11. Reconnect from the relay's log (M5, engine side)     port (M5)
Kind:      plumbing (no rule effect)
Files:     `src/net/lockstep_session.gd` (`rebuild_from_log`; end/hash/speed lines carry `side`; own lines in a `since` replay are ignored), `src/net/relay_client.gd` (`fetch_log`, `replayed_lines`, `caught_up`), `tests/lockstep_client.gd` (`--quit-at=`, `--rejoin`; runs to day Days+1 from wherever it starts), `tools/lockstep-local.ps1` (`-Rejoin`; hashes compared by day)
Source:    not needed for single player. A client that drops rejoins the room by name, asks the relay for the whole log, rebuilds the world with the Replayer to the last day both sides hashed, re-arms that day's batches, ends and hashes from the log, and continues in lockstep. The waiting side does nothing but wait.
Hashes:    unchanged. Gate: the Empire client quits on day 30 and rejoins; both reach day 201 with 171 of 171 shared day hashes identical. Save/Load (host-only, the same slot on both) is this mechanism behind C3PO's Multiplayer Options screen.
