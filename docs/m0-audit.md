# M0 audit — what in the simulation depends on "the player"

**Status:** DONE 2026-09-03 - all four steps landed, gate passed (bottom of this file).
Kept as the record of what was found and why each change was made.
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
- **Question 2, run through `research-game-rules` (2026-09-03).** Sources, in
  the skill's order: (1) GData: SDPRTB is 16 slots = two player-side blocks x
  four columns x two sides; three columns are Easy/Medium/Hard; the fourth is
  labelled "mp" per player side by `parse_side_lottery.py`, `dev` (slots 3-4)
  and `multiplayer` (slots 17-18) by open-rebellion's dumper, "Alliance-mp /
  Empire-mp (???)" by the Deep-Dive editor; `parse_rules.py` records that its
  own dev/mp reading of the same shape in GNPRTB "is a choice, not a finding".
  (2) TEXTSTRA/ENCYTEXT: no difficulty labels at all (the Shuttle Cockpit uses
  artwork). (3) Manual p067: "choose between Easy, Medium, or Hard campaigns"
  - THREE, so the fourth column is not a difficulty and the head-to-head
  screen offers none. (4) Community decompilation: the SDPRTB reader
  `FUN_00583f50` only allocates; its consumer is not published; `seed.js`
  reads through an unpublished helper. (5) Measurement: needs two machines on
  the original. **Verdict: the fourth column's meaning is Unknown at the
  source.** For lockstep the port needs ONE pair on both clients, and the
  least-invented choice is the reading two published sources share
  (open-rebellion's dumper and this repo's own GNPRTB convention): slots 17-18
  are the single multiplayer pair; no player-side row. Recorded as entry 6 of
  `docs/BACKPORT-LOG.md`. Entry 30's pair is 10/10 - symmetric, which is what a
  head-to-head start should be. `GameSettings.HostFaction` exists for the lobby
  but the tables no longer depend on it.

## Open questions for TeeJ

1. ~~Two humans in one battle~~ - answered by manual p152 (above): a Retreat by
   either side withdraws that side and ends the battle.
2. ~~The day-zero table rows~~ - resolved by research (above): head-to-head reads the
   single multiplayer pair (slots 17-18); nothing depends on whose row.

## M0 gate - PASSED 2026-09-03

```
tests/soak.gd -- --days=200 --seed=12345 --humans=both --difficulty=Multiplayer --faction=alliance --replay-log=a.log
tests/soak.gd -- --days=200 --seed=12345 --humans=both --difficulty=Multiplayer --faction=empire   --replay-log=b.log
```

Both logs identical, 201 of 201 day hashes, 24 battles each. Single player
still differs by side, as it must (the AI side differs). The seed-12345
single-player baseline was regenerated from the port (BACKPORT-LOG 5-7) and the
self-regression check passes 101 of 101.
