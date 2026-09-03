# M0 audit — what in the simulation depends on "the player"

**Status:** findings and proposed changes, 2026-09-03. Nothing edited yet; posted
for review (C3PO, Doof) and for TeeJ's answers to the two questions at the end.
Gate for M0: a 200-day soak with the local faction set to Alliance, then Empire,
then neither, prints identical day hashes all three ways, and the single-player
503/503 parity still holds.

## 1. The 45 reads of `GameSettings.PlayerFaction` under `src/game/`

| Class | Count | Where | What it means for lockstep |
|---|---|---|---|
| **Message gate** — "only tell the player": `if x.Faction != PlayerFaction: return` before `EventBus.BroadcastMessage` | 27 | assault 180; blockade 119, 135; captivity 61; character 175; fleet_battle 213; force 62, 112, 137, 176; informant 61; military_catalog 180, 217; mission 288, 304; planet 512, 530, 741; repair 104; research 88; smuggling 46; story 100, 145, 190, 233, 314, 332; victory 79 | The message log is game state (the day hash counts it, and Continue/Abort decisions hang off it), so both clients must produce the SAME log. Each of these becomes "for every human faction this concerns, broadcast a message addressed to it". The UI shows only the local faction's. |
| **Simulation branch** | 3 | ai_manager 46 (AI skips the human); day_zero 57 (the hidden HQ is explored only for the human); day_zero 129 (a claimed world is explored if the claimant is the human) | Real MP bugs: the sim would differ by which client is local. Become `IsHuman(f)` and per-faction exploration (§2). |
| **Battle orientation** | 2 | fleet_battle 127–129 (`Ours` = the human's fleet in a BattleReport) | The report is the thing the player answers; with two humans in one battle each needs its own view and its own answer (§3). |
| **Rule column default** | 3 | rule_manager 55, 62 (`Get`/`GetShared` default to the player's column); 19–25 (sanity print) | Neutralised in head-to-head: `Difficulty.Multiplayer` selects the shared column. See open question 2 for the one table that is NOT shared. |
| **Setup** | 3 | game_session 70, 75, 80 | Becomes: set `HumanFactions` (one or two) and `LocalFaction`. |
| **Presentation / logs** | 7 | day_zero 244, 253 (intel print-outs); victory 101 (`viewer_owns` — takes an explicit viewer); rule_manager 21, 25 | Pass the viewer explicitly or print for every human. No hash effect. |

## 2. The fog model is single-viewer — the biggest finding

`Planet.IsExplored` is ONE boolean per world meaning "known to the player".
Written at day zero (start worlds, the human's hidden HQ, core worlds, the
human's claims), by reconnaissance (mission 203), by assault (153) and by intel
capture (intel 108). Read by the AI at ai_manager 66 — **so today the AI looks
through the human's fog, not its own** (the "cannot see through fog" commit
gated on the human's flag). In lockstep there is no "the player": exploration
must be per faction.

| Today | Proposed |
|---|---|
| `var IsExplored: bool` | `ExploredBy(f: Faction) -> bool`, `SetExplored(f, on)`, backed by a per-faction set; the day-zero rules apply per human side (core worlds + own claims + own HQ), exactly what one human gets today |
| AI reads `IsExplored` | AI reads `ExploredBy(us)` |
| UI reads `IsExplored` (gid, sector, planet, finder, economy, mission windows, debug keys: 14 reads) | `ExploredBy(GameSettings.LocalFaction)` |
| GameSignature hashes `IsExplored` | hashes the per-faction set, so the fog itself is part of parity |

⚠ This changes single-player behaviour: the AI stops seeing the player's
exploration. That breaks the 503/503 parity with the C# source unless the
same change is made there. **Recommendation: mirror it in the source
(`backend/Planet.cs` + the five writers + `AiManager`), because the AI reading
the player's fog is a bug in the source too, and keeping the parity gate alive
is worth more than the C# diff.** Alternative: keep an `IsExplored` alias that
returns the FIRST human's flag so single-player stays bit-identical - rejected,
it would leave the AI cheating and the alias would be the kind of thing that
gets built on.

## 3. Battles with two humans

`FleetBattleManager.Engage` orients the report as Ours/Theirs around the one
human, parks it in `AwaitingOrders`, and the day waits for ONE answer (simulate,
retreat, take command). With two humans in the same battle:

- each client needs the report oriented to ITS side (a presentation view over
  one shared report, not two reports);
- the day cannot advance until BOTH have answered (a battle answer is a command
  in the M1 sense, one per involved human);
- the resolution rule when the answers differ is **not stated in the manual's
  head-to-head chapter**. The tactical chapter's "Battle Options" (manual p151)
  may say; it is on the reading list before M2. Until a source says otherwise
  this is **open question 1** below - not something to invent.

## 4. Entity serials

Commands name things. Fleet already has a deterministic serial. Add the same,
assigned at creation from a per-game counter reset with the game: `Unit.Serial`,
`Facility.Serial`, `Mission.Serial`, `GameMessage.Serial`. Excluded from the
snapshot and the signature, like the fleet id, so hashes do not change.

## 5. Settings shape

```
GameSettings.HumanFactions : Array[Faction]   # SP: [chosen]; MP: both playable
GameSettings.LocalFaction  : Faction          # this client; SP: the chosen one
GameSettings.IsHuman(f)    -> bool
GameSettings.PlayerFaction                     # kept as an alias of LocalFaction for the UI only;
                                               # the sim may not read it (a test greps for it)
```

## 6. Order of work inside M0

1. Serials (no behaviour change; hashes unchanged) - commit.
2. `HumanFactions` / `LocalFaction` / `IsHuman`; AI and setup switched - commit; parity check.
3. Messages addressed to a faction; the 27 gates rewritten; UI filters by local faction - commit; parity check (message COUNT changes only if a second human exists, so SP hashes hold).
4. Per-faction fog, in the source first, then the port; fixtures regenerated; parity re-proven; the three-way local-faction soak added to `tests/` as the M0 gate.

## Answers found after posting

- **Question 1 is answered by the manual.** Tactical chapter, "After the Battle"
  (manual p152): "Battle continues until one side destroys all of the opposing
  capital ships and fighters, **or until one side withdraws**." And "Withdraw
  from Battle" (p151) is each side's own option, refused only by tractor beams,
  speed or a gravity well. So with two humans: each answers for its own fleet;
  a Retreat by either side withdraws that side (subject to the existing gravity
  well refusal) and the battle ends; otherwise it is simulated. Not invented.
- **Question 2 stays open.** TheArchitect2018's `seed.js` reads the table through
  `game_resources.side_param(session, id, 0|1)`; the 0/1 is the SIDE column, and
  the helper that turns `session` into a row is not published. Inconclusive.

## Open questions for TeeJ

1. ~~Two humans in one battle~~ - answered by manual p152 (above): a Retreat by
   either side withdraws that side and ends the battle.
2. **The day-zero table rows are keyed by the human's side.** `side_lottery.json`
   entries 30/31 ("Core Sector Owned Systems") have an "mp" column, but it still
   sits under a "human faction" row, and the two rows differ (human Alliance:
   20/25; human Empire: 10/10 for entry 30). In head-to-head there are two humans.
   The manual says nothing. The original's behaviour would settle it (the seed
   routine in TheArchitect2018's `seed.js` reads a `session` side; I will check
   which). If that is inconclusive, the least-invented choice is the HOST's side
   (the host configures the game on the Multiplayer Options screen). seed.js
   turned out not to say (above). **Proposed: the host's side.** Your call.
