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
