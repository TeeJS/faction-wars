# faction-wars — status, missing features, backlog & known bugs

The single tracker for outstanding work. Sections: **Status** (done / in
progress), **Missing Features** (described by the manual, or required by the
port's own systems; not built), **Backlog** (lower-priority, not blocking
play), **Known Bugs** (confirmed, unfixed), **Non-issues** (investigated, no
change). Started 2026-09-05 in the agent-room dev session; keep it current as
items move.

Every merge below was verified headless on **Godot 4.7.1** (the project's
target) before landing.

---

## Status — done this session (merged)

| # | Item | PR |
|---|------|----|
| 1 | Comms "Go To" opens the associated planet's Defenses window | #8 |
| 2a | Fog: hide enemy personnel on a mission (OnMission) on a world you hold | #11 |
| — | Hotfix: #2a multi-line predicate broke parsing on Godot 4.7.1 | #14 |
| 2b | Defender notified on enemy mission foil / sabotage success (fog-blind) | #15 |
| 5 | "All Messages" at the top of the left-column category menu | #16 |
| 6 (A) | Single-player **Save** + six-slot Game Options screen | #17 |
| 6 (B) | Single-player **Load** — start-menu Load Game + GameManager replay | #22 |
| 7 | Keyboard shortcuts — all mappable strategic ones (F1/F2/F5/F6, Alt+I/O/0/W/G/U, Alt+1-9) | #20 #23 |
| 8 | Fix MenuButton `pressed` double-connect log spam | #18 |
| — | `faction-wars-dev` skill (workflow + context-MCP + handoff template) | #9 #10 #12 #13 |
| — | `BACKLOG.md` tracker | #19 |

## Status — in progress

*None — all approved work is merged.* What remains is under **Missing Features**
(new screens) and **Backlog** below; those need TeeJ's go before they start.

---

## Missing Features

Things the port does not yet have: mostly features the manual/original
describes that need new screens, plus gaps in the port's own systems that have
no original to cite.

| # | Feature | Source / note |
|---|---------|---------------|
| 9 | **F3** Fleet/Ship Finder window | no fleet finder exists (only Personnel + Planet finders) |
| 10 | **F4** Troop Finder window | no troop finder exists |
| 11 | **F7** Encyclopedia window | no Encyclopedia window exists at all |
| 12 | **Alt+B / Alt+T / Alt+F** build ships / troops / installations screens | no standalone build/manufacturing window |
| 13 | **Pack hash in the multiplayer settings** | Two clients on the same `pack.json` id but differing pack *content* desync on the lockstep hash, presenting as a mystery mismatch rather than "wrong pack". `SCHEMA.md` (source repo) carries `schema_version`, which guards engine-vs-pack, not client-vs-client. Put a pack id + content hash in the `settings` blob the relay already forwards through `create`/`join`/`start` (`relay/server.ts`) and verify it on join. Bites once Phase 2+ of the pack migration lands; see `PROJECT.md` phases in the source repo. |
| — | Other window-checklist gaps | see `docs/window-checklists.md` (Missing/Partial rows) — e.g. portrait art placeholders, modal-vs-nonmodal chrome |

## Phase 5 — pack modularity (setting names still in engine code)

Phases 1–4 of the pack migration are merged (SCHEMA.md status). Phase 5 is the
modularity proof: a second pack on an unchanged binary. The audit below
(2026-09-22, spot-checked non-comment code) lists every place engine code still
selects on a Star Wars name or reads the legacy `data/` folder. Each one breaks
SCHEMA.md §1 ("names are never behaviour") and would break a second pack.

| # | Leak | Where | Fix direction |
|---|------|-------|---------------|
| 14 | Capital-change loyalty shock keyed on `p.Name == "Coruscant"` | `src/game/loyalty_manager.gd:85` | **PR #48** — every fixed-HQ world in `factions.json` |
| 15 | Day zero finds `"Emperor Palpatine"` by name | `src/game/day_zero_generator.gd:198` | **PR #49** — `starts_at_hq` role |
| 16 | Droid unit display names map to mission types ("Imperial Probe Droid" …) | `src/game/mission_manager.gd:24-26` | **PR #48** — `missions.json` `spec_forces` inverted |
| 17 | `actor.Id == "empire"` branches; agent droid names IMP-22 / C-3PO | `src/game/mission_manager.gd:490`, `src/game/agent_droid.gd:41` | **Done** — PR #48 (`agent_name`, Assassination `available_to`); HQ sabotage derived from `hq.kind` (hidden = destroyable, fixed = captured), TeeJ 2026-09-22 |
| 18 | Replay header defaults the local side to `"alliance"` | `src/command/replayer.gd:22` | **PR #48** |
| 19 | `death_star_shield` / `death_star_sabotage` ids in engine | `src/game/bombardment_manager.gd:144`, `src/game/mission_table_manager.gd:18`, `src/game/mission_catalog.gd:39`, `src/data/snapshot_loader.gd:18` | facility role (`superweapon_shield`) and mission role tags |
| 20 | `SeedManager` still loads legacy defensive/military JSON through `Loaders`, family ids 34/35/36 → `ion_cannon` etc. | `src/game/seed_manager.gd:23-38` | **PR #48** — `Facility.Def` carries the stats |
| 21 | Military Data Editor reads `res://data/military_units.json` directly | `src/ui/military_data_editor.gd:37` | **Done** — editor removed with its data (TeeJ, 2026-09-22) |
| 22 | Legacy `data/` folder (15 JSON files) still shipped; `tests/dto_parity.gd` reads it | `data/`, `src/data/loaders.gd` | **Done** — folder, `Loaders` and eleven DTOs deleted; `dto_parity` compares the loaded pack with `tests/fixtures/dto-pack.json` |
| 23 | Rule-id constants carry setting names (`SeedCoruscantFirst`, `EspionageRevealCoruscantFloor`) | `src/game/rule_id.gd:93`, `src/game/mission_manager.gd:189` | naming only — rename to `SeedCapitalFirst` etc. when #14 lands |
| 24 | **Modularity proof** — a second, deliberately alien pack runs on an unchanged binary | source repo `PROJECT.md` Phase 5 | last; proves #14–#23 and #25–#34 |
| 25 | Day-zero character placement by display name: six to the first world, Mon Mothma to the HQ, Palpatine to the HQ, six Imperials to a random holding | `src/game/day_zero_generator.gd:186-217` | **PR #49** — `starts_at_*` roles |
| 26 | Story set-pieces keyed on names — the four Luke/Leia vs Vader/Emperor pairings, Han, Chewbacca | `src/game/story_manager.gd:7-27` | **PR #49** — `pilgrim` / `heir` / `dark_lord` / `dark_master` / `smuggler` / `companion` |
| 27 | Force pilgrimage and heir by name (Luke, Leia) | `src/game/force_manager.gd:8-9` | **PR #49** |
| 28 | Millennium Falcon effect keyed on "Han Solo" | `src/game/order_manager.gd:38` | **PR #49** — `smuggler` |
| 29 | Emperor excluded from special-power training by name | `src/game/mission_manager.gd:93` | **PR #49** — `dark_master` |
| 30 | Death Star: family 24 literal, `u.Name == "Death Star"`, `DeathStarAt` | `src/game/mission_manager.gd:53,175,512` | **PR #49** — `superweapon` |
| 31 | Garrison score term counts "Stormtrooper Regiment" by name | `src/game/mission_manager.gd:216` | **PR #49** — `garrison_troop` (engine and the AI mirror) |
| 32 | Engine joins its behaviours to the pack ids `death_star_sabotage` / `jedi_training` (and `dagobah` / `palace`, and the ten mission-table ids) | `src/game/mission_catalog.gd:39-40` | **PR #49** — `behaviour`; a mission's table shares its id |
| 33 | Snapshot import maps the C# snapshot's facility names (legacy format) | `src/data/snapshot_loader.gd:13-19` | **Kept** — `tests/fixtures/snapshot-seed12345.json` is still the bench/soak day-zero fixture; the map is the format boundary for that external file |
| 34 | Rule-id constants named for the setting (`SeedYavin*`, `SeedAllianceHq*`, `LukeVsVader*`, `DeathStarSabotage*`) | `src/game/rule_id.gd` | rename with #23 |
| 35 | Multiplayer Options win-condition tooltips are the manual's p162 text with Star Wars names (pinned verbatim by `tests/mp_screens.gd:134`) | `src/ui/mp/multiplayer_options.gd:11-12` | UI string only, selects nothing; a pack string when the p162 wording is allowed to vary |

## Backlog (lower priority, not blocking play)

| Item | Note |
|------|------|
| **Ctrl+Tab** cycle windows, **PgUp/PgDn** scroll, **Arrows** browse, global **Enter/Esc** | navigation polish, not wired |
| **Alt+M** Mission / **Alt+S** Status for the *selected* unit | needs a global "selected unit" concept — verify it exists first, else it's a no-op |
| "(captured)" label on a held enemy character in the Personnel tab | polish (see #4) |
| `SaveManager.Save` atomicity — write the index before the slot file (or temp-then-rename) so a crash mid-save can't desync them | minor robustness |

## Known Bugs (confirmed, unfixed)

*None currently open.* Bugs found in the 2026-09-05 session were all fixed
and verified (fog leaks #2a, defender-notice gap #2b, the 4.7.1 parse break,
the MenuButton double-connect). New confirmed bugs go here with a repro +
file:line.

## Non-issues (investigated, no change)

| # | Item | Verdict |
|---|------|---------|
| 4 | Kidnapped enemy shown on your Personnel tab | **Working as intended** — a captured enemy is *your* prisoner on *your* world (`Attached` = the holding world); you legitimately see your own captives. #2a's OnMission-only scope was correct; also hiding Kidnapped would be a regression. |

---

## Keyboard-shortcut audit (Steam guide + code trace)

**Done:** Alt+P (pause), Alt++/− (speed), Alt+H (objectives), Alt+O/Alt+0 (overview),
F1→Game Options, F2→System Finder, F5→Character Finder, F6/Alt+I→Message index,
Alt+W→close all, Alt+G/Alt+U→toggle Manage Garrisons/Production, Alt+1..9→Galaxy
Display modes. (PRs #20, #23.)
**Missing screen (backlog #9-#12):** F3, F4, F7, Alt+B/T/F.
**Skip:** Alt+Y (MP), Alt+V (R2-D2 sounds), Alt+A (tips), Alt+F4 (OS). Tactical
shortcuts (`tactical_view.gd`) — separate audit.

## Process notes

- Verify every change **headless on Godot 4.7.1** before merge (4.5.1 missed the
  #2a parse break). New `class_name` files need a `--import` before a headless
  test can reference them.
- One branch + one PR per issue; the chair is the sole committer/pusher/merger.
  See `.claude/skills/faction-wars-dev`. Related ledgers: `docs/window-checklists.md`
  (per-window manual-vs-port), `docs/BACKPORT-LOG.md`, `HANDOFF.md`.
