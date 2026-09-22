# World War II faction pack — charter and state

Branch `pack-ww2`. Started 2026-09-22. This is BACKLOG #24, the Phase 5
modularity proof: **a second, deliberately alien pack on an unchanged binary.**

## Charter (signed off by TeeJ, 2026-09-22)

| | |
|---|---|
| **Must do** | The pack loads and plays by flipping `packs/active.json` only. |
| **Wrong if shipped without it** | Any Star Wars name, family number or engine edit needed to make it run. |
| **Off-limits** | `if pack == "ww2"` anywhere in `src/`. Star Wars family ids kept in WWII data as a shim. |
| **Target / backup** | Branch `pack-ww2` off `origin/main`, PR to `main`. Git is the backup. |
| **Done when** | `tests/pack_loads.gd` passes on both packs; a fresh day-zero soak runs N days on this pack; the Star Wars soak gate is unchanged. |

## Decisions forced by the schema

| Constraint | Consequence |
|---|---|
| 2–4 factions; the side lottery is N×N | **Two factions, `axis` and `allies`.** Nations are flavour: unit names, `buildable_by`, character nationality, map regions. |
| `Enums.GalaxySize` has three members indexing `setup.galaxy_sizes` | Three sizes, named `standard` / `large` / `huge` like the original. Every starting world is in `standard`. |
| Stat keys (`shield`, `hull`, `hyperdrive`, …) are read by name in `military_catalog.gd` | Kept as-is: the keys are engine vocabulary. **The words are this pack's** — `display.json` `terms` (SCHEMA.md section 10, 2026-09-22): Armour, Hull, Cruising Speed (between regions) / Flank Speed (in a battle), Industry, War Materiel, Air Squadrons, Divisions, fortifications, coastal batteries, "at sea". |
| Every mission table id is read by the engine (`escape`, `foil`, `uprising_start`, …) | Tables are copied under their ids; only `death_star_sabotage` is renamed, to match the mission it belongs to. |

## How the numbers were made

**Nothing numeric is invented.** Every unit and facility names a Star Wars
`template` (kept as a field); its costs, stats and weapon loadout are copied
from that row with the weapon classes renamed. Rules, the side lottery and the
20 mission outcome tables are copied and re-keyed `empire → axis`,
`alliance → allies`. Character ratings are authored (the only hand-written
numbers) and every character has special-power probability 0.

| Star Wars | WWII |
|---|---|
| Ion Cannon / Turbolaser / Laser / Torpedo | Torpedoes / Main Guns / Light Guns / Bombs and Aerial Torpedoes |
| Ion Cannon / Turbolaser Battery / Planetary Shield / Death Star Shield (facilities) | Minefield / Coastal Battery / Fortifications / Hardened Airbase |
| Death Star (`superweapon`) | Atomic Bomber Wing, Allies |
| Stormtrooper Regiment (`garrison_troop`) | Waffen-SS Division |
| Story roles (pilgrim, heir, dark lord, …) | **Uncast.** Those set-pieces never fire. |
| `jedi_training`, `dagobah`, `palace`, the four unnamed missions, vacation / sabbatical / pickup / bounty | **Omitted.** Behaviours the pack does not offer, or rows the engine has no code for. |

Generator: the pack was produced by a one-off Python script from the Star Wars
pack; it is not in the repo because the JSON is the contract and the pack is
now hand-editable.

## Phase A — data (this commit)

`tests/pack_loads.gd` walks every folder under `packs/` and validates it.
Both pass. A 30-day fresh day-zero soak (`--faction=allies --size=Large`)
completes on this pack with the AI driving both sides.

**What the soak also showed:** day zero placed the headquarters and every
character, but **no ships, troops or facilities** — "0 Fleets containing 0
Capital Ships". That is the leak below, and it is why this pack exists.

## Phase B — the engine leak (done, same branch)

`setup.json` in this pack references seeding targets **by pack id**
(`{"unit": "bismarck_class_battleship"}`, `{"facility": "refinery"}`), per
SCHEMA.md §12 Q1 — ids, never numbers. The engine used to resolve them by the
original binary's family numbers. Fixed:

| Was | Now |
|---|---|
| `match asset.FamilyId: 32 → "headquarters", …, 16 → Troop, 20 → CapitalShip, …` in `DeployAsset` | `FacilityCatalog.ById` / `MilitaryCatalog.ById`; a facility row places tier 1 of its family; a `null` child is the empty carrier slot |
| `LogisticsAsset` reads `FamilyId` / `AssetId` | reads `unit` / `facility` |
| `CountOf("planetary_shield")` in the assault gate | `CountByRole("shield")` |
| Intel sighting and intel facts by family name | roles `shield` / `anti_ship` / `disable`, family looked up in the catalog |
| Delivery message category by family name | by role |
| `f.Family() == "death_star_shield"` in bombardment | role `superweapon_shield` (new in the facility role set) |
| `s.FamilyId == 24` for "the Death Star in your fleet" | unit role `superweapon` |
| The mines-first seeding rule placed `"mine"` by id | `FirstWithRole("extracts_raw")` |

The Star Wars pack's `setup.json` was migrated the same way (48 rows), and
validation rule 13 refuses a row that resolves to nothing, or one still
carrying `FamilyId`. Four negative cases in `tests/pack_validation.gd`.

**Verified:** both packs validate; the WWII 30-day soak now opens with
9 fleets, 14 capital ships and 14 refineries; the Star Wars soak gate is
byte-identical (four soaks, `tools\soak-gate.ps1`).

**No facility is named by family in engine code any more** (BACKLOG #37, closed
2026-09-22): the Defense Facility Status window, the economy rates, the agent
droid's build orders and the intel queue words all select by role.

**Out of scope here:** the source repo's `.DAT` extractor for the logistics
tables still emits `FamilyId` / `AssetId`; it must be re-keyed the same way
before the next regeneration (SCHEMA.md §8's standing warning), and that is a
source-repo change on `tschmitz-dev` with its own go-ahead.

## Phase C — content (done, branch `pack-ww2-content`)

| Item | What shipped |
|---|---|
| **Map layout** | **Real geography on the 1941 map** (since 2026-09-22; the Phase C board is gone). Each region sits where the map puts it, via a mapping fitted on 90 cities read off the map (cubic in lon/lat, 18 px RMS). The Central Pacific is unwrapped onto the map's right copy so that theatre does not span the whole width. **Europe is dense** (30 regions in ~200×250 px of a 1750-wide picture) and that is fine for the Sector window, which spreads a theatre's regions to fill it. On the main map the fix was engine-side, not a picture inset (tried, dropped): the theatre click-box padding went from 30 to 8 px, and every region dot carries an invisible button that opens its theatre, so a theatre under another's box is still one click away. |
| **Backdrop** | `world_1941.jpg`, a public-domain 1941 atlas page (publicdomainpictures.net image 510694) cropped to its neat line, 1750×1050; `map.json` coordinates are its pixels (SCHEMA.md §4). The map view draws it behind the regions, fitted into the frame; the right ~12% sits under the message panel, which also hides the Central Pacific regions. |
| **Starting forces** | One garrison table per starting nation (`germany_start_garrison` … `france_start_garrison`, Yavin-sized to HQ-sized, the original's `fixed_range`), nation-flavoured: Panzer and Wehrmacht divisions with Bf 109s at Germany, Zeros and the Special Naval Landing Force at Japan, Spitfires and Royal Marines at Britain, Guards and Il-2s in Russia… The seeded **fleet** is placed at the HQ *and* every starting world (engine behaviour), so it carries only faction-generic hulls and naval infantry. |
| **Roster** | 77 units (+22): Italian and Japanese squadrons and divisions, Hurricane, Wildcat, Hellcat, Avenger, Yak-9, Il-2, P-40, D.520, US and Soviet and French divisions. Every one still copies a Star Wars template's numbers. |
| **Characters** | 71 (+27): Model, Rundstedt, Student, Galland, Ozawa, Marshall, King, Harris, Tedder, Rokossovsky, Chuikov, Spruance, Wingate, Chennault, Zhu De, Menzies… |

**Verified:** both packs validate; a 60-day soak as the Axis on the huge map completes with 10 fleets and 15 capital ships at day zero.

### Left open — needs a decision, not more content

| Item | Why it is not just pack data |
|---|---|
| **Stat wording** ("Shield", "Hyperdrive", "Sublight", "Energy", "Raw Materials", "Turbolaser"…) | **103 UI sites** across `fleet_status_window.gd`, `unit_status_window.gd`, `planet_window.gd`, `game_manager.gd` hard-code the Star Wars words. Fixing it means a pack **terms table** (`display.json` `terms: {"shield": "Armour", "hyperdrive": "Cruising Speed", "energy": "Industry", …}`) read through one helper, the same pattern as `special_power_ranks`. That is a schema field plus an engine sweep — TeeJ's call. |
| **Cockpit-style `menu` picture** | Optional per SCHEMA.md §2; the button menu is used. Needs artwork. |
| **`artwork_id`** | Not read by the engine today; the field is filled sequentially. |
