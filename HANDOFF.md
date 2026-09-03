# HANDOFF — Porting sol-conflict-revolution to GDScript

**Date:** 2026-09-02 (v2 — amended after review room AM-4A9S3YYV7KGYHBLPJNGC52XD8B)
**Author:** Lord Vader (chair). Reviewed by C3PO (sections 2, 4, 6-UI, autoload policy) and R2D2 (section 7 arithmetic). Approved by TeeJ.
**Status:** Steps 0, 0b, 1A, 1B, 2, 3, 4 complete (2026-09-03). **The port is the game (TeeJ, room #104, 2026-09-03):** rule changes land here only, logged in `docs/BACKPORT-LOG.md` for later application to the C#; the parity soak is now a self-regression test against the port's own fixtures (last C#-generated at source `6da9451`). Multiplayer over the web is in progress: `docs/multiplayer-plan.md`; **M0 done** (`docs/m0-audit.md`: serials, human sides, addressed messages, per-faction fog, canonical battle orientation, the multiplayer table pair; gate: both sides human, local side swapped, 201/201 identical). **M1 done**: every player order is a Command through the CommandBus, logged with the day hashes to user://last-session.jsonl (or --record=path); tests/replay.gd rebuilds a game from the log (gate: 100/100). **M2 done** (engine side): LockstepSession over a Transport - two processes over a mailbox hold identical day hashes for 200 days, a forced desync is detected and repaired from the shared log (`tools/lockstep-local.ps1`). **M3 Gate A passed**: the Bun relay (`relay/`, zero dependencies, rooms + append-only log + forwarding + `since` replay) with its 12-check test, `WebSocketTransport` and `RelayClient`; the lockstep gate through a local relay holds 200/200. **Gate B passed 2026-09-03**: the relay runs on Unraid as `ghcr.io/teejs/wars-relay` (built by `.github/workflows/relay-image.yml`, template `relay/unraid/my-wars-relay.xml`) behind NPM Plus at wars.schmitzplex.com; two headless clients through the live container hold 200/200 (`tools/lockstep-local.ps1 -RelayUrl ws://192.168.1.25:8787/ws`). Godot's TLS module does not initialise headless on the workstation (`tests/tls_probe.gd`), so wss is verified by curl and the browser, not the harness. **M5 engine side done**: a dropped client rejoins by name, pulls the relay's log, rebuilds to the last day both sides hashed and continues (`LockstepSession.rebuild_from_log`; gates `tools/lockstep-local.ps1 -Relay -Rejoin 30` and `-Load 30` (both drop, relay restarted): 171/171 each; the relay lists `saves` per player, test 16/16). **M4 batch 1 done** (2026-09-03, designs in `docs/multiplayer-ui-design.md`, reviewed by Doof): the Cockpit's Multiplayer panel, Multiplayer Configuration, Host Game, Locate Session, Join Game, Multiplayer Options with chat and the Load Game list, and the GameManager hook - a real head-to-head from the menu (`tools/mp-flow-local.ps1 -Days 20 -Load`: 19/19 and, loaded from the Options screen, 19/19). **M4 batch 2 done** (2026-09-03): the Chat Messages tab with double-click and the Compose Chat Message window, the game speed as the slower of the two settings, Waiting for Opponent (Game Options screen, Pause, or a drop; Leave Game after a minute), host-only Save Game. **M4 and M5 are complete.** The web build in build/web was re-exported with the screens and walked in the browser against a local relay (Cockpit, Configuration, Host Game, Multiplayer Options with the room code and the settings echo). **Live since 2026-09-03** at https://wars.schmitzplex.com/ (image `ghcr.io/teejs/wars-relay`, Unraid template, NPM Plus). TeeJ's additions the same day, both in the room's review: the **Game speed rule** (Slowest wins / Average, BACKPORT-LOG #14) and the **feedback box** ('Provide feedback' on the Cockpit; reports with the session log land in `/data/feedback/` on the box, BACKPORT-LOG #15). Join Game rebuilds its list only when the set of games changes and shows a status line (#c7cd108, #8b0a01f), and a typed code finds an unlisted game (relay `lookup`). **Two-browser play-through done by TeeJ 2026-09-03** (room #97): the game ran on both screens through wars.schmitzplex.com - M3 is fully closed. His feedback: orders feel slow in head-to-head because M2 applies them at the day boundary; the phase-lockstep (apply batches every 300 ms, tick the day on the host's marker) is built (BACKPORT-LOG #18; Doof's review #118/#121). Delivery stays one image (relay + game) for now; the pivot to a relay-only image with the game files in appdata is decision 9 in the plan. Left: single-player Save/Load (not in the port; design question E). Bun 1.4.0 is installed at `%USERPROFILE%\.bunin` (approved 2026-09-03). The M2/M4 UI pieces come from C3PO's designs. The game exports to Web, boots in a browser to the menu, starts a game and opens its windows with zero console errors; the full GDScript day costs 10.8 ms in the browser. Remaining: TeeJ's play-through (desktop and browser), the Partial/Missing manual items the checklists flag, and the source AI quirk noted under step 2. TeeJ's standing order: proceed independently and commit until the port is complete.

**v2 changes:** JSON size corrected; Random audit corrected (11 unseeded sites, not 1); construct audit expanded; plan gains steps 0, 0b, 1A, 1B; autoload policy adopted; estimate limited to steps 0–1B; CLAUDE.md carried over whole; work split recorded (§10).

---

## 1. Decision

Port **sol-conflict-revolution** (Godot 4.7.1 mono, C#/.NET 8) to **GDScript** in
**this repo** as a fresh, clean, non-Mono Godot 4.7 project.

| Question | Answer |
|---|---|
| Is the port feasible? | **Yes.** No hard .NET blockers found (see §4). |
| Is it necessary? | **Yes, for a web build.** Godot 4 C# has no web export (see §2). |
| Approach | Preserve subsystem boundaries, rules, and the 2-side day-tick model; replace static global ownership with the explicit session policy in §6. |
| What must be preserved | **Manual fidelity.** The source repo's CLAUDE.md is copied whole (§9). |

## 2. Why GDScript — the web-export constraint (Confirmed, re-verified by C3PO 2026-09-02)

The driver is a **browser-playable build**.

> "Projects written in C# using Godot 4 currently cannot be exported to the web."
> — Godot docs, *Exporting for Web*, version-pinned 4.7 page and latest, checked 2026-09-02

Root cause: the .NET WASM runtime must be the main module and cannot be
dynamically linked into Godot's WASM. A community fork
(`ComplexRobot/godot-dotnet-web-export`) patches it but lacks GDExtension support
and has globalization gaps — not a shipping foundation.

The only alternatives to GDScript are GDExtension C++ (far more work) or Godot 3.

Sources:
- https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html
- https://godotengine.org/article/platform-state-in-csharp-for-godot-4-2/
- https://github.com/godotengine/godot/issues/70796
- https://github.com/ComplexRobot/godot-dotnet-web-export

## 3. Source inventory — `D:\Github\sol-conflict-revolution` @ `11c1b36` (spot-checked v2)

Godot 4.7.1 mono, `net8.0`, **zero NuGet packages** beyond `Godot.NET.Sdk`.

### Size

| Area | Files | Lines |
|---|---:|---:|
| `backend/` — game logic, no Godot UI | 50 | 16,038 |
| `frontend/` — windows, galaxy map, GID bar | 30 | 9,134 |
| root — `GameManager.cs`, `Menu.cs` | 2 | 647 |
| `.tscn` scenes (16 frontend + 2 root) | 18 | — |
| `data/*.json` (from Python parsers of the original `.DAT` tables) | 15 files, 14 DTO types | **~473 KB** (v1 said 2.8 MB — wrong) |
| **Total C#** | **82** | **~25,800** |

### Largest files

| File | Lines |
|---|---:|
| `backend/Mission.cs` | 2,640 |
| `backend/Planet.cs` | 1,642 |
| `frontend/UIManager.cs` | 1,012 |
| `backend/TacticalBattle.cs` | 968 |
| `frontend/FleetWindow.cs` | 905 |
| `frontend/DraggableWindow.cs` | 884 |
| `frontend/EconomyWindow.cs` | 883 |
| `backend/DayZeroGenerator.cs` | 873 |
| `backend/AiManager.cs` | 693 |
| `backend/StoryManager.cs` | 659 |
| `backend/OrderManager.cs` | 607 |
| `backend/FleetBattleManager.cs` | 549 |

### Backend subsystems (all must be translated)

Mission (2,640), Planet (1,642), TacticalBattle (968), DayZeroGenerator (873),
AiManager (693), StoryManager (659), OrderManager (607), FleetBattleManager (549),
Character (452), RuleManager (420), BombardmentManager (406), ForceManager (380),
MilitaryCatalog (370), StrategicTickManager (353), IntelManager (347),
AssaultManager (285), BlockadeManager (279), AgentDroid (260), LoyaltyManager (251),
SeedManager (223), RepairManager (222), ShipDamage (212), ResearchManager (194),
VictoryManager (193), InformantManager (186), DebugKeys (180), CaptivityManager (149),
Economy (145), GameSignature (141), SmugglingManager (135), MissionCatalog (133),
MissionTableManager (124), FacilityCatalog (124), GalaxyFactory (120), Unit (115),
SideLotteryManager (106), GameMessage (98), EventBus (89), UprisingTable (85),
plus `backend/Packs/` (347).

### What one strategic day actually calls

`StrategicTickManager.cs:270-347` runs **sixteen** subsystems per day:
Planet.ProcessDailyTick, Economy, Loyalty, Force, Story, Captivity, Informant,
AgentDroid, Ai, FleetBattle, Blockade, Smuggling, Repair, Victory, Research, Mission.
Before the first day, `GameManager.cs:114-177` loads RuleManager, MissionTable,
MissionCatalog, UprisingTable, SeedManager, FacilityCatalog, GalaxyFactory and runs
DayZeroGenerator. **"Run one day" therefore means ~10k of the 16k backend lines** —
which is why step 1 is split in §6.

### Frontend windows (all must be translated, 18 scenes)

UIManager, FleetWindow, DraggableWindow, EconomyWindow, DefenseWindow, SectorWindow,
MessageWindow, MilitaryDataEditor, Gid, GalaxyMap, BattleResultsWindow,
BattleAlertWindow, GidKey, TacticalView, GalaxyOverviewWindow, MissionWindow,
FleetStatusWindow, PersonnelFinder, DefenseFacilityStatusWindow, GidBar,
ObjectivesWindow, PlanetFinder, CharacterStatusWindow, UnitStatusWindow,
PlanetWindow, TransitConfirmWindow, InGameMenuWindow, Buttons/ (3 files).

## 4. Construct audit — the translation tax

Grep counts over `backend/`, `frontend/`, root at `11c1b36`.

### 4a. Original audit (verified v2)

| Construct | Hits | Risk | GDScript equivalent |
|---|---:|---|---|
| LINQ (`Where/Select/OrderBy/GroupBy/Sum/Any/First/ToList/ToDictionary`) | 421 | **HIGH** (volume) | `filter`/`map`/`sort_custom`/`reduce` or explicit loops. |
| Generic collections (`Dictionary<>/List<>/HashSet<>`) | 352 | MODERATE | `Dictionary`/`Array`; typed arrays where possible. |
| `System.Text.Json` attributes/options | 43 | **HIGH** | Hand-written per-DTO hydration. |
| `JsonSerializer.Deserialize<T>` call sites | 15 (14 distinct DTO types) | **HIGH** | One hydration function per DTO type. |
| C# `event` / `Action<>` / `Func<>` | 49 + 18 | LOW | `signal` / `Callable`. |
| `record` / `struct` | 5 / 4 | LOW | Plain classes. |
| `GetNode<T>` | 128 | LOW | `$Path` / `get_node()`. |
| `[Export]` / `[Signal]` | 15 / 1 | LOW | `@export` / `signal`. |
| `FileAccess` | 22 | LOW | Same API. |
| `_Process` / `_PhysicsProcess` | 3 | LOW | Same. |
| **`Random`** | **11 constructions, ALL unseeded** (v1 said 1) | **HIGH** | See 4c. Determinism must be **created**, not kept. |
| `async` / `Task<>` | **0** | none | — |
| `DllImport` / P/Invoke | **0** | none | — |
| `System.Reflection` | **0** | none | — |
| `unsafe` / `Span<>` | **0** | none | — |
| `ThreadPool` / `Parallel` | **0** | none | — |

### 4b. Omitted from v1 (C3PO's audit — lexical hits, overlapping, not additive)

| Construct | Hits | Risk | Note |
|---|---:|---|---|
| **Nullable value declarations** (`int?`, nullable enums/Color, mostly DTO fields) | 66 | **HIGH** | Missing/null must stay distinct from 0/default in hydration — a rules-fidelity bug waiting to happen. Needs parity tests. |
| **Tuple-keyed dictionaries** (4) + tuple returns/lists/deconstruction | ≥8 | MODERATE | Godot 4.7 Arrays compare and hash by contents, but mutable Array keys can invalidate lookup assumptions. Prefer immutable composite-key strings or value types. |
| **Static classes** | 39 | **HIGH** (architectural) | Needs the ownership policy in §6 (three buckets) *before* translation. |
| Null-conditional `?.` / null-coalescing `??` / `??=` | 242 / 198 / 10 | MODERATE | Pervasive default behaviour to preserve. |
| `out` parameters (21 methods; 191 incl. `TryGetValue`/`TryParse`) | 191 | MODERATE | Result objects or split queries; watch error paths. |
| Type-pattern `is T x` | 117 | MODERATE | Explicit `is` + cast + temp. |
| Switch expressions / statements | 43 / 21 | MODERATE | Expression-valued switches need control-flow rewrites. |
| Interpolated strings | 816 | LOW (volume) | Mechanical; user-visible text. |
| `=>` tokens (lambdas, expression-bodied members, overlaps LINQ) | 1,065 | LOW (volume) | — |
| Target-typed `new()` | 99 | LOW | — |
| Interface `ITransitEntity` (Unit, Fleet; used in generic constraints) | 1 | LOW | Common contract / duck typing + tests. |
| Inheritance: Character→Unit; Planet/Fleet→Location; windows→DraggableWindow→PanelContainer | shallow | LOW | — |
| Range/index-from-end, local functions, `init`, `with` | 7 / 6 / 5 / 1 | LOW | — |

**Conclusion (unchanged): no hard blockers.** The cost is volume — roughly 3,000
more touch points than v1 counted — plus the determinism work in 4c.

### 4c. Random — the eleven sites

| Site | What |
|---|---|
| `backend/StrategicTickManager.cs:13` | `_rng = new()` — the main tick RNG, passed to ~40 `ProcessDay`/`Resolve`/`Roll` methods (the one site v1 counted) |
| `backend/DayZeroGenerator.cs:10` | `rng = new()` — galaxy generation, 27 call sites |
| `backend/LoyaltyManager.cs:92` | `static _rng = new()` |
| `backend/Planet.cs:1053` | `static _unrestRng = new()` |
| `backend/TacticalBattle.cs:845` | `static _shared = new()` |
| `backend/FleetBattleManager.cs:397` | `new Random()` per battle |
| `frontend/BattleAlertWindow.cs:144`, `FleetWindow.cs:562`, `FleetWindow.cs:696`, `UIManager.cs:866`, `GameManager.cs:303` | `new System.Random()` at UI call sites |

**The source is not deterministic today.** `System.Random` and Godot's
`RandomNumberGenerator` are different generators, so even a seeded port would not
reproduce the C# stream. Same-seed parity (risk 4, step 2 gate) requires a
hand-written portable PRNG (xorshift or PCG) on **both** sides — see step 0b.

### Translation rules learned in 1A (binding for steps 2–3)

| C# | GDScript | Why |
|---|---|---|
| member names | **the same PascalCase names** | 25k lines reference them; the parity dump compares by name. GDScript style is not the goal, fidelity is. |
| `string` null | `""` — and `s != null` becomes `not s.is_empty()` | GDScript `String` cannot be null. The source only ever tests strings with `IsNullOrWhiteSpace`, `??` or `!= null` (DayZeroGenerator.cs:257, :262), so `""` is safe. `tools/compare_json.py` treats C# null ≡ GD `""` for strings only. |
| `int?` | `Variant`, null preserved | risk 8; never coalesce in the hydrator. |
| `List<T>` with `= new()` / without | `[]` / `null` (`Variant`) | mirror the C# initialiser exactly. |
| a member named `Color` | `ColorHex` | GDScript cannot name a member after a builtin type; the source was renamed to match (`[JsonPropertyName("color")]` keeps the pack key). |
| `enum` | `Enums.X`, declaration order preserved | several are ordinal (MissionType joins MISSNSD by position). |
| `Faction` reference | `Faction` object from `FactionRegistry.ById` | identity by reference, as in C#. |
| JSON numbers | `int()` at every int site | `JSON.parse` yields float. |
| `--headless -s script.gd` on a fresh checkout | run `--import` first | `class_name` lookup needs `.godot/global_script_class_cache.cfg`. |

### DTO types deserialised (each needs a hydration function)

`List<Character>` (×2), `List<UnitStatRule>`, `List<SideRuleData>`, `List<SectorJsonData>`,
`List<PlanetJsonData>`, `List<MissionDef>`, `List<MilitaryUnit>`, `List<GameRuleData>`,
`List<FacilityStatRule>`, `List<DefenseStatRule>`, `IntTable`,
`Dictionary<string, MissionTableData>`, `Dictionary<string, LogisticsFile>`, generic `T`.

## 5. Risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| 1 | **GDScript is bytecode-interpreted, no JIT on any platform; on WASM that stacks on the engine's own WASM overhead.** The Planet/Mission tick is the hot loop. Cost is **unmeasured**. Rough prior: 10–50× slower than C# in tight loops. | **CRITICAL** | Step 1B measures it on a full-production day-zero snapshot over 100 days before any schedule is committed. |
| 2 | Web threads require SharedArrayBuffer + COOP/COEP headers. | LOW | Source uses 0 threads. Do not introduce any. |
| 3 | `user://` on web is IndexedDB, async-flushed. | LOW | Source has **no save/load system** (0 `user://` hits). Nothing to port; design for it later. |
| 4 | LINQ→loop translation errors silently change rules. | MODERATE | Headless same-seed C# vs GDScript comparison — **depends on step 0b**; impossible against the source as it stands (4c). |
| 5 | ~473 KB JSON + galaxy BMPs in the `.pck`. | LOW | Acceptable for web. |
| 6 | Browser audio/input autoplay policies. | LOW | UI only. |
| 7 | **No snapshot/serialiser exists in the source.** Step 1B needs C# to emit a canonical day-zero state (galaxy, planets, characters, fleets, missions). | MODERATE | New serialiser in the source repo as part of step 0b. Same approval path. |
| 8 | Hydration drops the null-vs-0 distinction on nullable DTO fields (4b). | MODERATE | Parity tests on every nullable field in step 1A. |

## 6. Next steps (in order — gates are hard)

| # | Step | Where | Gate |
|---|---|---|---|
| **0** | Copy `data/*.json`, `GAMEPLAY.md`, `manual/ILLUSTRATIONS.md` from the source into this repo. Each copied doc gets a first line `<!-- last synced from sol-conflict-revolution commit <sha> -->`. Copy the source `CLAUDE.md` whole and edit only *Repo facts* (§9). | this repo | Files present, sync lines present. |
| **0b** ✅ | **Done** — source commit `c5bded4` on `tschmitz-dev`. Gate passed: `tools/replay-check.ps1`, seed 12345, 100 days, identical snapshots and 101 identical day hashes, 7 s. Proof files in `tests/fixtures/`. **Make the source deterministic.** One seeded, portable PRNG (xorshift or PCG — the same algorithm the GDScript side will implement) routed through all 11 sites in 4c. Add a day-zero snapshot serialiser (JSON). Verify same-seed replay in C# alone: two runs, identical snapshot, identical 100-day log. | **source repo, `tschmitz-dev`** — needs TeeJ's separate go-ahead | Same-seed replay identical in C#. |
| **1A** ✅ | **Done.** `tools/dto-parity.ps1`: the source's `--dto-dump` (backend/DtoDump.cs, commit below) and `tests/dto_parity.gd` emit the same canonical form for all 18 datasets (14 DTO types + pack manifest/factions + the editor's MilitaryUnit + both uprising tables); `tools/compare_json.py` diffs them field by field. **Zero differences** over 200 planets, 213 rules, 57 units, 60 characters, 35 side-lottery rows, 25 missions, 20 tables, 11 logistics files. Hydrate all 14 DTOs from `data/*.json` in GDScript. Correctness gate: every field, including nullable-vs-0, matches what the C# side loads. | this repo | Field-level parity report, zero diffs. |
| **1B** ✅ | **Done. Browser numbers in (2026-09-03):** `Web-bench` export (tests/ included, `tests/bench_1b_scene.tscn` as main scene), Chromium WebGL2 via the desktop app's browser pane, Emscripten 4.0.20 single-threaded: **steady mean 10.8 ms/day** (p50 10.2, p95 16.2, max 22.0; warm-up 20.0) over 100 full days from the seed-12345 snapshot with every subsystem live and the opponent AI running. The fastest game speed is 1.3 s/day, so the tick uses under 1% of the budget - **GO**. (Wall-clock was slow only because the embedded pane throttles frames to about one every 2 s.) Desktop numbers below are the earlier stubbed run. `tests/bench_1b.gd` (headless) and `Main.tscn` (C3PO, frame-spread, for the browser) hydrate the snapshot and run `StrategicTickManager.AdvanceDay` with Planet, Economy, Mission, Research live and 13 subsystems stubbed (`src/game/stubs.gd`). **Hydration gate: the day-1 GameSignature text is character-for-character identical to the source's** (`tools/diff_replay_text.py`). Desktop, 150 planets, 60 characters, 100 days: steady mean **2.0 ms/day** (p95 5.0, max 5.6) idle; **3.0 ms/day** (p95 9.6, max 14.1) with six espionage missions running. The source's full C# day, all subsystems, is ~35 ms (7 s / 200 days). Days 2+ diverge from the source only where the stubbed AI acts — that is step 2's parity target. **Browser run pending** (needs the non-Mono editor + web templates). Hydrate the step-0b snapshot. Run `Planet.ProcessDailyTick` + `Mission.ProcessDay` for 100 days with the other 14 ProcessDay subsystems stubbed to no-ops. Record warm-up separately, then mean / p50 / p95 / max per-day time (and allocations if the profiler exposes them). **Export to Web** and repeat in a browser. | this repo | **Go / no-go on tick budget.** |
| **2** ✅ | **Done.** Every `backend/` subsystem is translated and live in `StrategicTickManager.AdvanceDay`; `src/game/stubs.gd` is gone. `tests/soak.gd` mirrors the source's `GameManager.RunSoak` (AI drives both sides, both droids on, pending battles run through `TacticalBattle` then `SimulateResults`) and compares every day hash against a C# `--replay-log`. **Gate passed from a fresh day zero, three seeds: 12345 × 100 days (101/101), 7 × 200 days (201/201), 2026 × 200 days (201/201)** — 503 of 503 hashes, with 25–88 fleet battles, assaults, blockades, uprisings and missions per run. Full GDScript day: **50–100 ms** on desktop (C# ~35 ms). 2026-09-03 rule fix (TeeJ's report, room #67-#72): a pre-placed RIM seat no longer costs its side a core starting slot, matching the original's seed routine; fixed in both repos, fixtures regenerated, 503/503 re-passed. Known issue in the SOURCE's AI, carried over faithfully (room #77, TeeJ: not now): a fleet beaten at a fogged world is re-ordered at the same world because it still 'sees' nobody defending - seed 12345 sends Empire Fleet_0001 (strength 0) at Phraetiss nine times in 100 days. Known gaps: the snapshot does not carry PRNG state or the opening intel, so `start_from_snapshot` re-seeds and is only a hydration check; fresh day zero is the parity path. Translate remaining `backend/`, subsystem by subsystem, largest-risk first. | this repo | Same-seed parity vs C# passes per subsystem. |
| **3** ✅ | **Done (translation).** All 18 scenes: the 16 `.tscn` copied byte-identical except the script path, every `frontend/*.cs` and `GameManager.cs`/`Menu.cs`/`DebugKeys.cs` translated to `src/ui/*.gd` with the C# names kept (`docs/ui-port-notes.md` records every rule and every backend name that differs). Gates: `tests/ui_compile.gd` 32 scripts / 0 failures; `tests/ui_smoke.gd` opens all 21 windows over the seed-12345 galaxy through a bare UIManager and again through `Main.tscn` (`--main --seed=12345`), runs the repaint poll, advances days and drives three real battles (Battle Alert, Battle Results, TacticalView) - zero script errors both ways. Each window's section of `docs/window-checklists.md` was re-checked line by line: every Present item is in the port; the 60 Partial/Missing items are carried over unchanged and remain flagged. Zero PORT GAPs (no backend member was missing). Foundation reviewed by C3PO (#64): pass, two parity nits fixed. **Not yet done:** a human play-through - the smoke test proves the windows build and repaint, not that they look or behave right on screen. Translate `frontend/` (18 scenes), window by window, **each checked against the manual passage that specifies it**. Owner: C3PO. | this repo | Manual-element checklist per window. |
| **4** ✅ | **Done (first export).** `export_presets.cfg`: preset `Web` (GL Compatibility, `variant/thread_support=false` so no COOP/COEP headers are needed, tests/tools/docs excluded) and `Web-bench`. `Godot_v4.7.1-stable_win64_console.exe --headless --path . --export-release Web build/web/index.html` produces a 39.5 MB wasm + 1.2 MB pck; served over plain HTTP it boots to the menu, starts an Alliance game, draws the map/GID/HUD, opens Sector and Planet windows - zero console errors. Toolchain: non-Mono editor at `D:\Downloads\godot-4.7.1-web\`, templates installed to `%APPDATA%\Godot\export_templates\4.7.1.stable`, both SHA-512 verified against the release. Web export of the full game; re-profile. | this repo | Playable in browser. |

### Static-class / autoload policy (adopted — C3PO)

Do **not** turn 39 static classes into 39 autoloads. Three buckets:

1. **Pure/stateless utilities and immutable constants** → `class_name` scripts with static funcs/consts; no autoload.
2. **Loaded catalogs and mutable per-game managers** → ordinary RefCounted/Resource/Node instances owned by one `GameSession` composition root. This includes Rule/Seed/Facility/Mission/MissionTable catalogs and runtime Economy/EventBus/FleetBattle/Intel/Loyalty/Informant/Repair/Research/Smuggling/Story/Victory/Mission/Force state. EventBus is a `GameSession` child signal hub so teardown starts a truly clean game.
3. **Autoloads** → at most an application-level SceneRouter/Bootstrap plus persistent user settings. `GameSession` may be an autoload only if scene changes require it, and must expose explicit `new_game`/`reset`/`dispose` and own every per-run dependency.

Gid display definitions may stay a static data script/Resource; `_activeMode` belongs to the instantiated GalaxyMap/Gid controller. GameSettings splits into persistent UserSettings vs per-run GameConfig. Class-by-class mapping is finalised while building 1A/1B.

### Other practices

- Headless, deterministic test runner driven by a fixed seed.
- Signal-based tick orchestration.
- Strict JSON error handling and index-building at load.
- Keep the Python parsers upstream in the source repo; **JSON is the contract**.

## 7. Effort

v1's 17–25 days works out to 1,033–1,519 translated lines per day (R2D2) and was
sized on 421 LINQ hits and 14 DTOs only. It excludes the ~3,000 extra touch points
in 4b, the determinism refactor and serialiser in 0b, and the 18 manual-element
checklists in step 3. **It is withdrawn.**

Size only what can be sized now; re-size the rest after 1B's numbers exist.

| Step | Estimate |
|---|---|
| 0 | hours |
| 0b (source repo) | ~~2–3 days~~ done in one session |
| 1A | 2–3 days |
| 1B | ~~3–4 days~~ built in one session; browser measurement pending |
| 2, 3, 4 | **not sized until 1B passes** |

## 8. Unresolved

- Actual GDScript/WASM tick cost — settled by 1B.
- **1B found two bugs in the source's `Snapshot.cs`** (both fixed, commits `8202768`, `48eadb7`): planets under a sector were written as bare names, and dictionary properties (`Planet.Support`) came out null. The 0b replay hash was unaffected (it goes through GameSignature), so the determinism proof stands; the snapshot fixture was regenerated.
- The web export needs **Godot 4.7.1 non-Mono** plus its **export templates** — not downloaded as of 2026-09-03; a download needs TeeJ's explicit yes.
- ~~Portable PRNG choice~~ **Decided (Wicket's research + mask fix): canonical xorshift64\* on signed 64-bit, the logical shift reproduced as `(x >> 7) & 0x01FFFFFFFFFFFFFF`.** C# reference: source `backend/Prng.cs`. GDScript must match `tests/fixtures/prng-12345.txt` (first 1,000 raw outputs from seed 12345) byte for byte.
- 0b found two nondeterminism sources beyond the eleven Random sites: a null-rng Dagobah roll, and fleet names built from a Guid. Both fixed at the source. Fleet serials are now per-game counters.
- Hosting/headers for the web build (only matters if threads are ever added).

## 9. CLAUDE.md carry-over

v1 listed six rules. The source has rules 0, 1, 1a, 2, 3, 4, 5, 6, 7, 8 plus
*Repo facts*; the six dropped rule 5 (report confidence), 6 (never kill the running
game), 7 (build the whole feature incl. UI, with the GAMEPLAY.md / ILLUSTRATIONS.md
pointers step 3 depends on), 8 (be brief), rule 1's source table, and reduced
rule 0 to one line despite calling it verbatim.

**Copy the source `CLAUDE.md` whole.** Edit only *Repo facts*:

| Line | Change |
|---|---|
| Engine | Godot 4.7 **non-Mono**, same binary path minus `mono`. Launch via a `run-game` skill for this repo. |
| Remotes | this repo's own; the source repo rules about `upstream` do not apply here. |
| Not in the repo | `.DAT` files are not here at all; `data/*.json` **is** here (copied, §6 step 0). `manual/pages/` remains only in the source repo. |
| Docs | `GAMEPLAY.md` and `manual/ILLUSTRATIONS.md` are copies — check the sync line before trusting them; re-sync from the source when it moves. |

## 10. Work split (TeeJ, 2026-09-02)

| Agent | Share | Scope |
|---|---|---|
| Lord Vader | remainder | backend translation, data layer, step 0b, amendments to this document, sync lines and checklist status table |
| C3PO | ~25% while tokens last | all UI: step 3 windows vs manual passages, manual-element checklists, autoload mapping; reviewed §8, the two-pass lottery, and the 1B harness (`Main.tscn`) |
| Doof | as available | review of Lord Vader's plans and output (three `f32` fixes in `tactical_battle.gd` were Doof's); step 3 windows when C3PO is out of tokens |
| Wicket | retired 2026-09-02 | replaced by Doof at TeeJ's instruction |

C3PO and Doof review Lord Vader's output. C3PO ran out of tokens on 2026-09-03; Doof is the reviewer from then on when present. R2D2 was removed from the project on 2026-09-02.
