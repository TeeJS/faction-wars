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
| 40 | **The original's art out of the public repo; owners import it** (`docs/original-art-plan.md`). The signed Faction Wars Exporter writes the player's own art set; the game imports it into browser storage or the user folder; art sets are separate from shareable faction packs, which wear the original UI through per-faction skins. The art is gone from the repo, its history (rewritten, backup `D:\Backup\faction-wars\faction-wars-20260923-1518.git`) and GHCR. Optional, TeeJ's: a GitHub Support ticket for the old commits still reachable through PR refs | #114 #115 #116 #117 #118, exporter-v2.1.0 |

## Status — in progress

*None - all approved work is merged.* What remains is under **Missing Features**
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
| 13 | **Pack hash in the multiplayer settings** | **Done** (branch `pack-plumbing`): the host's room settings carry `pack` + `pack_hash` (SHA-256 over the pack's JSON files); a guest on another pack or different content is told on the Options screen (`MpSetup.pack_mismatch`), and the lockstep hello refuses the start. The command-log header carries both too, so a save/replay/snapshot from another pack is refused by name (`FactionRegistry.HeaderMismatch`). `--pack=<id>` selects the pack headless; `FactionRegistry.ListPackIds()` is the picker's list |
| 36 | **Old-repo dependency in the generators.** Six `tools/build-*-json.py` transforms: four read `data/` (deleted in #52), two read the old repo via `SCR_SOURCE`, and all six would have wiped the hand-added pack fields | **Done** — retired (TeeJ, 2026-09-22). The pack is hand-edited and is the contract; `source_*` fields keep provenance |
| 38 | **Ships and fleets named like the original** | TeeJ, 2026-09-23. Fleet lookup by serial first; the original's own naming scheme to be read from its screens / tables before building. **Done** (2705081, 2026-09-24): "Fleet 1" per side (manual p121) and ships numbered in their class ("Corellian Corvette 5", manual p122 Fig. 3.65); orders name fleets by ID |
| 39 | **Message subject pictures** | TeeJ, 2026-09-23. Follow-up from the window-matching work (#95-#113); scope to be checked against the original before building |
| 41 | **Sound: music and sound effects** — Play Music on/off, the music and sound effects volume sliders (Game Options, manual p076 Fig. 3.16) | TeeJ, 2026-09-23. The game has no sound at all yet; the Game Options screen shows the three controls greyed until it does. **The music: `docs/music-plan.md`** (2026-09-26, for TeeJ's decisions) |
| 42 | **Tactical Display Options** — Show Starfield, Show Planet, Show Pyrotechnics, Use High Detail Models, Display Holocube (manual p076; "default to on", not changeable mid-battle) | TeeJ, 2026-09-23. Needs the tactical battle view, which the port does not have; shown greyed on the Game Options screen |
| 43 | **Cockpit credits monitor → the original's credits sequence.** In the original the LucasArts-logo monitor plays a credits cutscene (a starfield, "Director and Lead Designer / Scott Witte" and so on). Ours opens a popup of the pack's credits: remove it and leave the monitor inactive until the cutscenes are in (`docs/cutscenes-plan.md`) | TeeJ, 2026-09-25: "we'll need to figure that out". ⚠ Open question first: that popup is the only place in the game showing the Milky Way card picture's **CC BY 4.0** attribution (`pack.json` `menu.credits`), which the licence requires - it needs a new home before the popup goes. **Done 2026-09-26** (cutscenes plan, #255): View credits plays the original's credits movie (005) once the player imports the exporter 2.5.0 movies file, and opens the popup until then; the attribution's new home is **"Credits and licences"** on the pack's card in the picker (decision 6) |
| 44 | **Unread counts on a chip beside each Message Alert icon** instead of the small number on the icon's corner: a dark rounded chip, yellow rim, 16 px bold yellow digits, on the metal pillar next to the icon (right of it for the Alliance, left of it for the Empire, whose bar is on the right edge). The frame stays as it is | TeeJ, 2026-09-25: "let me think on the chip". Mock-up made on a real capture. The alternative - widening the frame's alert column - was estimated at half a day, with the column's angled top corner unlikely to stretch cleanly |
| 45 | **The droids moving.** The agent (C-3PO / IMP-22) "only moves when he is talking, otherwise he is still" - talking (the briefing, translated messages) is not built, so he stands still. The message droid (R2-D2 / SD-7): when it moves, and what its right-click menu's **Message Alerts** does (TEXTSTRA 12573; the manual never says; greyed for now). Their frames are in the art set (exporter 2.4.5: each droid's type-302 run); the original's SPT/BIN/FDT scripts, RCDATA, that say which frames play when are unread | TeeJ, 2026-09-25: "put R2 in the to do list". SD-7 was caught mid-animation on his screenshots, so it does move at times |
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
| 19 | `death_star_shield` / `death_star_sabotage` ids in engine | `src/game/bombardment_manager.gd:144`, `src/game/mission_table_manager.gd:18`, `src/game/mission_catalog.gd:39`, `src/data/snapshot_loader.gd:18` | **Done** — `superweapon_shield` facility role (branch `pack-ww2`); the mission half went with PR #49 `behaviour`. `snapshot_loader.gd` keeps its legacy family map for the source's fixture only |
| 20 | `SeedManager` still loads legacy defensive/military JSON through `Loaders`, family ids 34/35/36 → `ion_cannon` etc. | `src/game/seed_manager.gd:23-38` | **PR #48** — `Facility.Def` carries the stats |
| 21 | Military Data Editor reads `res://data/military_units.json` directly | `src/ui/military_data_editor.gd:37` | **Done** — editor removed with its data (TeeJ, 2026-09-22) |
| 22 | Legacy `data/` folder (15 JSON files) still shipped; `tests/dto_parity.gd` reads it | `data/`, `src/data/loaders.gd` | **Done** — folder, `Loaders` and eleven DTOs deleted; `dto_parity` compares the loaded pack with `tests/fixtures/dto-pack.json` |
| 23 | Rule-id constants carry setting names (`SeedCoruscantFirst`, `EspionageRevealCoruscantFloor`) | `src/game/rule_id.gd:93`, `src/game/mission_manager.gd:189` | **Done** — 32 constants renamed to their role, old name kept as a trailing comment (TeeJ, 2026-09-22) |
| 24 | **Modularity proof** — a second, deliberately alien pack runs on an unchanged binary | source repo `PROJECT.md` Phase 5 | **In progress, branch `pack-ww2`** — `packs/ww2` (WWII, Axis vs Allies) loads, seeds and soaks; `tests/pack_loads.gd` validates every pack. Charter and leak list: `packs/ww2/PACK.md` |
| 35 | Day-zero seeding resolved assets by the original's family numbers (`32 → headquarters`, `16 → Troop` …), so a second pack seeded nothing | `src/game/day_zero_generator.gd:388` (was) | **Done** on `pack-ww2` — `setup.json` rows name a `unit` / `facility` id; validation rule 13 |
| 36 | Defence look-ups by family name (`planetary_shield`, `turbolaser_battery`, `ion_cannon`); `CanDestroySystem` by family 24 | `assault_manager.gd:31`, `intel_manager.gd:246`, `intel_facts.gd:110`, `planet.gd:778`, `bombardment_manager.gd:43` (were) | **Done** on `pack-ww2` — roles `shield` / `anti_ship` / `disable` / `superweapon` |
| 37 | Remaining family-name reads, all display-side: the Defense Facility Status window's names and icons; `mine` / `refinery` / `shipyard` ids in `economy.gd:99`, `agent_droid.gd:78`, `intel_manager.gd:398` (same ids in both packs, so not a blocker) | (were) | **Done** (TeeJ, 2026-09-22): the window by roles and the family's tier-1 display name, `Terms` for the shield row and the Defenses tags; the economy rates and the droid's build orders by `extracts_raw` / `refines`; the intel queue words are the pack's producer names by `produces_*` |
| 25 | Day-zero character placement by display name: six to the first world, Mon Mothma to the HQ, Palpatine to the HQ, six Imperials to a random holding | `src/game/day_zero_generator.gd:186-217` | **PR #49** — `starts_at_*` roles |
| 26 | Story set-pieces keyed on names — the four Luke/Leia vs Vader/Emperor pairings, Han, Chewbacca | `src/game/story_manager.gd:7-27` | **PR #49** — `pilgrim` / `heir` / `dark_lord` / `dark_master` / `smuggler` / `companion` |
| 27 | Force pilgrimage and heir by name (Luke, Leia) | `src/game/force_manager.gd:8-9` | **PR #49** |
| 28 | Millennium Falcon effect keyed on "Han Solo" | `src/game/order_manager.gd:38` | **PR #49** — `smuggler` |
| 29 | Emperor excluded from special-power training by name | `src/game/mission_manager.gd:93` | **PR #49** — `dark_master` |
| 30 | Death Star: family 24 literal, `u.Name == "Death Star"`, `DeathStarAt` | `src/game/mission_manager.gd:53,175,512` | **PR #49** — `superweapon` |
| 31 | Garrison score term counts "Stormtrooper Regiment" by name | `src/game/mission_manager.gd:216` | **PR #49** — `garrison_troop` (engine and the AI mirror) |
| 32 | Engine joins its behaviours to the pack ids `death_star_sabotage` / `jedi_training` (and `dagobah` / `palace`, and the ten mission-table ids) | `src/game/mission_catalog.gd:39-40` | **PR #49** — `behaviour`; a mission's table shares its id |
| 33 | Snapshot import maps the C# snapshot's facility names (legacy format) | `src/data/snapshot_loader.gd:13-19` | **Kept** — `tests/fixtures/snapshot-seed12345.json` is still the bench/soak day-zero fixture; the map is the format boundary for that external file |
| 34 | Rule-id constants named for the setting (`SeedYavin*`, `SeedAllianceHq*`, `LukeVsVader*`, `DeathStarSabotage*`) | `src/game/rule_id.gd` | **Done** with #23 |
| 35 | Multiplayer Options win-condition tooltips are the manual's p162 text with Star Wars names (pinned verbatim by `tests/mp_screens.gd:134`) | `src/ui/mp/multiplayer_options.gd:11-12` | **Done** — `pack.json` `victory_tips` (TeeJ, 2026-09-22); the test still pins the manual's words for this pack |

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
