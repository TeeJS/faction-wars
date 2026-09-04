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
Hashes:    unchanged. Gate A: the lockstep gate through a locally running relay, 200 of 200 day hashes identical; the relay's own test, 16 of 16. Gate B (2026-09-03): the same through the live container on Unraid, 200 of 200. The relay ships as `ghcr.io/teejs/wars-relay` (relay/Dockerfile, .github/workflows/relay-image.yml, relay/unraid/my-wars-relay.xml).


## 11. Reconnect from the relay's log (M5, engine side)     port (M5)
Kind:      plumbing (no rule effect)
Files:     `src/net/lockstep_session.gd` (`rebuild_from_log`; end/hash/speed lines carry `side`; own lines in a `since` replay are ignored), `src/net/relay_client.gd` (`fetch_log`, `replayed_lines`, `caught_up`, `list_saves`/`saves`), `relay/server.ts` (`saves`: the started games a player is in, newest first), `tests/lockstep_client.gd` (`--quit-at=`, `--rejoin`; runs to day Days+1 from wherever it starts; the resume day's orders are not repeated), `tools/lockstep-local.ps1` (`-Rejoin`, `-Load`; hashes compared by day)
Source:    not needed for single player. A client that drops rejoins the room by name, asks the relay for the whole log, rebuilds the world with the Replayer to the last day both sides hashed, re-arms that day's batches, ends and hashes from the log, and continues in lockstep. The waiting side does nothing but wait.
Hashes:    unchanged. Gates: (rejoin) the Empire client quits on day 30 and rejoins; both reach day 201 with 171 of 171 shared day hashes identical. (load) BOTH quit on day 30, the relay is killed and restarted so the room must come back from disk, both rejoin: 171 of 171. The relay test covers `saves` and the restart (16 of 16). Save is therefore nothing the player does: every line is already on the relay (and in each client's own user:// log). Load = the Multiplayer Options list of `saves` the two names share, then this rejoin, behind C3PO's screen.

## 12. The head-to-head screens, Figs 5.1-5.9, and Load Game (M4 batch 1 + M5 Load)     port (M4/M5)
Kind:      UI (no rule effect)
Files:     `src/net/mp_setup.gd` (the state across the screens; `reset()` on every exit path; the relay URL from the page's origin or `--relay=`), `src/ui/mp/*` (`MpBottomBar`, `MpScreen`, Multiplayer Configuration, Host Game, Locate Session, Join Game, Multiplayer Options with the Load Game list), `Menu.tscn`/`menu.gd` (the Multiplayer panel, lower left), `src/ui/game_manager.gd` (`_StartLockstep`: the session on the lobby's transport, the log under the room code, rebuild from a loaded game's log; the clock marks the day due and `_process` advances it through the session), `src/ui/in_game_menu_window.gd` (exits reset the session), `src/net/relay_client.gd` (`name`, `opponent_left`), `relay/server.ts` (`saves` carry `day`), `tests/mp_screens.gd`, `tests/mp_flow.gd`, `tools/mp-flow-local.ps1`
Source:    manual p156-p163, Figs 5.1-5.9, element by element per docs/multiplayer-ui-design.md sections 1-7 (reviewed by Doof). Deviations recorded there: one honest provider entry; a game code instead of an IP address; browser defaults for the names; the host's name after the game name in the Join list; no artwork.
Hashes:    unchanged. Gates: `tests/mp_screens.gd` 48 checks (every figure element, the manual's wording); `tools/mp-flow-local.ps1 -Days 20 -Load`: two headless clients through the real screens into lockstep, 19 of 19 day hashes identical; a second pair picks the game from the Load Game list and resumes it at day 21, 19 of 19. Single player unchanged (`ui_smoke --main`, the relay lockstep gate).

## 13. The in-game head-to-head pieces: Chat Messages, Compose Chat Message, shared speed, Waiting for Opponent, Save (M4 batch 2 + M5 Save)     port (M4/M5)
Kind:      UI (no rule effect)
Files:     `src/ui/message_window.gd` (tab title "Chat Messages"; double-click opens a message; the Compose Chat Message button at the bottom of the right-hand column, head-to-head only), `src/ui/ComposeChatMessageWindow.tscn` + `compose_chat_message_window.gd`, `src/ui/ui_manager.gd` (`OpenComposeChatMessage`), `src/command/command_applier.gd` (the incoming line reads "Message From The Empire"), `src/ui/game_manager.gd` (`_ApplyClock`: the slower of the two settings governs, the face says "(set by opponent)"; `MenuOpened`; `_MpWatch`: Waiting for Opponent, Leave Game after 60 s behind a confirmation, desync repair from the log), `src/ui/in_game_menu_window.gd` (the opponent waits while the Game Options screen is up; host-only Save Game), `src/net/lockstep_session.gd` (`opponent_gone` from the relay's seat notices), `tests/mp_screens.gd`, `tests/mp_flow.gd`
Source:    manual p162-p164, Figs 5.10-5.11, per docs/multiplayer-ui-design.md sections 8-12 (Doof's answers A-D). Speed and pause travel as the M2 protocol's `speed` line (not as commands), so a rebuilt game resumes at the speeds the log last recorded. Save writes nothing new - every line is already on the relay and in both clients' logs - so it confirms "Saved on both computers: <game>, Day N" or says the relay is unreachable. Single-player Save/Load is NOT in the port (flagged to TeeJ, design question E).
Hashes:    unchanged. Gates: `tests/mp_screens.gd` 58 checks; `tools/mp-flow-local.ps1 -Days 16 -Load`: the host chats on day 3 and the guest's Chat Messages receive "Message From The Alliance"; the host opens the Game Options screen on day 6 and the guest sees Waiting for Opponent; the guest sets Medium on day 10 and the host's face reads "(set by opponent)"; 15 of 15 day hashes identical, then Load resumes at day 17, 15 of 15. Single player unchanged.

## 14. Game speed rule: Slowest wins (manual) or Average (TeeJ's addition)     port (M4)
Kind:      rule (deliberate deviation, user-requested) + UI
Files:     `src/game/game_settings.gd` (`SpeedRule`), `src/net/lockstep_session.gd` (`combine_speeds`, `effective_speed`), `src/ui/game_manager.gd` (clock and face), `src/net/mp_setup.gd` (travels with the room settings, restored by Load), `src/ui/mp/MultiplayerOptions.tscn` + `multiplayer_options.gd` (the "Game speed rule" row: Slowest wins / Average, host only, echoed), `tests/speed_rule.gd`, `tests/mp_screens.gd`, `tests/mp_flow.gd` (`--speed-rule=`), `tools/mp-flow-local.ps1` (`-SpeedRule`)
Source:    manual p163 says the game runs at the slowest speed set on either computer; that stays the default. TeeJ (room AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #75) asked for a second, host-chosen rule: the average of the two settings, rounding down, so adjacent settings give the slower one and an unbalanced pair rounds down (Slow + Fast = Medium; Fast + Very Slow = Slow). Pause on either side pauses both under either rule (a pause must stop both; Waiting for Opponent depends on it). Plan reviewed in the room (#77, Sonnet #78).
Hashes:    unchanged (speed never enters the simulation). Gates: `tests/speed_rule.gd` 55 of 55 (all 25 pairs under both rules plus TeeJ's examples); screens smoke 61 of 61; the flow gate under `average` shows "Medium (averaged with opponent)" on the host's face for guest Medium vs host Fast.

## 15. The tester's feedback box: "Provide feedback" on the Cockpit, a note with the session log to the relay     port (tooling)
Kind:      tooling (no rule effect; an addition to the Cockpit, not from the manual)
Files:     `Menu.tscn` + `src/ui/menu.gd` (the checkbox, remembered in user://mp.cfg), `src/game/game_settings.gd` (`ProvideFeedback`), `src/net/mp_setup.gd` (prefs), `src/ui/feedback_panel.gd` (the box at the bottom of the left column: note, Submit, result line; POST to the relay's /feedback; kept under user://feedback/ when the relay is unreachable), `src/ui/ui_manager.gd` (adds it when ticked), `src/command/command_log.gd` (`Snapshot`), `relay/server.ts` (POST /feedback: 4 MB cap, feedback/<utc time>-<player>.json + .jsonl), `relay/test.ts`, `tests/feedback_smoke.gd`, `tools/feedback-local.ps1`
Source:    TeeJ (room AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #80): a checkbox in the New Game menu; when ticked, a text field and Submit in the game where a tester writes a note that is saved on the server with diagnostic data or a log of the gameplay. Plan #85 (per-tester, not per-room; the report carries the client's own session log so it can be replayed to the day; local fallback), approved by Sonnet #86.
Hashes:    unchanged. Reports land on the box under /mnt/user/appdata/wars-relay/data/feedback/ and are listed at `GET /feedback` (newest first, no logs) - wars.schmitzplex.com/feedback. Gates: relay test (accepted, files written, junk and empty refused); `tools/feedback-local.ps1` (a headless single-player game submits a note through a local relay; the report's player/game/day/seed/log lines are checked).

## 16. "Opponent paused." in the Waiting for Opponent box; the build version on screen     port (M4 / tooling)
Kind:      UI wording (deliberate deviation, user-requested) + tooling
Files:     `src/ui/game_manager.gd` (`_MpWatch`: the box's body says "Opponent paused." when the opponent's speed is 0 - Pause or their Game Options screen - and "Waiting for opponent..." otherwise; the connection-lost line as before), `src/game/build_info.gd` (`version()` from `res://version.txt`, "dev" without it), `.github/workflows/relay-image.yml` (writes version.txt = utc date + short commit before the export), `src/ui/ui_manager.gd` (the version right of the Menu button), `src/ui/menu.gd` (bottom right of the Cockpit), `tests/mp_screens.gd`, `tests/mp_flow.gd`
Source:    manual p163 has one message, "Waiting for Opponent"; TeeJ (room AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #106) asked the waiting player to be told the reason, knowing it departs from the original. The version stamp is tooling.
Hashes:    unchanged. Gates: screens smoke (the Cockpit's version label); the flow gate reports whether the guest's box said "Opponent paused." while the host's Game Options screen was open.

## 17. Rejoin by code into a started game; the code on the Waiting for Opponent box     port (M5)
Kind:      plumbing + UI
Files:     `src/ui/mp/multiplayer_options.gd` (a guest or host who joins a started game with lines on the relay pulls the whole log and the game is rebuilt, as Load does), `src/ui/game_manager.gd` (the Waiting for Opponent box shows the game code when the opponent dropped), `src/ui/mp/join_game.gd` (a taken seat says the rejoiner must use the same name), `tests/mp_flow.gd` (`--quit-at=`, `--rejoin-code`), `tools/mp-flow-local.ps1` (`-RejoinCode D`)
Source:    TeeJ (room AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #110): "if no one has the code, how can they rejoin?" Checking it showed that joining a started game by code went to a fresh day 1; only Load Game rebuilt. Now both paths rebuild from the relay's log (`LockstepSession.rebuild_from_log`, BACKPORT-LOG #11).
Hashes:    unchanged. Gate: `tools/mp-flow-local.ps1 -Days 16 -RejoinCode 6`: the guest drops on day 6, comes back through Locate Session (the code), Join Game and Multiplayer Options, rebuilds, and the shared day hashes match.

## 18. Phase lockstep: orders apply within a phase, the day ticks on the host's marker     port (M2 revised)
Kind:      plumbing (no rule effect; changes WHEN an order takes effect in head-to-head, not what it does)
Files:     `src/net/lockstep_session.gd` (rewritten around phases: `phase`, `end_phase(advance)`, `try_phase()`, `overdue_ms()`; `try_tick()` kept for the headless clients; `rebuild_from_log` re-applies completed phases), `src/command/command.gd` (`Phase`, in the JSON), `src/command/command_bus.gd` (`apply_batch`, the one ordering routine; `apply_day` calls it), `src/ui/game_manager.gd` (a 300 ms phase timer; the host's day clock sets the advance marker; stall detection by the overdue phase), `tests/lockstep_client.gd` (the alliance client hosts), `tests/mp_flow.gd` (the guest reports the day and delay of the host's chat)
Source:    TeeJ's live game (room AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #97): orders felt slow because M2 applied them only at the day boundary; the original applies orders immediately. Plan #99, Doof's review #118/#121: commands carry a phase number only; the boundary is the host's end line with advance:true; one ordering routine for phases and days; the relay already logs every line; 300 ms phase, latency = phase + one round trip; the guest's clock emits nothing. Pause still stops both (the host sends no advance while paused; the guest sees Waiting for Opponent).
Hashes:    unchanged for every gate (the day hash is the same state at the same tick). Old logs replay identically (no phase field = phase 0).

## 19. Defences are Sabotage targets from the System Defenses window     port (feedback)
Kind:      UI gap (no rule change: the rule was already in `CanSabotage`)
Files:     `src/ui/defense_window.gd` (the Orbital Defenses rows are buttons that resolve the mission crosshair, like the Manufacturing window's facility rows and the fleet rows), `src/ui/draggable_window.gd` (the system-click popup names the windows to open), `tests/sabotage_targets.gd`
Source:    manual p040 ("select a particular facility to sabotage"), p108 (targets: facility, capital ship, fighter squadron, trooper regiment, SpecForce), Encyclopedia ("a sabotage mission destroys a facility, capital ship or an object"); TeeJ's feedback report 2026-09-03T23-56-45 and room #198 ("defences are all potential sabotage targets"). Regiments and fighters on the ground already took the crosshair through `SetupMenuButton`; shields, batteries and ion cannons were plain labels, so a system defended only by them had nothing to click. Sabotage stays object-specific, as the original is (TeeJ confirmed from his own play, room #219/#224, with two screenshots: targeting the object GenCore Level I gives Sabotage; targeting the whole world gives only world missions, no Sabotage). An earlier build of this entry added a world-level "Target:" picker on a system click; that was wrong and was removed (room #221-#224) - Sabotage never appears on a bare world pick. The one path is: crosshair a compatible object (facility, defence, ship, regiment, squadron, SpecForce) and Create Mission opens naming that object.
Hashes:    unchanged. Gate: `tests/sabotage_targets.gd` (CanSabotage accepts an enemy shield, battery and ion cannon, refuses our own; the Orbital Defenses tab carries one target row per sighted defence and none unseen).

## 20. Shorter join path: two-button Configuration, Locate Session joins by code, Join Game removed     port (M4 revised)
Kind:      UI (deliberate deviations, user-requested)
Files:     `src/ui/mp/MultiplayerConfiguration.tscn` + `multiplayer_configuration.gd` (no provider list, no Proceed; Connect To Game / Setup Game act at once), `src/ui/mp/LocateSession.tscn` + `locate_session.gd` (player name, code required, OK looks the code up and joins; relay answers on a status line), `src/ui/mp/JoinGame.tscn` + `join_game.gd` removed, `src/ui/mp/host_game.gd` (the game name follows the player name while it is "<name>'s game"), `src/ui/game_manager.gd` (the waiting box's title is "Waiting" - the full title was cut off), `tests/mp_screens.gd`, `tests/mp_flow.gd`, `docs/multiplayer-ui-design.md` (checklist rows 5.2, 5.6, 5.8)
Source:    TeeJ, room AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #197 items 1, 2, 4, 6 (and #68: "we've already picked it by putting in the code"). Manual Figs 5.2, 5.6 and 5.8 describe the longer path; the deviations are recorded in the design doc.
Hashes:    unchanged. Gates: screens smoke; the flow gate's guest and rejoin-by-code paths now go Locate Session -> Multiplayer Options.

