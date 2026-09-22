<!-- reconciled from sol-conflict-revolution commit 167e2ad (SCHEMA.md, 2026-07-25) -->

# Faction Pack Schema v1 — DRAFT (awaiting sign-off)

The contract between the engine and a faction pack. Everything that describes
*content* lives here; everything that describes *how the simulation runs* lives
in engine code. See the source repo's `PROJECT.md` for why.

> **This is the reconciled copy.** The original was drafted 2026-07-25 against
> the C# repo, before any migration ran, and several of its claims no longer
> match the data folder. Every correction is listed in §13. The source repo's
> copy is now **behind this one** and needs TeeJ's separate go-ahead to update.

**Status:** Phases 1 and 2 are **done** (`pack.json`, `factions.json`, the
faction-keyed re-key of `game_rules.json` / `side_lottery.json` / `BuildableBy`).
Sections marked **`[later]`** are reserved — a pack may declare them and a v1
engine ignores them.

---

## 1. Conventions

- **ids** are `lower_snake_case`, unique within their file. Every cross-reference
  must resolve; the loader rejects dangling refs (§11).
- **Names are never behaviour.** Engine code selects on **role tags**, never on
  an id or display name. "is this an ion_cannon" is forbidden; "does this
  facility have the disable role" is correct.
- Colors are `#rrggbb`. Percentages are 0–100 integers. Costs are integers.
- **Durations are in ticks. 1 tick = 1 in-game day.**
- **N factions (2–4).** Nothing in a pack or the engine may assume two sides.
  Anything that was a two-sided pair becomes a map keyed by faction id.
- Unknown fields are ignored (forward-compatible). Missing required fields are a
  load error.
- A pack is a folder under `packs/<pack_id>/`. The Star Wars content currently in
  `data/` becomes `packs/star-wars-rebellion/`.

### Files in a pack

Fifteen JSON files and one bitmap live in `data/` today. Every one of them is
accounted for below — that is what this reconciliation was for.

| File | Purpose | Current source | Built? |
|---|---|---|---|
| `pack.json` | Manifest + setup defaults | *(new)* | ✅ |
| `factions.json` | The sides: identity, color, HQ config, asymmetry flags | *(new)* | ✅ |
| `map.json` | Sectors and planets: position, ring, artwork | `sectors_data.json` (20) + `planets_data.json` (200) | ✅ |
| *(the map bitmap)* | The galaxy backdrop the map is drawn on — a **`pack.json` field**, `map_image`, not a file of its own (§2) | now `packs/star-wars-rebellion/galaxyShaded.bmp` | ✅ |
| `facilities.json` | Static structures + **role tags** | `production_facilities.json` (9) + `defensive_facilities.json` (6) + the `FacilityType` enum | ✅ |
| `units.json` | Mobile units and their stats | `military_units.json` (57) | ✅ |
| `weapons.json` | Weapon classes + **role tags** | `military_units.json` weapon columns + the four-class vocabulary in `tactical_battle.gd` | ✅ |
| `characters.json` | Named characters | `major_characters.json` (6) + `minor_characters.json` (54) | ✅ |
| `rules.json` | Tunable rule table, keyed by faction + difficulty | `game_rules.json` (213) | ⚠ re-keyed, not moved |
| `setup.json` | Day-zero seeding: side lottery + logistics tables | `side_lottery.json` (35) + `day_zero_logistics.json` (11 tables) | ⚠ re-keyed, not moved |
| `missions.json` | The mission catalog | `missions.json` (25) | ❌ |
| `mission_tables.json` | Per-mission outcome tables | `mission_tables.json` (12 tables) | ❌ |
| `display.json` | The Galactic Information Display catalog | `src/ui/gid.gd` (currently code) | ❌ |
| `uprising.json` | Uprising thresholds `[later]` | `uprising_start.json`, `uprising_end.json` | ❌ |

**Not pack content:** `gnprtb_globals.json` (212 rows of
`{global, parameter_id, entry_id, name}`) is a map from rule entries to the
original binary's memory addresses — a reverse-engineering artifact belonging
with the extraction tooling, not shipped in a pack.

---

## 2. `pack.json` — manifest

**Built.** Matches `packs/star-wars-rebellion/pack.json`.

```json
{
  "id": "star-wars-rebellion",
  "display_name": "Star Wars: Rebellion",
  "schema_version": 1,
  "faction_count": 2,
  "neutral": { "id": "neutral", "display_name": "Neutral", "color": "#5499ff" },
  "unexplored_color": "#cccccc",
  "map_image": "galaxyShaded.bmp",
  "setup": {
    "difficulty_default": "medium",
    "galaxy_sizes": ["standard", "large", "huge"]
  }
}
```

| Field | Notes |
|---|---|
| `schema_version` | This doc is **1**. The loader refuses anything newer. |
| `faction_count` | Must equal the entries in `factions.json`; 2–4. |
| `neutral` | The uncontrolled side. Pack data, not a hardcoded singleton, because its name and color are setting-specific. **Not** playable, not counted in `faction_count`. |
| `unexplored_color` | Color for systems the viewing faction has no knowledge of. A display convention, not a rule. |
| `map_image` | **★ DECIDED (TeeJ, 2026-09-21).** The galaxy backdrop, as a filename relative to the pack folder. Required; a pack that declares none is a **load error**, not a blank screen. Named here rather than fixed by convention so the engine never assumes a filename. |
| `setup.galaxy_sizes` | The size names offered on the menu. **Which sectors each size includes is declared per sector** in `map.json` (`min_size`), not here — see §4. |

---

## 3. `factions.json` — the sides

**Built,** and it carries three field groups the original draft did not specify:
`starting_planets` is a list of objects (not ids), plus `seed` and `victory`.

```json
{
  "factions": [
    {
      "id": "alliance",
      "display_name": "Rebel Alliance",
      "color": "#ff0000",
      "loyalty_label": "Loyalty to the Alliance",
      "hq": { "kind": "hidden", "placement": "random_rim", "movable": true },
      "occupation_support_policy": "occupation_penalty",
      "starting_planets": [
        { "planet": "Yavin", "support": 100, "explored": true,
          "garrison": "CMUNYVTB.DAT" }
      ],
      "seed": {
        "hq_facilities": "FACLHQTB.DAT",
        "hq_garrison": "CMUNHQTB.DAT",
        "fleet": "CMUNAFTB.DAT",
        "procedural_fleet": "CMUNALTB.DAT"
      },
      "victory": { "capture_characters": ["Emperor Palpatine", "Darth Vader"] }
    }
  ]
}
```

| Field | Notes |
|---|---|
| `color` | Drives the map marker, the sector window and the GID legend. One source of truth; the engine holds no faction color constants. |
| `hq.kind` | `fixed` — a known capital, captured when taken. `hidden` — placed at `placement` (a planet name or the `random_rim` sentinel), unknown to other factions until located, optionally `movable`, destroyed rather than captured. |
| `occupation_support_policy` | `garrison_bonus` (troops raise support over time) or `occupation_penalty` (first occupation lowers it). Asymmetry as a flag. |
| `loyalty_label` | Display string for the GID loyalty mode. |
| `starting_planets[]` | `{planet, support, explored, garrison}`. `planet` holds a **display name** today; **becomes a planet id** (§12 Q1, decided). |
| `seed` | Which day-zero logistics table seeds this side's HQ, garrison and fleets. Values are **original `.DAT` filenames** today; **become role ids** (§12 Q2, decided). |
| `victory.capture_characters` | Characters this side must hold captive to win. **Display names** today; **become character ids** (§12 Q1, decided). |

---

## 4. `map.json` — sectors and planets

Merges `sectors_data.json` (20 sectors) and `planets_data.json` (200 planets).
Ids replace the numeric `SectorId`/`PlanetId`; the numeric ids may remain as
`source_id` for traceability.

```json
{
  "sectors": [
    { "id": "abrion", "display_name": "Abrion", "ring": 2,
      "starts_neutral": false, "map": { "x": 469, "y": 642 },
      "min_size": "huge", "intel_tier": "presence" }
  ],
  "planets": [
    { "id": "abregado", "display_name": "Abregado", "sector": "abrion",
      "starts_inhabited": false, "map": { "x": 479, "y": 726 },
      "artwork_id": 12 }
  ]
}
```

| Field | Notes |
|---|---|
| `ring` | 1 = Core, >1 = Rim. Drives day-zero seeding and default knowledge. From `GalaxyRing`. |
| `min_size` | The **smallest galaxy size this sector appears in** — one of `pack.json`'s `setup.galaxy_sizes`. Sizes are cumulative: a `standard` sector is in all three. See below. |
| `artwork_id` | The planet's portrait. Present in the real data as `ArtworkId`; absent from the original draft. Pack content — a different setting ships different art. |
| `intel_tier` | `live` — control and support always current (Core). `presence` — updates only with a fleet or mission present (Rim). **`[later]`**; v1 may treat all sectors as `live`. |

**⚠ Correction — there is no per-planet `base_resources`.** The original draft
specified one. Energy and raw-material slots are **rolled at day zero** from
rule entries 180, 182 and 189–197
([day_zero_generator.gd:431](src/game/day_zero_generator.gd:431)), and clamped
to hard maxima. They are generated, not authored. A pack tunes them through
`rules.json`, not through `map.json`.

This also closes the original §10 Q1 (an open resource vocabulary implying a
`resources.json`): the two resources are *rule-driven quantities*, so declaring
a third means adding rule entries **and** an engine consumer, not just a pack
file. Re-open only if that is actually wanted.

### Galaxy size is currently a hardcoded sector list in engine code

**⚠ Absent from the original draft.** Which sectors a `standard` / `large` /
`huge` galaxy contains is not data at all — it is twenty literal sector names
in [galaxy_factory.gd:14-25](src/game/galaxy_factory.gd:14):

```gdscript
var sectors := { "Corellian": true, "Sesswenna": true, "Sluis": true, ... }
if size == Enums.GalaxySize.Large or size == Enums.GalaxySize.Huge:
    for n in ["Farfin", "Glythe", "Jospro", "Kanchen", "Quelli"]:
```

`pack.json` declares the size *names*; the engine holds the *membership*. That
is setting content in code, and it is `map.json`'s job.

The counts reconcile exactly with `sectors_data.json`:

| Size | Sectors added | Running total |
|---|---|---|
| `standard` | 10 | 10 |
| `large` | +5 | 15 |
| `huge` | +5 | **20** = every row in `sectors_data.json` |

**Representation: `min_size` on each sector**, rather than a list of sector ids
per size in `pack.json`. Sizes are strictly cumulative in the original, so one
field per sector expresses it without duplicating ids in two files where they
could drift. If a setting ever wants non-nested sizes — a size that *omits* a
sector a smaller one includes — this is the field that has to change.

A sector excluded by the chosen size takes its planets with it; the loader
already drops planets whose sector was filtered out
([galaxy_factory.gd:40](src/game/galaxy_factory.gd:40)).

### `map_image`

**★ DECIDED (TeeJ, 2026-09-21) — named in `pack.json`.** `data/galaxyShaded.bmp`
is the backdrop the galaxy map draws over; the original draft had nowhere to put
it. The manifest names it (§2) rather than the engine assuming a path, and a
pack that omits it fails to load.

---

## 5. `facilities.json` — structures, selected by role

Replaces the `FacilityType` enum ([enums.gd:17](src/game/enums.gd:17)), whose
members `IonCannon`, `TurbolaserBattery`, `DeathStarShield` and `PlanetaryShield`
are setting vocabulary in engine code.

**⚠ Correction — there are two source files, not one.** The original draft named
only `defensive_facilities.json`. The real set is 15 facilities:

| Source | Rows | Extra columns beyond the common set |
|---|---|---|
| `production_facilities.json` | 9 | `ProcessingRate` |
| `defensive_facilities.json` | 6 | `WeaponRating`, `ShieldStrength` |

Common to both: `Id`, `FamilyId`, `Name`, `Tier`, `BuildableBy`,
`ConstructionCost`, `MaintenanceCost`, `ResearchOrder`, `ResearchCost`,
`BombardmentDefense`. The two differ only in their stat columns, which is
exactly what an open `stats` map absorbs.

```json
{
  "facilities": [
    { "id": "ion_cannon", "display_name": "Ion Cannon", "tier": 1,
      "family": 34,
      "roles": ["planet_defense", "disable"],
      "buildable_by": ["empire", "alliance"],
      "construction_cost": 4, "maintenance_cost": 4,
      "research_order": 2, "research_cost": 120,
      "stats": { "weapon_rating": 2000, "shield_strength": 0,
                 "bombardment_defense": 0 } },

    { "id": "mine", "display_name": "Mine", "tier": 1,
      "roles": ["extracts_raw"], "buildable_by": ["empire", "alliance"],
      "construction_cost": 2, "maintenance_cost": 1,
      "stats": { "processing_rate": 1 } }
  ]
}
```

| Field | Notes |
|---|---|
| `roles` | The engine's selection vocabulary. v1 role set: `headquarters`, `extracts_raw`, `refines`, `produces_unit`, `produces_troop`, `produces_facility`, `planet_defense`, `shield`, `disable`, `anti_ship`. The loader rejects unknown roles so a typo cannot silently create an inert facility. |
| `buildable_by` | A list of faction ids; absent means all. **Already migrated** in the real data. |
| `stats` | Open map. The engine has no built-in stat vocabulary; consumers read named stats declared by the pack. Absorbs the production/defensive column split. |

---

## 6. `units.json` — mobile units

From `military_units.json`, 57 rows, 44 columns.

```json
{
  "units": [
    { "id": "mon_calamari_cruiser", "display_name": "Mon Calamari Cruiser",
      "family": "capital_ship", "roles": ["capital_ship"],
      "buildable_by": ["alliance"],
      "construction_cost": 92, "maintenance_cost": 70,
      "stats": { "shield": 300, "hull": 2400, "turbolaser": 360,
                 "ion_cannon": 200, "sublight": 4, "hyperdrive": 60,
                 "fighter_capacity": 3, "troop_capacity": 1 } }
  ]
}
```

- `buildable_by` **is already a list of faction ids** in the real data
  (`"BuildableBy": ["alliance"]`). Phase 2 landed this; the original draft still
  described it as pending.
- **Stats that do not apply are omitted, not `null`.** The current file writes
  `null` for inapplicable stats, which is what crashed `SeedManager` after the
  `json_gui` merge. An open `stats` map makes absence the natural encoding.
- **Rows do not share a key set.** Only the five torpedo-carrying fighters have
  `Torpedoes` / `TorpedoRange` at all; capital ships omit them entirely. Any
  tooling that infers the schema from the first row will miss columns — the
  omission is not `null`, it is absence, which is the encoding §6 asks for.

### Weapons are a Phase 3 vocabulary item

The weapon columns carry **two independent axes**, and only one of them is a
schema question.

| Axis | Values | Verdict |
|---|---|---|
| **Location** — firing arc | Fore, Aft, Starboard, Port | **Engine behaviour.** [`ArcTo()`](src/game/tactical_battle.gd:188) picks the arc from relative bearing; that is simulation. The engine already folds the flat columns into 4-element arrays at [military_catalog.gd:112](src/game/military_catalog.gd:112), so the flat layout is a *file* shape, not a runtime one. |
| **Name** — weapon class | Turbolaser, Ion Cannon, Laser, Torpedo | **Setting vocabulary in engine code.** The same problem as `FacilityType`, and it belongs to the same Phase 3 job. |

#### What the four classes actually do

Measured, not designed — every row below is a citation, not a proposal:

| Class | Arcs | Vs capitals | Vs fighters | Extra condition |
|---|---|---|---|---|
| Ion Cannon | 4 | counts | **excluded entirely** | — |
| Turbolaser | 4 | counts | counts × accuracy | — |
| Laser | 4 | counts | counts × accuracy | — |
| Torpedo | none | counts | **excluded** | firing unit is a squadron **and** target's shields are down |

Sources: [tactical_battle.gd:213](src/game/tactical_battle.gd:213) (ion excluded
against fighters), [429-450](src/game/tactical_battle.gd:429) (the accuracy
multiplier applied to turbolaser and laser but not ion),
[453](src/game/tactical_battle.gd:453) (the torpedo condition),
[568](src/game/tactical_battle.gd:568), and
[fleet_battle_manager.gd:90](src/game/fleet_battle_manager.gd:90) for the
strategic mirror of the same rule.

**Turbolaser and laser are not distinguished anywhere.** They are summed
together and treated identically at every site. The only thing separating them
in the engine is their range values (turbolaser 35–75, laser 17–25).

So the engine's real vocabulary is not four named weapons. It is: *does this
weapon affect fighters, is it accuracy-scaled when it does, does it require the
target's shields to be down* — plus a range. Role-shaped, exactly like
facilities.

#### Proposed `weapons.json`

```json
{
  "weapons": [
    { "id": "ion_cannon", "display_name": "Ion Cannon",
      "roles": ["no_fighter_effect"], "arcs": true, "range": 35 },
    { "id": "turbolaser", "display_name": "Turbolaser",
      "roles": ["fighter_accuracy_scaled"], "arcs": true, "range": 60 },
    { "id": "torpedo", "display_name": "Proton Torpedo",
      "roles": ["no_fighter_effect", "requires_shields_down", "squadron_only"],
      "arcs": false, "range": 7 }
  ]
}
```

A unit's `stats` then keys by weapon id rather than by a fixed column name, and
the engine stops containing the word "turbolaser".

#### Why this is Phase 3 and not a `units.json` detail

Phase 3 is *"open the vocabulary"* — replacing closed engine enums with
pack-declared defs carrying role tags. `FacilityType` is the named example;
weapons are the same job on the same schedule, and doing them separately means
touching the tactical engine twice. **Blocked behind the same decision**, and
verified the same way: a pack declares a weapon class the Star Wars pack does
not have, with no recompile.

#### Still open under this item

- **The redundancy.** Port and Starboard are identical in all 57 rows, and each
  summary column is exactly the sum of its four arcs. A pack could store
  `fore` / `aft` / `broadside` and let the engine mirror, dropping the summaries
  as derived — but that is behaviour-visible if any consumer reads a summary
  directly, and those consumers have not been enumerated.
- **The role names above are descriptions of observed behaviour**, not a
  ratified vocabulary. They need the same sign-off the facility role set gets.

---

## 7. `characters.json` — the roster

**The original draft's §10 Q2 said characters "were not examined in detail."
This is that pass.**

60 characters (6 major, 54 minor), identical 29-column schema in both files. The
split is by importance, not by structure, so one pack file with an `is_major`
flag is enough.

```json
{
  "characters": [
    { "id": "mon_mothma", "display_name": "Mon Mothma", "faction": "alliance",
      "is_major": true,
      "ratings": {
        "diplomacy":        { "base": 90, "var": 10 },
        "espionage":        { "base": 20, "var": 10 },
        "combat":           { "base": 10, "var": 10 },
        "leadership":       { "base": 90, "var": 10 },
        "loyalty":          { "base": 100, "var": 0 },
        "ship_research":    { "base": 0, "var": 0 },
        "troop_research":   { "base": 0, "var": 0 },
        "facility_research":{ "base": 0, "var": 0 }
      },
      "can_command": ["admiral", "commander", "general"],
      "wont_betray": true,
      "special_power": { "probability": 0, "is_known_user": false,
                         "level": { "base": 0, "var": 0 },
                         "can_train": false }
    }
  ]
}
```

*(Values above are shape illustration, not transcribed from the table.)*

| Change from the raw data | Why |
|---|---|
| `Faction` `"Alliance"` → `"alliance"` | The raw files use **title case** while the pack uses lower case. `FactionRegistry.ById` folds case to paper over exactly this ([faction_registry.gd:69](src/game/faction_registry.gd:69)). Re-keying removes the need for the fold. |
| 8 `XxxBase`/`XxxVar` column pairs → a `ratings` map | The pairs are uniform; a map removes named engine fields. |
| `CanBeAdmiral`/`CanBeCommander`/`CanBeGeneral` → `can_command` list | Three booleans are a closed vocabulary. |
| `JediProbability`, `IsKnownJedi`, `JediLevelBase/Var`, `CanTrainJedi` → `special_power` | **These are IP vocabulary in the data schema**, mirrored in engine code as `Character.JediLevel`, `IsKnownJedi`, `CanTrainJedi` and `Enums.ForceRanking.JediMaster` ([character.gd:43-151](src/game/character.gd:43)). The charter forbids it. Renamed to **special powers** — §12 Q5, decided. |

### Special powers — the engine-side rename (§12 Q5)

A hidden aptitude, probabilistically present, trainable, with ranked bands that
gate abilities. Generic mechanic, IP name. The rename:

| Today | Becomes |
|---|---|
| `Character.JediLevel` | `SpecialPowerLevel` |
| `Character.JediLevelBase` / `JediLevelVar` | `SpecialPowerLevelBase` / `SpecialPowerLevelVar` |
| `Character.IsKnownJedi` | `IsKnownSpecialPowerUser` |
| `Character.CanTrainJedi` | `CanTrainSpecialPower` |
| `Character.JediProbability` | `SpecialPowerProbability` |
| `Enums.ForceRanking` | `Enums.SpecialPowerRank` |
| `ForceRanking.JediMaster` | `SpecialPowerRank.SpecialPowerMaster` |
| `RuleId.FastHealForceRankThresh` | `FastHealSpecialPowerThresh` |

**The five band labels stay pack strings.** The engine holds ranked bands and
their thresholds (10 / 20 / 80 / 100 / 120 —
[character.gd:144-151](src/game/character.gd:144)); what they are *called*
("Jedi Master") is `display.json` content.

**LANDED 2026-09-21**, with two boundaries held deliberately:
> `Enums.MissionType.JediTraining` and its rule-id constants are the **mission**
> vocabulary and move with `missions.json`, not here. The enum MEMBERS
> `JediStudent` / `JediKnight` / `JediMaster` are **rendered straight to the
> player** by `JsonUtil.enum_name`, so they cannot move until `display.json` can
> hold their labels — renaming them now would put "SpecialPowerMaster" in the
> Character Status window. `MissionManager.Pretty()` is where those labels live
> today and is the natural hook.

> **One open detail.** TeeJ named `SpecialPowerLevel`,
> `IsKnownSpecialPowerUser` and `SpecialPowerMaster`. Inside an enum already
> called `SpecialPowerRank`, the prefix on the band members is redundant —
> `SpecialPowerRank.Master` reads better than
> `SpecialPowerRank.SpecialPowerMaster`, and the lower two bands (`Novice`,
> `Trainee`) are unprefixed already. Written above in TeeJ's literal form;
> say if the shorter member names are preferred.

**This is a code rename, not a data move** — it touches `character.gd`,
`captivity_manager.gd`, `rule_id.gd` and the character tables together, and
needs its own go-ahead before it lands.

---

## 8. `rules.json` and `setup.json` — the faction-keyed migration

**⚠ The original draft described this as pending. It is done.** Both files are
already nested maps keyed by faction id, and the extractors that generate them
(`parse_rules.py`, `parse_side_lottery.py`, `parse_military.py` in the source
repo) were updated in the same change.

Real shape of `game_rules.json`, 213 rows:

```json
{ "EntryId": 1,
  "Name": "Space Travel Time: Base (%, lower=faster)",
  "ParameterId": 1,
  "Development": 100,
  "Multiplayer": 100,
  "by_faction": {
    "alliance": { "easy": 100, "medium": 100, "hard": 100 },
    "empire":   { "easy": 100, "medium": 100, "hard": 100 }
  } }
```

Two differences from the original draft's example:

- Rows are addressed by the integer `EntryId`, not a `lower_snake_case` id. The
  names this codebase reads are constants in
  [rule_id.gd](src/game/rule_id.gd), which maps a readable name to the number.
  Whether the table itself should be name-keyed is **§12 Q6.**
- `Development` and `Multiplayer` are top-level columns, not entries inside
  `by_faction`. `Multiplayer` is the shared column a head-to-head game reads;
  `Development` is the fallback for structural entries
  ([rule_manager.gd:61](src/game/rule_manager.gd:61)).

`side_lottery.json` (35 rows) is an **N×N matrix** —
`by_faction[side][difficulty][side]` — plus flat `dev` and `mp` maps. Today 2×2.
A third faction makes every one of the 35 entries a 3×3, and the original
`SDPRTB.DAT` has no values to supply them; they would have to be authored.

**⚠ Correction — `core_infrastructure.json` and `rim_infrastructure.json` do not
exist.** The original draft named them as `setup.json`'s sources. Neither file
is in either repo. `setup.json`'s real sources are `side_lottery.json` and
`day_zero_logistics.json`.

> **The `data/*.py` extractors must be updated in the same change** as any
> further re-keying. They regenerate these files from the original game data;
> re-keying the JSON without re-keying the extractors means the next
> regeneration silently reverts it. This is risk #3 in `PROJECT.md`.

---

## 9. `missions.json` and `mission_tables.json`

**Entirely absent from the original draft**, which stated missions were "not
modelled in the engine yet." They are: `mission_manager.gd`,
`mission_catalog.gd`, `mission_table_manager.gd` and `Enums.MissionType`.

### `missions.json` — 25 rows

**⚠ It carries the exact pattern the charter forbids:** columns named
`"Alliance": 1` and `"Empire": 1` — per-faction availability flags with the
faction in the column name. The charter calls this out by name: *"`AllianceCanBuild`
/ `EmpireCanBuild` columns are as much a hardcoding as an `if`."* This is the
last un-migrated instance.

```json
{ "missions": [
    { "id": "diplomacy", "display_name": "Diplomacy",
      "available_to": ["alliance", "empire"],
      "spec_forces": ["bothan_spies", "infiltrators"],
      "length": { "base": 14, "spread": 7 },
      "flags": { "can_continue": true, "scripted": false,
                 "return_on_abort": true, "target_known_required": false,
                 "abort_on_blockade": true, "can_escape": true,
                 "can_kill": false },
      "targets": { "friendly": false, "neutral": true, "hostile": false } }
  ] }
```

*(Values above are shape illustration, not transcribed from the table.)*

- `available_to` replaces the `Alliance` / `Empire` integer pair.
- `spec_forces` is a list of **display names** in the raw data
  (`"Bothan Spies"`); it **becomes a list of unit ids** (§12 Q1, decided).
- `Enums.MissionType` ([enums.gd:35](src/game/enums.gd:35)) contains
  `JediTraining` and `DeathStarSabotage`. Like `FacilityType`, it is a closed
  setting vocabulary in engine code and this file must replace it.
- Seven `UnknownN` columns remain undecoded. They stay as-is; a pack author
  never sets them.

### `mission_tables.json` — 12 tables

Outcome tables, keyed by original `.DAT` filename (`ABDCMSTB.DAT`,
`ASSNMSTB.DAT`, …), each `{field1, entries_count, info, entries, description}`.
**Keys become role ids with `source_file` kept alongside** (§12 Q2, decided) —
but five of the twelve have no obvious mission counterpart and must be read
before they are named.

---

## 10. `display.json` — the Galactic Information Display

Currently a code table in [gid.gd](src/ui/gid.gd). The closest thing in the
codebase to pack-ready; moving it is mechanical.

```json
{
  "categories": [
    { "id": "resources", "display_name": "Resources",
      "modes": [
        { "id": "mines", "label": "Mines", "title": "Mines",
          "quantity": { "kind": "facility_count", "facility": "mine" },
          "tiers": [
            { "min": 6, "label": "6+ Mines",  "flare": "big" },
            { "min": 3, "label": "3-5 Mines", "flare": "mid" },
            { "min": 1, "label": "1-2 Mines", "flare": "low" },
            { "min": 0, "label": "No Mines",  "flare": "none" }
          ] } ] } ]
}
```

| Field | Notes |
|---|---|
| `quantity.kind` | How the engine computes the magnitude. v1 set: `facility_count`, `facility_role_count`, `unit_count`, `fleet_count`, `character_count`, `base_resource`, `support`, `constant_zero`. `constant_zero` lets a pack declare a mode whose backing system does not exist yet, without a code branch. |
| `tiers` | Ordered descending by `min`; the last entry (`min: 0`) is the bare-dot tier. Thresholds are **absolute**, never normalised to the map maximum. |
| `flare` | `big` / `mid` / `low` / `none`. Marker *sizes* are engine presentation constants; which tier gets which size is pack data. |

Faction colors and the legend come from `factions.json` + `pack.json`, so the
GID legend stops being hardcoded rows.

---

## 11. Validation

The loader reports **every** error before play, not the first. Implemented in
[pack_loader.gd](src/data/pack_loader.gd); each live rule has a negative test in
`tests/pack_validation.gd` that proves it rejects, not merely that the real pack
passes.

1. ✅ `pack.json.id` equals the folder name; `schema_version` ≤ engine-supported.
2. ✅ `faction_count` equals the entries in `factions.json`, and is 2–4.
3. ⚠ **Map cross-references live** — every planet resolves to a declared sector,
   ids are unique. Facilities, units, characters and missions await their files.
4. ⚠ **Facility `roles` checked** against the v1 set. `display.quantity.kind`
   awaits `display.json`.
5. ⚠ **Character `faction` and `can_command` checked.** `buildable_by` /
   `available_to` await the facility, unit and mission files.
6. ✅ Each faction's `hq` is internally consistent: a `fixed` HQ names a planet;
   a `hidden` HQ declares a `placement`.
7. ✅ Every `starting_planets` entry exists, and a `fixed` HQ names a real planet.
8. ❌ Display tiers are ordered descending and terminate with a `min: 0` tier.
9. ✅ `map_image` is declared and names a file present in the pack folder.
10. ✅ Every sector's `min_size` is one of `setup.galaxy_sizes`, and the smallest
    declared size has at least one sector — otherwise that menu option yields an
    empty galaxy.

---

## 12. Open questions for sign-off

The original draft's four questions, revised against the real data. Its Q1
(resource vocabulary) is **closed** by §4; its Q2 (characters) is **answered**
by §7; its Q4 (missions and victory "not modelled yet") is **obsolete** — both
systems exist. Its Q3 (pack location) is **settled**: `packs/<id>/` alongside
`data/`, which is what shipped.

**None remain open.** All six were settled 2026-09-21 and are kept here, struck
through, so the numbering stays stable for cross-references. Q4 was not answered
but *refiled* — it is a Phase 3 vocabulary item now, tracked in §6.

1. ~~**Cross-reference by display name.**~~ **★ DECIDED (TeeJ, 2026-09-21) — ids.**
   Every cross-reference between pack files uses a `lower_snake_case` id, never
   a display name. No exception is carved out.

   Affected today: `factions.json` `starting_planets[].planet` and
   `victory.capture_characters`; `missions.json` `spec_forces`. All three
   currently hold display names and are resolved by **exact string equality**
   ([day_zero_generator.gd:180](src/game/day_zero_generator.gd:180),
   [victory_manager.gd:50](src/game/victory_manager.gd:50)), so a rename or a
   typo silently yields `null` rather than an error — the failure this decision
   removes.

   `display_name` stays alongside as the human label and may change freely.

   **Sequencing:** the rename cannot land before `map.json` and
   `characters.json` exist — there is nothing to hold the ids yet — so it is
   part of that migration, and validation rule §11.3 goes live with it.

2. ~~**`.DAT` filenames as pack keys.**~~ **★ DECIDED (TeeJ, 2026-09-21) —
   rename to roles.** Table keys become `lower_snake_case` ids naming what the
   table *does*, not which file it came from. `factions.json.seed` then
   references those ids.

   **Traceability is kept as a field, not a key:** each table carries
   `"source_file": "CMUNYVTB.DAT"`, so the link back to the extraction survives
   without the filename being load-bearing.

   ```json
   "hq_facilities": { "source_file": "FACLHQTB.DAT", "entries": [ ... ] }
   ```

   **One pass is still needed to name them.** The 11 logistics tables map
   cleanly onto roles that `factions.json.seed` already uses
   (`hq_facilities`, `hq_garrison`, `fleet`, `procedural_fleet`) plus the two
   system-infrastructure tables (core / rim). The 12 mission tables are **not
   all 1:1 with a mission** — `ESCAPETB`, `FOILTB`, `INFORMTB`, `FDECOYTB` and
   `CSCRHTTB` have no obvious mission counterpart and must be read before they
   are named. Do not guess them.

3. ~~**The map bitmap.**~~ **★ DECIDED (TeeJ, 2026-09-21) — named in `pack.json`.**
   `map_image` is a required manifest field holding a filename relative to the
   pack folder. A pack that declares none is a load error. Specified in §2;
   validation rule §11.9 added.

4. ~~**Weapon arcs.**~~ **★ SPLIT AND REFILED (TeeJ, 2026-09-21).** The question
   conflated two axes. **Locations (arcs) are engine behaviour** — settled, not
   a schema question. **Weapon class names are setting vocabulary** and are now
   a **Phase 3 vocabulary item** alongside `FacilityType`, written up in §6.
   The redundancy sub-question travels with it. Original wording kept below.

   `units.json` carries 12 per-arc columns
   (fore/aft/port/starboard × turbolaser/ion/laser), 3 summary columns and 3
   range columns. Three facts measured across all 57 units:

   - **Every per-arc column is used** — all 12 are non-zero somewhere.
   - **Port and Starboard are identical in every single row.** The data models
     one "broadside" value, stored twice.
   - **Each summary column is exactly the sum of its four arcs**, in every row,
     with no exceptions. `Turbolaser`, `IonCannon` and `LaserRating` are
     derived, not independent.
   - Fighters use only the Fore arc, and their turbolaser and all three range
     columns are `null`.

   The tactical engine *does* read arcs — `Enums.ShipArc` and `ArcTo()` at
   [tactical_battle.gd:191-225](src/game/tactical_battle.gd:191) — so the four-arc
   model is engine behaviour, not a data convention.

   **Open:** whether to keep the redundancy. The pack could store `fore`, `aft`,
   `broadside` (3 values, no duplication) and let the engine mirror broadside to
   both beams, and drop the summary columns as derived. That is a cleaner file
   but a behaviour-visible change if any consumer reads the summary directly.

5. ~~**Renaming the Force.**~~ **★ DECIDED (TeeJ, 2026-09-21) — "special
   powers".** `SpecialPowerLevel`, `IsKnownSpecialPowerUser`,
   `CanTrainSpecialPower`, `SpecialPowerProbability`, `Enums.SpecialPowerRank`.
   Full mapping and the one open naming detail are in §7.

6. ~~**Name-keyed rule rows.**~~ **★ DECIDED (TeeJ, 2026-09-21) — keep integer
   keys.** `game_rules.json` rows stay addressed by integer `EntryId`.

   Engine code already reads rules by name through
   [rule_id.gd](src/game/rule_id.gd), which maps a readable constant to the
   number, so a slug would buy raw-JSON readability only — for a file that is
   generated, not hand-edited. The cost lands in `parse_rules.py` plus a
   re-export of all 213 rows, and the extractors are risk #3 in the charter.
   Not worth it.

   **This is the one place a number legitimately survives into pack data.**
   `rule_id.gd` remains the required way to reference a rule from engine code —
   its own header says a bare number next to one of those constants is the bug
   the class exists to prevent.

---

## 13. Reconciliation log

What changed from the source repo's 2026-07-25 draft, and why.

| # | Change | Cause |
|---|---|---|
| 1 | Status: "nothing is migrated" → Phases 1–2 done | The port shipped them; the charter was never updated |
| 2 | File table: added `missions.json`, `mission_tables.json`, `map_image`; noted `gnprtb_globals.json` as non-pack | Five `data/` files were covered by no pack file |
| 3 | File table: `facilities.json` source gains `production_facilities.json` | Draft named only the defensive file; there are two, 9 + 6 |
| 4 | Removed `core_infrastructure.json` / `rim_infrastructure.json` as `setup.json` sources | **Neither file exists** in either repo |
| 5 | §4: removed per-planet `base_resources`; added `artwork_id` | Resources are rolled at day zero from rules, not authored. `ArtworkId` is real data the draft missed |
| 6 | §4: added the `map_image` subsection | The galaxy bitmap had no home |
| 7 | §3: documented `starting_planets` as objects, plus `seed` and `victory` | The shipped `factions.json` is richer than the draft |
| 8 | §6, §8: marked `buildable_by` and the faction-keyed rule tables **done** | Phase 2 landed; the draft still described them as pending |
| 9 | §7: written from scratch | The draft's Q2 admitted characters were never examined |
| 10 | §8: corrected the rule row example to the real `EntryId`/`Name`/`Development`/`Multiplayer` shape | The draft's `lower_snake_case` id example does not match the file |
| 11 | §9: written from scratch | The draft said missions were "not modelled in the engine yet". They are |
| 12 | §11: marked which validation rules are implemented | The draft listed eight; three are live |
| 13 | §12: two questions closed, one answered, one obsolete; six questions now stand | Q4 assumed missions and victory did not exist |
| 14 | §12 Q1 **decided — ids, no exception** (TeeJ, 2026-09-21); §3 and §9 updated to match | Five open questions remain |
| 15 | §4: galaxy-size **sector membership** documented as a `map.json` field (`min_size`) | It is 20 literal sector names in `galaxy_factory.gd` — pack content living in engine code, missed by the draft |
| 16 | §12 Q3 **decided — `map_image` in `pack.json`** (TeeJ, 2026-09-21); §2 and §4 specify it, validation rules 9–10 added | Four open questions remain |
| 17 | §12 Q2 **decided — rename `.DAT` keys to roles** (TeeJ, 2026-09-21), `source_file` kept alongside for traceability; §3 and §9 updated | Five of the twelve mission tables still need reading before they can be named |
| 18 | §12 Q5 **decided — "special powers"** (TeeJ, 2026-09-21); §7 gains the full field mapping | One naming detail left: whether enum members keep the redundant prefix |
| 19 | §12 Q4: measured the real weapon data across all 57 units | Port == Starboard in every row; every summary column is exactly the sum of its arcs. The question is now about redundancy, not vocabulary |
| 20 | §12 Q6 **decided — keep integer `EntryId` keys** (TeeJ, 2026-09-21) | The one place a number legitimately survives into pack data; `rule_id.gd` stays the required reference path |
| 21 | §12 Q4 **split and refiled** (TeeJ, 2026-09-21): arcs are engine behaviour; weapon class names become a **Phase 3 vocabulary item**, written up in §6 with a proposed `weapons.json` | The question conflated location with name. Only the name half is a schema question, and it is the same job as `FacilityType` |
| 22 | §6: **four** weapon classes recorded, not three — `Torpedoes`/`TorpedoRange` exist on five fighters only | The earlier column dump read row 0, a capital ship, so the torpedo columns were invisible. `military_units.json` rows do not share a key set |
| 23 | **§4 built.** `map.json` generated, loaded and live; the bitmap moved into the pack; validation rules 3 (map half), 7, 9, 10 implemented and negative-tested | The hardcoded sector list is gone from `galaxy_factory.gd`. Soak gate 1004/1004 |
| 24 | **§7 built.** `characters.json` generated, loaded and live: one file, `is_major` flag, lower-case faction ids, `ratings` map, `can_command` list, `special_power` block. Validation rules 3 and 5 for the roster | The two-file major/minor split is gone. Soak gate 1004/1004 |
| 25 | **§12 Q5 landed.** The character aptitude fields and `Enums.SpecialPowerRank` renamed across 11 files | Enum MEMBERS and `MissionType.JediTraining` deliberately held back — see §7 |
| 28 | **§6 live.** `MilitaryCatalog` and the tactical engine read the pack; the four weapon names are gone from engine code. **No re-baseline** — byte-identical | Weapon DECLARATION ORDER in `weapons.json` is now load-bearing: the damage sum rounds to f32 per weapon |
| 27 | **§6 data built.** `units.json` (57) and `weapons.json` (4 classes) generated, loaded and validated; nothing reads them yet. The three derived summary columns are DROPPED, and the generator re-proves on every build that each is exactly the sum of its arcs | The tactical engine still reads the flat unit fields. Swapping it is the next step |
| 26 | **§5 built and live.** `Enums.FacilityType` is **deleted**; facilities are pack data selected by role. 154 call sites across 24 files. The game signature now carries the family id, so the soak gate is re-baselined | Proven behaviour-identical first by emitting the old ordinals: 1004/1004. Five silent bugs found on the way — see the commit |
