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
| Stat keys (`shield`, `hull`, `hyperdrive`, …) are read by name in `military_catalog.gd` | Kept as-is. Display wording for them is a Phase C item. |
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

## Phase B — the engine leak (next, needs its own go-ahead)

`setup.json` in this pack references seeding targets **by pack id**
(`{"unit": "bismarck_class_battleship"}`, `{"facility": "refinery"}`), per
SCHEMA.md §12 Q1 — ids, never numbers. The engine still resolves them by the
original binary's family numbers:

| Leak | Where |
|---|---|
| `match asset.FamilyId: 32 → "headquarters", 34 → "ion_cannon", …, 16 → Troop, 20 → CapitalShip, 28 → Fighter, 60 → SpecForce` | `src/game/day_zero_generator.gd:388-417` |
| `LogisticsAsset` reads `FamilyId` / `AssetId` only | `src/data/dto/catalog_dtos.gd:68` |
| `MilitaryCatalog.BySource(Vector2i(family, id))` | `src/game/military_catalog.gd:39` |
| Facility ids `planetary_shield`, `turbolaser_battery`, `ion_cannon` selected by name | `src/game/intel_facts.gd:110`, `src/game/intel_manager.gd:246`, `src/game/assault_manager.gd:31` |
| `death_star_shield` family by name | `src/game/bombardment_manager.gd:144` (BACKLOG #19) |
| Legacy snapshot family map | `src/data/snapshot_loader.gd:14` |

Fix direction: an asset names a `unit` or `facility` id; `DeployAsset` looks the
unit up in `MilitaryCatalog` by id and the facility by id, and the four
defence look-ups select on roles (`shield`, `anti_ship`, `disable`,
`superweapon_shield`). Proven the same way as every Phase 5 change: the Star
Wars soak gate byte-identical.

## Phase C — content

Real orders of battle, a real world map with coordinates (`world.png` is a
placeholder grid; positions are lon/lat projected into the Star Wars
coordinate range), artwork, display wording for shields / hyperdrive / energy,
an optional Cockpit-style `menu` picture.
