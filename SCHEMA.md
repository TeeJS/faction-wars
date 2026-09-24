<!-- reconciled from sol-conflict-revolution commit 167e2ad (SCHEMA.md, 2026-07-25) -->

# Faction Pack Schema v1

The contract between the engine and a faction pack. Everything that describes
*content* lives here; everything that describes *how the simulation runs* lives
in engine code.

> **This is the only live copy.** First drafted 2026-07-25 in the old C# repo,
> reconciled here against the real data and implemented here; every correction
> is listed in §13. The old repo's copy is history and is never synced.

**Status:** every file below is **built, loaded, validated and live**. Sections
marked **`[later]`** are reserved — a pack may declare them and a v1 engine
ignores them. The examples are excerpts of the shipped Star Wars pack
(`packs/star-wars-rebellion/`); open its files for the full picture.

---

## Making your own pack

Rebellion has a long modding history; a faction pack is how this game carries
it on. Most packs start **from the original**, for the player's own use:

1. **Copy a shipped pack.** The pack editor (`TeeJS/faction-wars-editor`)
   does it with *Make my own copy*; by hand, copy `packs/star-wars-rebellion/`
   to a folder named after your new id and set that id in `pack.json` (rule 1:
   the folder name **is** the id). A copy keeps the original's rules, units,
   characters and missions exactly, and plays identically.
2. **Keep `art_sets: ["swr-original"]`.** The pictures then come from the
   player's **own** art set, exported from their copy of the game (§14). A pack
   never carries the original's pictures or text: the editor's export and the
   game's import both refuse one that does. Your own pictures go in the pack's
   `art/` folder and win over the art set's.
3. **Change what you like** - the rest of this document is every field. A key
   starting with `_` (`"_comment"`) is yours: it is never read as data, anywhere.
4. **Load it.** Export the pack as a `.zip` (the editor's *Export*) and drag it
   onto the game's first screen. The import checks it with the same validator the game
   uses (§11) and refuses it, with the reasons, if the game could not load it.
   A pack with the same id as a shipped one is never used - give yours its own.

No engine rule selects on a pack's id, so a renamed copy behaves the same.
What a pack can **not** do is add a new kind of mechanic: every behaviour it
names (a facility role, a mission `behaviour`, a GID `quantity.kind`) is one
the engine implements. The loader refuses an unknown one rather than ignore it.

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
- Unknown fields are ignored (forward-compatible).
- **A missing file is a load error; a missing field is one only where §11 checks
  it.** Everywhere else an absent field takes its default (0, empty, `false`) -
  so a typo in an optional field's name is silently the default. The pack
  editor warns about fields it does not know.
- **A key starting with `_` is a comment**, in any object and any keyed map
  (`JsonUtil.data_keys`): `"_comment"`, `"_note"`, `"_monitors_comment"`. The
  shipped packs use them.
- A pack is a folder: `packs/<id>/` (shipped with the game) or `user://packs/<id>/`
  (imported). The folder name is the pack's id. A shipped pack wins over an
  imported one with the same id.

### Files in a pack

Twelve JSON files, all required. The "Current source" column is provenance:
the original data files each was first built from (they are gone; the pack
files are hand-edited now and are the contract).

| File | Purpose | Current source | Built? |
|---|---|---|---|
| `pack.json` | Manifest + setup defaults | *(new)* | ✅ |
| `factions.json` | The sides: identity, color, HQ config, asymmetry flags | *(new)* | ✅ |
| `map.json` | Sectors and planets: position, ring, artwork | `sectors_data.json` (20) + `planets_data.json` (200) | ✅ |
| *(the map picture)* | The galaxy backdrop the map is drawn on — a **`pack.json` field**, `map_image`, not a file of its own (§2): a picture in the pack, or one from an art set | the Star Wars pack: `swr-original:screens/galaxy.png`, the player's own | ✅ |
| `facilities.json` | Static structures + **role tags** | `production_facilities.json` (9) + `defensive_facilities.json` (6) + the `FacilityType` enum | ✅ |
| `units.json` | Mobile units and their stats | `military_units.json` (57) | ✅ |
| `weapons.json` | Weapon classes + **role tags** | `military_units.json` weapon columns + the four-class vocabulary in `tactical_battle.gd` | ✅ |
| `characters.json` | Named characters | `major_characters.json` (6) + `minor_characters.json` (54) | ✅ |
| `rules.json` | Tunable rule table, keyed by faction + difficulty | `game_rules.json` (213) | ✅ |
| `setup.json` | Day-zero seeding: side lottery + logistics tables | `side_lottery.json` (35) + `day_zero_logistics.json` (11 tables) | ✅ |
| `missions.json` | The mission catalog | `missions.json` (25) | ✅ |
| `mission_tables.json` | Per-mission outcome tables | `mission_tables.json` (**20** tables) | ✅ |
| `display.json` | The Galactic Information Display catalog, the Alt+1..9 order, and the special-power band labels | `src/ui/gid.gd` (was code) | ✅ |
| *(no `uprising.json`)* | `uprising_start.json` / `uprising_end.json` were **byte-identical copies** of two tables the pack already carries in `mission_tables.json` (`uprising_start`, `uprising_end`). `UprisingTable` reads those | `mission_tables.json` | ✅ |

**Not pack content:** `gnprtb_globals.json` (212 rows of
`{global, parameter_id, entry_id, name}`) is a map from rule entries to the
original binary's memory addresses — a reverse-engineering artifact belonging
with the extraction tooling, not shipped in a pack.

---

## 2. `pack.json` — manifest

An excerpt of `packs/star-wars-rebellion/pack.json` (regions, monitors and the
credits shortened; the tips abridged).

```json
{
  "id": "star-wars-rebellion",
  "display_name": "Star Wars: Rebellion",
  "summary": "The Galactic Civil War: the Rebel Alliance's hidden headquarters against the Empire's Coruscant, ...",
  "schema_version": 1,
  "faction_count": 2,
  "neutral": { "id": "neutral", "display_name": "Neutral", "color": "#5499ff" },
  "unexplored_color": "#cccccc",
  "art_sets": ["swr-original"],
  "map_image": "swr-original:screens/galaxy.png",
  "map_image_rect": [-5, 110, 1070.6666, 803],
  "setup": {
    "difficulty_default": "easy",
    "galaxy_sizes": ["standard", "large", "huge"],
    "galaxy_size_default": "standard"
  },
  "victory_tips": {
    "_comment": "The Multiplayer Options tooltips, manual p162, verbatim.",
    "standard": "Rebel Win Conditions: Capture Coruscant and ...",
    "hq_only": "Rebel Win Conditions: Capture Coruscant. ..."
  },
  "menu": {
    "image": "swr-original:screens/cockpit.png",
    "selected_color": "#ffd23c",
    "readout": { "rect": [270.2, 374.2, 108.4, 15.1], "standard": "Standard Game",
                 "hq_only": "Headquarters Only Victory", "color": "#40ff40" },
    "regions": [
      { "action": "difficulty", "value": "easy", "rect": [58.7, 36.4, 53.3, 48.9],
        "tooltip": "Set game difficulty to easy.", "selected_color": "#ff3030" },
      { "action": "start", "value": "empire", "rect": [147.6, 302.2, 75.6, 66.7],
        "tooltip": "Start the game as the Empire." }
    ],
    "monitor_fps": 10,
    "monitors": [
      { "image": "swr-original:menu/easy.png", "at": [61, 40], "frames": 30 }
    ],
    "credits": ["..."]
  }
}
```

Rects are in the menu picture's own pixels - the original's cockpit is
640×480.

| Field | Notes |
|---|---|
| `schema_version` | This doc is **1**. The loader refuses anything newer. |
| `faction_count` | Must equal the entries in `factions.json`; 2–4. |
| `neutral` | The uncontrolled side. Pack data, not a hardcoded singleton, because its name and color are setting-specific. **Not** playable, not counted in `faction_count`. |
| `unexplored_color` | Color for systems the viewing faction has no knowledge of. A display convention, not a rule. |
| `map_image` | **★ DECIDED (TeeJ, 2026-09-21).** The galaxy backdrop, as a filename relative to the pack folder. Required; a pack that declares none is a **load error**, not a blank screen. Named here rather than fixed by convention so the engine never assumes a filename. **Or `"<art set>:<path>"`**, a picture in one of the pack's `art_sets` (§14): the player's own, so the pack does not ship it and the loader does not look for it; without it the map is placed by `map_image_rect` with nothing under it. |
| `art_sets` | **★ 2026-09-23 (docs/original-art-plan.md).** The art sets the pack's original look comes from, e.g. `["swr-original"]` - see §14. Optional; without it the pack has the engine's own art. |
| `map_image_rect` | **★ 2026-09-22.** Where the picture sits in the pack's map coordinate space, `[x, y, w, h]`: `x, y` is the map-space point at the picture's (and the map frame's) top-left corner, `w, h` the picture's extent in map units. The map view scales the space so that rectangle fills its frame, draws the picture there, and places every marker at `(coordinate − (x, y)) × scale`. Absent: the picture's own pixels are the space. Star Wars: `[-5, 110, 1070.67, 803]`, exactly where `Main.tscn` used to bake the picture, so nothing moved. WWII: `[0, 0, 700, 420]` for a 1750×1050 picture. |
| `setup.galaxy_sizes` | The size names offered on the menu. **Which sectors each size includes is declared per sector** in `map.json` (`min_size`), not here — see §4. |
| `setup.galaxy_size_default` | The size pre-selected on the Cockpit. Optional; the first of `galaxy_sizes` when absent. Must be one of them. |
| `summary` | **★ DECIDED (TeeJ, 2026-09-22).** One sentence on what the setting is, shown on the pack picker's card under the name. Optional; blank when absent. The card's other content (name, sides and their colours, the map picture) already comes from `display_name`, `factions.json` and `map_image`. |
| `card_image` | **★ 2026-09-24 (TeeJ).** The pack picker card's picture when `map_image` cannot be shown - its art set not imported. A file in the pack folder, or `"<art set>:<path>"` (rule 18 checks the art set is declared). Optional, and not required to be there: a copy of the Star Wars pack that leaves the picture behind still loads, its card just has no picture. Star Wars: `milky_way.jpg`, NASA/JPL-Caltech's Milky Way. |
| `credits` | Who made the setting: the lines "View credits" shows, from either form of the Cockpit. Optional. A pack with a Cockpit picture may put them in `menu.credits` instead, which wins when both are given. |
| `victory_tips` | The two win-condition tooltips on the Multiplayer Options screen — `standard` and `hq_only` (manual p162; the Star Wars pack carries its sentences verbatim). Optional; both texts required when present. The last setting text engine code carried (TeeJ, 2026-09-22). |
| `menu` | **The Shuttle Cockpit as the pack's picture** (manual p021, Fig. 2.2). Optional: a pack without it gets the engine's labelled-button menu. `image` is a file in the pack folder, or `"<art set>:<path>"` (§14) - without that art set the pack gets the button menu; `regions` lays one clickable area per menu function over it, `rect` = `[x, y, w, h]` in the picture's own pixels (the engine scales them with the picture, keeping aspect). `action` is engine vocabulary — `difficulty` (`value` easy/medium/hard), `galaxy_size` (`value` from `setup.galaxy_sizes`), `start` (`value` a faction id), `load_game`, `credits`, `hq_only_victory`, `multiplayer`, `exit`. **Every function must have exactly one region** — one per difficulty, per offered size, per playable faction, and one each of the rest — so the picture cannot lose a function the button menu has (validation rule 11). `readout` is the text panel the engine paints `standard` / `hq_only` on as the victory toggle changes; `selected_color` is the corner-bracket colour on the chosen difficulty and size; a region may override it with its own `selected_color` (the original marks difficulty in red, galaxy size in yellow). A region may give a `quad` - the screen it shows as four `[x, y]` corners in the picture's pixels, top-left, top-right, bottom-right, bottom-left - and the brackets then follow that screen's edges instead of the rect's (the Star Wars cockpit's difficulty monitors are seen at an angle); the click area stays the rect. **The picture must carry no selection state of its own** — the engine draws the brackets; the Star Wars capture had the original's marks scrubbed from the easy and standard screens. `credits` is the lines "View credits" shows. `monitors` (optional) puts a picture on each monitor (Fig. 2.2's "rotating red Alliance icon"): `image` is a strip of `frames` equal frames side by side (a pack file or `"<art set>:<path>"`), played in a loop at `monitor_fps` (default 10) with its top-left at `at` = `[x, y]` in the picture's pixels; with `region` (a region's `action` or `action:value`) and `selected_image`, that picture shows while the region is chosen; with `still` (a frame of the strip, from 0) it holds that frame and does not move. A monitor whose picture is missing stays dark. |

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
        { "planet": "yavin", "support": 100, "explored": true,
          "garrison": "alliance_start_garrison" }
      ],
      "seed": {
        "hq_facilities": "alliance_hq_facilities",
        "hq_garrison": "alliance_hq_garrison",
        "fleet": "alliance_fleet",
        "procedural_fleet": "alliance_procedural_fleet"
      },
      "victory": { "capture_characters": ["emperor_palpatine", "darth_vader"] }
    }
  ]
}
```

| Field | Notes |
|---|---|
| `color` | Drives the map marker, the sector window and the GID legend. One source of truth; the engine holds no faction color constants. |
| `hq.kind` | `fixed` — a known capital (`planet`, a **planet id**), captured when taken. `hidden` — placed at `placement` (a **planet id** or the `random_rim` sentinel), unknown to other factions until located, optionally `movable`, destroyed rather than captured. **Sabotage follows the kind** (TeeJ, 2026-09-22): a hidden HQ can be sabotaged (destroyed), a fixed one cannot — that is manual p108's "the Empire can sabotage the Alliance headquarters" without naming a side. |
| `occupation_support_policy` | `garrison_bonus` (troops raise support over time) or `occupation_penalty` (first occupation lowers it). Asymmetry as a flag. |
| `loyalty_label` | Display string for the GID loyalty mode. |
| `agent_name` | What the side's agent droid / adviser is called (manual p030, Fig. 2.16; C-3PO and IMP-22). Optional; "Agent" when absent. Was an id branch in engine code. |
| `adjective` | The side's name as an adjective in the game's own sentences - "the **Imperial** fleet", "**Alliance** forces" (the battle alert and results, TEXTSTRA's battle block). Optional; the `display_name` when absent. |
| `starting_planets[]` | `{planet, support, explored, garrison}`. `planet` is a **planet id** (`map.json`); `garrison` a logistics table id (`setup.json`). |
| `seed` | Which day-zero logistics table seeds this side's HQ, garrison and fleets — **table ids** from `setup.json` (§12 Q2). |
| `victory.capture_characters` | **Character ids** (`characters.json`) this side must hold captive to win. The Objectives window looks the display name up (`FactionRegistry.CharacterNameOf`). |

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
| `map.x`, `map.y` | **The pack's own map space, and they are gameplay:** `Planet.DistanceTo` reads them, so a pack's coordinate span sets its travel times under the rules it ships (Star Wars spans ~675 units; the WWII pack scaled its picture pixels by 1/2.5 to a 700-unit span for comparable journeys). Never rescale a pack's coordinates to fit a picture. The map view fits the space to its frame by `pack.json` `map_image_rect` and places every marker at `coordinate × scale`. |
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

### Galaxy size — `min_size` on each sector

Which sectors a `standard` / `large` / `huge` galaxy contains is `map.json`
data: each sector's `min_size`. (It was once twenty literal sector names in
`galaxy_factory.gd`; that list is gone.) The game offers **three** sizes - the
menu's buttons and a multiplayer room's setting - so `setup.galaxy_sizes` needs
at least three entries (rule 22); a fourth and later can be chosen only from a
pack's own Cockpit picture.

The Star Wars counts, which reconcile with the original's sector table:

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

**★ DECIDED (TeeJ, 2026-09-21) — named in `pack.json`.** The backdrop the
galaxy map draws over. The manifest names it (§2) rather than the engine
assuming a path, and a pack that omits it fails to load. It is a picture in the
pack folder, or `"<art set>:<path>"` (the Star Wars pack's is the player's own
`swr-original:screens/galaxy.png`).

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
    { "id": "ion_cannon", "display_name": "KDY-150", "family": "ion_cannon", "tier": 1,
      "roles": ["planet_defense", "disable"],
      "buildable_by": ["alliance", "empire"],
      "construction_cost": 4, "maintenance_cost": 4,
      "research_order": 0, "research_cost": 0,
      "stats": { "bombardment_defense": 5, "weapon_rating": 2000, "shield_strength": 0 },
      "source_family_id": 34, "source_id": 1, "string_id": 8704 }
  ]
}
```

`family` is a **string**; the facilities of one family are its tiers.
`source_family_id`, `source_id` and
`string_id` are provenance - the original's table numbers - and nothing
selects on them.

| Field | Notes |
|---|---|
| `roles` | The engine's selection vocabulary. v1 role set: `headquarters`, `extracts_raw`, `refines`, `produces_unit`, `produces_troop`, `produces_facility`, `planet_defense`, `shield`, `disable`, `anti_ship`, `superweapon_shield` (the structure that shelters the `superweapon` unit while docked; counts as military for bombardment). The loader rejects unknown roles so a typo cannot silently create an inert facility. |
| `buildable_by` | A list of faction ids; absent means all. |
| `stats` | A map keyed by the engine's **stat vocabulary** — `shield`, `hull`, `hyperdrive`, `sublight`, `detection`, `weapon_rating`, `shield_strength`, `bombardment_defense`, `processing_rate`, … — read by name in `military_catalog.gd` and `facility_catalog.gd`. **⚠ Corrected 2026-09-22:** this row used to say the engine has no built-in stat vocabulary; it does, exactly as it has a role vocabulary. The pack supplies the values here and the on-screen **words** in `display.json` `terms` (§10). Absorbs the production/defensive column split. |

---

## 6. `units.json` — mobile units

From `military_units.json`, 57 rows, 44 columns.

```json
{
  "units": [
    { "id": "mon_calamari_cruiser", "display_name": "Mon Calamari Cruiser",
      "kind": "capital_ship", "buildable_by": ["alliance"],
      "construction_cost": 92, "maintenance_cost": 70,
      "research_order": 2, "research_cost": 24,
      "weapons": {
        "ion_cannon": { "arcs": { "fore": 40, "aft": 40, "starboard": 60, "port": 60 }, "range": 35 },
        "turbolaser": { "arcs": { "fore": 60, "aft": 60, "starboard": 120, "port": 120 }, "range": 50 }
      },
      "stats": { "detection": 10, "shield": 300, "sublight": 4, "maneuverability": 2,
                 "hyperdrive": 60, "hull": 2400, "fighter_capacity": 3, "troop_capacity": 1 } },

    { "id": "b_wing", "display_name": "B-wing", "kind": "fighter", "buildable_by": ["alliance"],
      "weapons": {
        "ion_cannon": { "arcs": { "fore": 6, "aft": 0, "starboard": 0, "port": 0 } },
        "laser":      { "arcs": { "fore": 8, "aft": 0, "starboard": 0, "port": 0 } },
        "torpedo":    { "amount": 12, "range": 7 }
      },
      "stats": { "shield": 9, "sublight": 7, "hyperdrive": 60, "squadron_size": 12 } }
  ]
}
```

| Field | Notes |
|---|---|
| `kind` | `capital_ship`, `fighter`, `troop` or `spec_force` - what the unit IS to the engine. |
| `roles` | **★ APPROVED (TeeJ, 2026-09-22).** The engine's special cases for a unit, so no rule names one: `superweapon` (the Death Star — Superweapon Sabotage's target, and what plain Sabotage refuses), `garrison_troop` (the regiment the mission score's garrison term counts). Usually absent. Unknown roles are a load error. |
| `weapons` | A map keyed by **weapon id** (`weapons.json`). A weapon with firing arcs gives `arcs` (`fore`, `aft`, `starboard`, `port`) and a `range`; one without (a torpedo) gives an `amount` and a `range`. **The range is the unit's, per weapon** - the same weapon class reaches differently on different hulls. |
| `stats` | Keyed by the engine's stat vocabulary (§5). **A stat that does not apply is omitted**, never `null`. |

**Order matters:** the tactical engine sums a unit's weapons in `weapons.json`
declaration order, rounding per weapon, so reordering weapons changes battle
results (and the pack hash).

### Weapons — `weapons.json`

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

#### The file (live)

```json
{
  "weapons": [
    { "id": "ion_cannon", "display_name": "Ion Cannon",
      "roles": ["no_fighter_effect"], "arcs": true, "observed_ranges": [35, 40, 60] },
    { "id": "turbolaser", "display_name": "Turbolaser",
      "roles": ["fighter_accuracy_scaled"], "arcs": true, "observed_ranges": [35, 50, 60, 65, 70, 75] },
    { "id": "torpedo", "display_name": "Torpedo",
      "roles": ["no_fighter_effect", "requires_shields_down", "squadron_only"],
      "arcs": false, "observed_ranges": [7, 10] }
  ]
}
```

The engine selects on the `roles`; the words are the pack's. `observed_ranges`
is a note of the ranges the original's units use - **nothing reads it**; a
unit's `weapons` entry carries the range that counts (above). The three summary
columns of the original's table are gone: each was exactly the sum of its arcs.

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
| `ForceRanking.JediStudent` / `JediKnight` / `JediMaster` | `SpecialPowerRank.Student` / `Knight` / `Master` — labels in `display.json` |
| `RuleId.FastHealForceRankThresh` | `FastHealSpecialPowerThresh` |

**The five band labels stay pack strings.** The engine holds ranked bands and
their thresholds (10 / 20 / 80 / 100 / 120 —
[character.gd:144-151](src/game/character.gd:144)); what they are *called*
("Jedi Master") is `display.json` content.

**LANDED IN FULL 2026-09-21.** The mission half went with `missions.json`
(`SpecialPowerTraining`, §9). The band members went with `display.json`: the
eight render sites — Character Status window, three Force messages, the story
manager, `MissionManager.Pretty()` and two debug lines — all read the pack's
label through `Character.RankLabel`. `tests/pack_validation.gd` proves every
band resolves to the pack's wording and that no enum member leaks.

> **Resolved.** The band members are `Novice, Trainee, Student, Knight, Master`
> — unprefixed, because they are **never rendered**: what a band is *called* is
> `display.json` `special_power_ranks`, read through the one helper
> `Character.RankLabel`. TeeJ's literal was `SpecialPowerMaster`; with the label
> in the pack the prefix carried nothing, so the shorter form was taken. Say if
> the literal is preferred — it is a one-line rename with no behaviour.

**This is a code rename, not a data move** — it touches `character.gd`,
`captivity_manager.gd`, `rule_id.gd` and the character tables together, and
needs its own go-ahead before it lands.

---

### Roles — the story parts and day-zero placement

**★ APPROVED (TeeJ, 2026-09-22).** `roles` on a character, so the engine never
names one:

| Role | What the engine does with it |
|---|---|
| `starts_at_first_world` | Day zero places them on the side's first `starting_planets` entry, awaiting orders (Luke, Leia, Han, Chewbacca, Dodonna, Wedge). |
| `starts_at_hq` | Day zero places them at the side's headquarters (Mon Mothma, the Emperor). |
| `starts_at_random_holding` | Day zero places them on a random world or fleet the side holds, in roster order (Vader and the five Imperial officers). |
| `pilgrim` | The Force encounter aggressor, the Dagobah pilgrimage, the Final Battle (Luke). |
| `heir` | The second encounter aggressor; exempt from latent-power discovery; learns from the pilgrim (Leia). |
| `dark_lord` / `dark_master` | The encounter antagonists and the Final Battle's opponents; the `dark_master` cannot be trained (Vader, the Emperor). |
| `smuggler` | The bounty hunters' target and Jabba's palace; the Millennium Falcon travel effect (Han). |
| `companion` | Joins the palace rescue party with the pilgrim and the heir (Chewbacca). |

### `starts_at` — a declared opening world

**★ DECIDED (TeeJ, 2026-09-22).** `"starts_at": "<planet id>"` on a character
puts them on that world at day zero, awaiting orders, and wins over the
placement roles above. Optional. The world must be one the character's own
side holds at day zero — one of its `starting_planets` or its fixed `hq`
planet — or the loader refuses it (rule 15). It draws nothing from the PRNG,
so a pack that declares none (Star Wars) is placed exactly as before. The WWII
pack uses it so Churchill opens in Britain, Eisenhower in the United States,
de Gaulle in France, Stalin in Russia, Chiang in China, Mussolini in Italy and
Tojo in Japan, instead of every Allied leader at Britain.

Each story role is **one character** (validation rule 12); a pack that casts
nobody in a part simply never fires that set-piece. Unknown roles are a load
error.

## 8. `rules.json` and `setup.json` — the faction-keyed migration

**⚠ The original draft described this as pending. It is done.** Both files are
already nested maps keyed by faction id, and the extractors that generate them
(`parse_rules.py`, `parse_side_lottery.py`, `parse_military.py` in the old
repo) were updated in the same change. (Historical: the pack is hand-edited now.)

`rules.json` is a **top-level array** of 213 rows, one per rule entry:

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

### Seeding rows name what they place BY ID

**★ LANDED 2026-09-22 (branch `pack-ww2`).** A logistics row's asset is
`{"unit": "<units.json id>"}` or `{"facility": "<facilities.json id>"}` —
never the original's `FamilyId` / `AssetId` numbers, which `DeployAsset`
matched with a literal `32 → headquarters, 16 → Troop, …` table. That was the
last place a pack named a thing by the binary's table position, and the WWII
pack found it on its first soak: "0 Fleets containing 0 Capital Ships". A
facility row places tier 1 of that facility's family (the original's
"Refinery (Tier 2)" rows seeded a tier-1 refinery). In a hierarchical list a
`null` child is the original's "None" row: the first child is the CARRIER slot
and an empty one means "no carrier" — dropping it would reorder the garrison
and move the replay hash. Validation rule 13 rejects a row that resolves to
nothing, and refuses `FamilyId` outright.

#### `setup.json` logistics tables

`setup.json` is `{"side_lottery": [...], "logistics": {<table id>: {...}}}`.
A logistics table is what day zero places on a world:

```json
"alliance_fleet": {
  "Type": "CMUN/FACL (Hierarchical)", "Description": "SeedFamilyTableEntry",
  "source_file": "CMUNAFTB.DAT", "fixed_range": [90, 91],
  "Entries": [
    { "ParentId": 1, "ProbabilityThreshold": 1, "Multiplier": 1, "ChildrenCount": 1,
      "Assets": [{ "unit": "corellian_corvette" }] },
    { "ParentId": 2, "ProbabilityThreshold": 2, "Multiplier": 1, "ChildrenCount": 3,
      "Assets": [{ "unit": "medium_transport" }, { "unit": "alliance_fleet_regiment" },
                 { "unit": "alliance_fleet_regiment" }] }
  ] },
"core_system_facilities": {
  "Type": "SYFC (Flat)", "source_file": "SYFCCRTB.DAT",
  "Entries": [
    { "ParentId": 1, "ProbabilityThreshold": 0, "SpawnChancePercent": 0, "Asset": null },
    { "ParentId": 2, "ProbabilityThreshold": 36, "SpawnChancePercent": 64, "Asset": { "facility": "refinery" } }
  ] }
```

| Field | Read by the engine? | Meaning |
|---|---|---|
| `Type` | **yes** | A table whose `Type` contains `SYFC` seeds a world's **facilities** slot by slot (each energy slot rolls against the entries' `ProbabilityThreshold`, placing that entry's `Asset`). Any other table places **units** (below). |
| `Entries` | **yes** | The rows, in order. |
| `fixed_range` | **yes** | `[first, max]` rule-entry ids (`rules.json` `EntryId`s): the table is a fixed list and entries `first..max` (read from those rules) are all placed. Absent: one entry is drawn - the last whose `ProbabilityThreshold` is at or under a 1-100 roll. |
| `ProbabilityThreshold` | **yes** | The roll an entry needs (above). |
| `Asset` | **yes** (SYFC) | `{"facility": id}` or `{"unit": id}`; `null` places nothing. |
| `Assets` | **yes** (unit tables) | A carrier and what it carries: the first is placed; when it is a capital ship the rest (fighters, troops) ride in it, otherwise they stand on the world. A `null` first entry is "no carrier". |
| `Multiplier` | **yes** | How many times the entry's `Assets` are placed. Default 1. |
| `ParentId`, `SpawnChancePercent` | parsed, **not used** | The original's columns, kept for provenance. |
| `ChildrenCount`, `Description`, `source_file` | **no** | Provenance. |

**Tables the engine reads by name:** `core_system_facilities` (every inhabited
world in a ring-1 sector) and `rim_system_facilities` (every other) - rule 20.
Every other table is named by `factions.json` `seed` or a starting world's
`garrison`.

`side_lottery.json` (35 rows) is an **N×N matrix** —
`by_faction[side][difficulty][side]` — plus flat `dev` and `mp` maps. Today 2×2.
A third faction makes every one of the 35 entries a 3×3, and the original
`SDPRTB.DAT` has no values to supply them; they would have to be authored.

**⚠ Correction — `core_infrastructure.json` and `rim_infrastructure.json` do not
exist.** The original draft named them as `setup.json`'s sources. Neither file
is in either repo. `setup.json`'s real sources are `side_lottery.json` and
`day_zero_logistics.json`.

> **The pack files are hand-edited and are the contract (2026-09-22).** The
> `tools/build-*-json.py` transforms that first produced them from the old
> repo's parsed tables were retired: they knew nothing of the fields added by
> hand since (roles, `behaviour`, `agent_name`, `menu`, `victory_tips`, id-keyed
> seeding) and would have wiped them. Provenance is the `source_family_id` /
> `source_id` / `source_file` fields on the rows, not a regeneration path.
> Risk #3 of the old charter ("regeneration silently reverts") no longer exists
> because there is no regeneration.

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

- `available_to` replaces the `Alliance` / `Empire` integer pair. **Code state
  (2026-09-24): only Assassination reads it** (`MissionManager` refuses the
  mission to a side not listed); for every other mission it is **not
  implemented** - either side can run it whatever the list says.
- `behaviour` **★ APPROVED (TeeJ, 2026-09-22)** names the ENGINE behaviour this
  row is the pack's flavour of — `Enums.MissionType` in snake_case
  (`superweapon_sabotage`, `special_power_training`, …) plus the two scripted
  stays `dagobah` and `palace`. This is the join; the engine no longer knows the
  ids `death_star_sabotage` or `jedi_training`. One mission per behaviour;
  rows without one (the unnamed tables) are content the engine has no code for.
  **A mission's outcome table in `mission_tables.json` shares the mission's
  id** — that is how `MissionManager.TableFor` finds it.
- `spec_forces` is a list of **display names** in the raw data
  (`"Bothan Spies"`); it **becomes a list of unit ids** (§12 Q1, decided).
- **⚠ CORRECTION — `Enums.MissionType` is NOT the `FacilityType` case, and this
  file does not replace it.** A facility's behaviour reduced entirely to role
  tags and stats, so the enum was pure vocabulary and could go. A mission's
  does not: each kind is a block of bespoke code in `mission_manager.gd` (1160
  lines) with its own scoring terms, rating gains and resolution. A pack cannot
  add a mission kind without code, and inventing a generic mission-scripting
  model to pretend otherwise would be inventing mechanics. **`MissionType` is
  the engine's list of behaviours it implements**; which of them a setting
  offers, what they are called, who may run them, their lengths, flags, teams
  and outcome tables are pack data and live here.

  What WAS wrong and is fixed: two members were IP-named. They are now
  `SuperweaponSabotage` and `SpecialPowerTraining`, joined to the pack's
  `death_star_sabotage` and `jedi_training` by id. The engine name is generic;
  the player still reads the pack's wording.
- Seven `UnknownN` columns remain undecoded. They stay as-is; a pack author
  never sets them.

### `mission_tables.json` — 20 tables

```json
{ "tables": {
    "diplomacy": { "source_file": "DIPLMSTB.DAT", "description": "Diplomacy - mission success %",
      "entries": [ { "id": 1, "field2": 1, "threshold": -39, "value": 1 },
                   { "id": 2, "field2": 1, "threshold": -29, "value": 3 } ] } } }
```

A table maps a score to a value: the value of the last entry whose `threshold`
the score reaches (the first entry's when none). `id` and `field2` are the
original's columns. Keys are role ids, `source_file` kept for provenance
(§12 Q2).

| Tables | Read by |
|---|---|
| one per mission, **named by the mission's id** (`diplomacy`, `sabotage`, `death_star_sabotage`, …) | that mission's success roll (`MissionManager.TableFor`) |
| `foil`, `decoy`, `evasion`, `escape`, `informants`, `uprising_start` | the mechanic of that name. **Missing, the mechanic switches off** without an error: nothing is foiled, no decoy fools, a pursued character always escapes, captives never try, informants never report, and no uprising ever starts (the last logs an error). The loader does not require them. |
| `troop_decoy`, `character_search`, `resource_event`, `uprising_end` | **nothing - not implemented.** The Star Wars pack carries them from the original; editing them changes nothing. |

---

## 10. `display.json` — the Galactic Information Display

**Live.** Was a code table in [gid.gd](src/ui/gid.gd); the pack now declares
the catalog and the engine computes each `quantity.kind`. The pack-driven
catalog was proven **byte-identical** to the code one — every label, title,
threshold and flare, all 21 modes — by dumping both and diffing.

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
| `quantity.kind` | How the engine computes the magnitude. **The v1 set is measured from the catalog it replaced — one kind per distinct reader:** `support`, `uprising`, `my_fleets` (`status`), `personnel` (`busy`), `status_figure` (`key`), `facility_count` (`family`), `idle_producer` (`role`), `defence_figure` (`key`), `intel_line_count` (`section`), `constant_zero`. The draft's guessed list is superseded. |
| `tiers` | Ordered descending by `min`; the last entry (`min: 0`) is the bare-dot tier. Thresholds are **absolute**, never normalised to the map maximum. |
| `flare` | `big` / `mid` / `low` / `none`. Marker *sizes* are engine presentation constants; which tier gets which size is pack data. |
| `label` | **Load-bearing:** the active mode's label is part of the game signature (`GameSignature.GidLabel`). Rename one and the lockstep hash changes. |
| `title_from` | `loyalty_label` — the key-panel title is the player's faction's `loyalty_label` from `factions.json`, resolved per side. |
| `galaxy_display_modes` | Mode ids in the original's Alt+1..9 order. |
| `loyalty_bar` | **Optional.** The playable sides left to right on the sector window's loyalty bar (manual p025 Fig 2.9 has the Empire on the left, the Alliance on the right, so the Star Wars pack says `["empire", "alliance"]`). When given it must name every faction exactly once (rule 16); left out, the bar follows the pack's faction order. |
| `icons` | **Optional per key.** The pack's own picture for a sector-window corner glyph: `manufacturing` (top left), `fleet` (upper right), `defenses` (lower left), `mission` and `uprising` (lower right) - manual p070 Fig 3.7. A file in the pack folder, white on alpha (the map tints it with the faction colour), 16 px. A glyph the pack does not name comes from the engine's `assets/icons/` (drawn by `tools/draw_corner_icons.py`). Rule 17. In the original's look, the sector window draws the art set's own corner pictures instead (§14). |
| `special_power_ranks` | The band labels for §7's special power: `none`, `novice`, `trainee`, `student`, `knight`, `master`. |
| `terms` | **★ APPROVED (TeeJ, 2026-09-22).** What this setting calls the engine's concepts on screen — the unit stats (`hyperdrive`, `sublight`, `shield`, `hull`, `detection`, `weapons`, `bombardment`, `bombardment_defense`, `bombardment_modifier`, `maintenance`, `squadron_size`, `fighter_capacity`, `troop_capacity`), the economy (`energy`, `raw_materials`, `refined_materials`, `mine`/`mines`, `refinery`/`refineries`), the two defence kinds as prose plurals (`planetary_shields`, `orbital_batteries`), the unit kinds (`fighter_squadron(s)`, `trooper_regiment(s)`), `in_transit` ("in hyperspace") and the five ship systems tactical damage tracks (`system_shield_recharge`, `system_weapon_recharge`, `system_tractor`, `system_engines`, `system_hyperdrive`; manual p128) and a standing defence's state tag in the Defenses window (`shield_active`, `weapon_armed`). The key set is engine vocabulary (`PackLoader.KNOWN_TERMS`); an unknown key is a load error (rule 14). **Optional**: a key the pack leaves out takes the engine's neutral default, so a pack labels only what it wants to. Read through one helper, like the rank labels. Note the two speeds are distinct concepts: `hyperdrive` is movement *between* systems (a time multiplier, lower is faster, and 0 means "cannot"), `sublight` is speed *in* a battle. |

Faction colors and the legend come from `factions.json` + `pack.json`, so the
GID legend stops being hardcoded rows.

---

## 11. Validation

The loader reports **every** error before play, not the first. Implemented in
[pack_loader.gd](src/data/pack_loader.gd); each live rule has a negative test in
`tests/pack_validation.gd` that proves it rejects, not merely that the real pack
passes. The pack picker lists a pack that fails with its errors and no Play,
and the import refuses one (§14).

1. ✅ `pack.json.id` equals the folder name; `schema_version` ≤ engine-supported.
2. ✅ `faction_count` equals the entries in `factions.json`, and is 2–4.
3. ✅ Cross-references resolve and ids are unique: planets to sectors; facility,
   unit, character and mission rows to what they name.
4. ✅ Every facility `roles` entry, weapon role and `display.quantity.kind` is in
   the engine's known set for this `schema_version`.
5. ✅ Faction references resolve: a character's `faction` and `can_command`
   ranks; facility and unit `buildable_by`; mission `available_to`.
6. ✅ Each faction's `hq` is internally consistent: a `fixed` HQ names a planet;
   a `hidden` HQ declares a `placement`.
7. ✅ Every `starting_planets` entry is a planet id, a `fixed` HQ's `planet` is a planet
   id, and a `hidden` HQ's `placement` is `random_rim` or a planet id.
8. ✅ Display tiers are ordered descending, use a known flare, and terminate
   with a `min: 0` tier; every Alt+N slot names a declared mode; every band has
   a label.
9. ✅ `map_image` is declared and names a file present in the pack folder (or
   an art set's picture).
10. ✅ Every sector's `min_size` is one of `setup.galaxy_sizes`, and the smallest
    declared size has at least one sector — otherwise that menu option yields an
    empty galaxy.
11. ✅ The Cockpit picture (`menu`), when a pack has one, reaches every menu
    function with exactly one region each (§2); its readout, monitors and
    colours are well-formed.
12. ✅ Character roles, unit roles and mission behaviours are in the engine's
    set; each story role is cast at most once; each mission behaviour appears
    at most once.
13. ✅ Every seeding row in `setup.json` names a `unit` or `facility` id the pack
    declares (a `null` child is the empty carrier slot); a row carrying the
    original's `FamilyId` / `AssetId` is refused.
14. ✅ Every `display.json` `terms` key is one of the engine's known terms and
    its label is non-empty.
15. ✅ A character's `starts_at` names a planet on the map that its side holds at
    day zero (a `starting_planets` entry or its fixed `hq` planet).
16. ✅ `display.json` `loyalty_bar`, when given, names every playable faction
    exactly once and nothing else.
17. ✅ `display.json` `icons` names only the five corner glyphs, each a file the
    pack ships.
18. ✅ Art sets (§14): every `art_sets` entry is one the engine knows; with art
    sets, every faction names a `skin` the sets have (and without them, none
    does); every row's `art` is `[<set>:]<kind>/<id>` with a declared set and a
    known kind; an art-set `map_image` or `menu.image` names a declared set.

What day zero reads without asking - each of these once passed the loader and
then stopped the game on its first day (the editor handoff, 2026-09-23):

19. ✅ A seeded side (`factions.json` `seed`) with a headquarters names
    `hq_facilities`, `hq_garrison` and `fleet`; one whose starting worlds carry
    a `garrison` names `fleet`.
20. ✅ `setup.json` logistics has `core_system_facilities` when the map has a
    ring-1 sector and `rim_system_facilities` when it has any other.
21. ✅ Every logistics table is an object.
22. ✅ `setup.galaxy_sizes` has at least three entries.

**Not checked by the loader** (the engine copes, but a pack author should know):
the named mission tables of §9 (missing, their mechanic switches off); a
`galaxy_sizes` entry past the third (reachable only from the pack's own Cockpit
picture); a logistics table's `Type` (only `SYFC` in it changes anything, §8).

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

   **★ LANDED.** `Planet.PackId` / `Character.PackId` carry the ids; day zero,
   victory, captivity, the story manager, the AI objective planner and the
   loader all resolve on them. The two places a reference is also *shown*
   (the Objectives window's capital and capture rows) look the display name up.
   `missions.json` SpecForces landed with §9.

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

   **★ DONE for both table sets, nothing guessed.** The 20 mission tables carry
   their own `description` (§9). The 11 logistics tables carry none, so their
   ids are derived from **what reads them**: `factions.json.seed` already names
   each one's role per side, and day zero picks the core/rim pair by ring. The
   generator refuses an id nothing references.

   One thing the rename exposed: `DayZeroGenerator.FixedListRange` decided
   whether a table was a fixed list by **matching the `.DAT` filename**. That
   is pack data and now lives on the table as `fixed_range` (§8).

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
   generated, not hand-edited (it was, then). The cost landed in `parse_rules.py`
   plus a re-export of all 213 rows. Not worth it.

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
| 36 | **Q1 landed** — `factions.json` references planets and characters by id; every resolver compares `PackId`; validator rules 3 and 7 check ids, including a hidden HQ's placement | Closes the last half-implemented decision. Three stale lines fixed: the "source copy is behind" blockquote, the "Phases 1–2" status, §3's `.DAT` example |
| 35 | Two bugs the sweep found that the gate cannot: `MissionTableManager.LoadFromPack` cleared the **pack's own** table dictionary on the second game in a process (every mission table vanished; only a load-then-compare test sees it), and six surviving `Facility.Type` reads in the Economy window | `tests/load_resave.gd` and `tests/ui_smoke.gd`. The soak gate runs one game per process and never opens a window |
| 34 | **§10 live.** `display.json` drives the GID catalog, the Alt+1..9 order and the special-power band labels; `gid.gd`'s literal table is gone. Proven byte-identical by before/after dump; signature untouched (labels unchanged). Committed on that evidence at TeeJ's call; a single soak follows | Q5 is **complete**: the band members are `Student`/`Knight`/`Master` and never rendered. `Label` on a DTO shadows a native class — the second time |
| 33 | `pack_validation` counts *ran* against *ok + failed*, so a runtime abort inside a case can never print PASS | It did exactly that when `PackDefs` failed to compile |
| 32 | **No `uprising.json`.** `UprisingTable` reads the `uprising_start` table the pack already carries in `mission_tables.json` | Two byte-identical copies of one table would be a second source of truth |
| 31 | **§8 live.** `rules.json` and `setup.json` moved into the pack; `RuleManager`, `SideLotteryManager` and `SeedManager` read it. Logistics tables renamed from use (Q2, closing its last item). **No re-baseline** | The rename exposed `FixedListRange`, which chose seeding behaviour by matching `.DAT` filenames. Now `fixed_range` on the table |
| 30 | **§9 live.** `MissionCatalog` and `MissionTableManager` read the pack; the hardcoded MISSNSD numbers and `.DAT` filenames are gone. Two IP-named members renamed. **No re-baseline** — byte-identical | §9's claim that this file "must replace" `Enums.MissionType` is **corrected**: mission behaviour is engine, not content |
| 29 | **§9 data built.** `missions.json` (25) and `mission_tables.json` (20) generated, loaded and validated; nothing reads them yet. `Alliance`/`Empire` became `available_to` — the last instance of the pattern the charter forbids. SpecForces resolve to unit ids (Q1) | Q2's "five tables must be read before naming" is **resolved**: the tables self-describe |
| 28 | **§6 live.** `MilitaryCatalog` and the tactical engine read the pack; the four weapon names are gone from engine code. **No re-baseline** — byte-identical | Weapon DECLARATION ORDER in `weapons.json` is now load-bearing: the damage sum rounds to f32 per weapon |
| 27 | **§6 data built.** `units.json` (57) and `weapons.json` (4 classes) generated, loaded and validated; nothing reads them yet. The three derived summary columns are DROPPED, and the generator re-proves on every build that each is exactly the sum of its arcs | The tactical engine still reads the flat unit fields. Swapping it is the next step |
| 26 | **§5 built and live.** `Enums.FacilityType` is **deleted**; facilities are pack data selected by role. 154 call sites across 24 files. The game signature now carries the family id, so the soak gate is re-baselined | Proven behaviour-identical first by emitting the old ordinals: 1004/1004. Five silent bugs found on the way — see the commit |
| 37 | **§2 `menu`** — the Shuttle Cockpit picture with a region per function, `setup.galaxy_size_default`, validation rule 11 (every function reachable, one region each). The Star Wars pack ships `cockpit.png` mapped from Fig. 2.2; a pack without `menu` keeps the button menu | TeeJ, 2026-09-22: packs own their main-menu picture. The manual labels every control of Fig. 2.2, so the region vocabulary is exactly that list |
| 38 | **Phase 5, mechanical batch.** `Unit.PackId`; the SpecForce mission roster is `missions.json` `spec_forces` inverted (`MissionCatalog.SpecForceMissions`), Assassination side-lock is `available_to`; the loyalty capital is any fixed-HQ world; `factions.json` `agent_name`; `SeedManager` reads defence stats from `facilities.json`, not `data/`; replay defaults to the first playable faction; the Galaxy Overview counts units by id | The 2026-09-22 audit (BACKLOG #14-#24). No new role vocabulary; every change proven identical on the Star Wars pack by the soak gate and `tests/spec_force_missions.gd` |
| 39 | **Roles and behaviours (TeeJ approved 2026-09-22).** `characters.json` `roles` (placement + story parts), `units.json` `roles` (`superweapon`, `garrison_troop`), `missions.json` `behaviour`; validation rule 12. Day zero, the story, Force and order managers, MissionManager and MissionTableManager select on these; the fourteen character names, the Death Star family number, "Stormtrooper Regiment", `death_star_sabotage` / `jedi_training` / `dagobah` / `palace` are gone from engine code | BACKLOG #25–#32. Soak gate green — the pack's roster order matches the old named lists, so the PRNG walk is unchanged |
| 40 | Pack defaults flipped to the manual's (`difficulty_default` easy, `galaxy_size_default` standard, manual p021); the button menu pre-presses them too. Per-region `selected_color`; the cockpit picture scrubbed of its baked-in brackets | TeeJ, 2026-09-22: the baked marks made every selection look like easy/standard |
| 41 | HQ sabotage derived from `hq.kind` — the last `actor.Id == "empire"` in engine code is gone | TeeJ, 2026-09-22: a hidden HQ is destroyable, a fixed one is captured; no new field needed |
| 42 | **Seeding by id.** `setup.json` rows name a `unit` or `facility` id; `DeployAsset`'s family-number table is gone; the four defence look-ups (assault shield count, intel sighting, intel facts, delivery message category) and `CanDestroySystem` select on roles; `superweapon_shield` joins the facility role set; validation rule 13 | The WWII pack (`packs/ww2`, BACKLOG #24) seeded nothing on an unchanged binary. Star Wars soak gate byte-identical |
| 42 | `data/*.json`, `Loaders` and eleven `CatalogDtos` classes deleted; the Military Data Editor removed; `tests/dto_parity.gd` compares the loaded pack with `tests/fixtures/dto-pack.json` | TeeJ, 2026-09-22: nothing read `data/` any more but the parity dump and the editor |
| 43 | `pack.json` `victory_tips` — the p162 Multiplayer Options tooltips come from the pack | TeeJ, 2026-09-22: pack strings, so the manual's verbatim wording stays pinned for this pack and a second pack shows its own |
| 44 | 32 `RuleId` constants renamed from setting names to their role (`SeedCapitalFirst`, `PilgrimVsDarkLordGainScale`, `SuperweaponSabotageCombatGain`, ...); the old name stays as a trailing comment for the GNPRTB trail. Engine identifiers only; the pack's `rules.json` is untouched | TeeJ, 2026-09-22 (BACKLOG #23/#34) |
| 45 | The six `tools/build-*-json.py` generators retired; the pack is hand-edited and is the contract, provenance via the `source_*` fields | TeeJ, 2026-09-22 (BACKLOG #36): four read a folder deleted in #52, two read the old repo, all six would have wiped the hand-added fields |
| 46 | **§10 `terms`** — the pack names the engine's stats, resources and unit kinds on screen; validation rule 14; §6's `stats` row corrected (stat keys ARE engine vocabulary). Step 1 of 5: schema and data only; the windows switch to the helper next | TeeJ, 2026-09-22: on the WWII pack a battleship showed "Shield" and "Hyperdrive" |
| 47 | Terms step 4: the same words in message prose, tooltips and headings across 17 engine and UI files; four prose nouns join the term set (`mine`, `refinery`, `planetary_shields`, `orbital_batteries`); the superweapon's messages use the pack's unit name | TeeJ, 2026-09-22 |
| 48 | Terms: the five tactical ship-system names (`system_*`) join the term set; `ShipDamage.DisplayName` reads them; both packs name them | TeeJ, 2026-09-22 |
| 49 | The Defense Facility Status window selects by role (`shield`, `disable`, `anti_ship`) and titles itself with the family's tier-1 display name; its shield row and the Defenses window's two state tags (`shield_active`, `weapon_armed`, new term keys) come from the pack. BACKLOG #37's window half | TeeJ, 2026-09-22: a WWII fortification opened as "Defense Facility" with shield strength "N/A" |
| 50 | The last facility ids in engine code go: the economy's two rates and the agent droid's build orders select by `extracts_raw` / `refines` (`FacilityCatalog.ProcessingRateForRole`, `FamilyForRole`); the intel Manufacturing lines name each queue after the pack's `produces_*` facility. BACKLOG #37 closed; no pack file changes | TeeJ, 2026-09-22 |
| 51 | **The pack picker.** `PackPicker.tscn` is the first scene: one card per pack under `packs/` (name, `summary`, the sides in their colours, `map_image`), Play loads it and goes on to its Cockpit; skipped when `--pack=` is given, a pack is already loaded, or only one is installed; a pack that fails validation is listed with its problems and no Play. `pack.json` `summary` (§2) | TeeJ, 2026-09-22: a setting has to be chosen before the Cockpit, which is pack content. The plumbing (PR #71) made the choice a load-by-id |
| 52 | **Exit returns to the picker.** The Cockpit's Exit (button and picture region) goes back to `PackPicker.tscn`, which unloads the pack (`FactionRegistry.Unload`, its only caller) and offers the cards again; the picker's own **Exit Game** quits (hidden on the web). With one pack, or `--pack=` forcing one, the Cockpit's Exit quits. The GID catalog remembers which pack built it. `tests/pack_switch.gd` proves a game after a switch hashes exactly like a fresh process | TeeJ, 2026-09-22: "make the cockpit exit to the pack picker, and have an exit game option in the picker" |
| 53 | **The map picture comes from the pack.** `GalaxyMap` loads `map_image`, places it by `map_image_rect` in the pack's map space, fits that to its frame and scales every marker with it; the Star Wars picture baked into `Main.tscn` is gone. **Coordinates are untouched: they are travel time** (`Planet.DistanceTo`) - a first draft converted Star Wars's to picture pixels and the soak gate diverged on day 2 | TeeJ, 2026-09-22: the WWII pack played over the Star Wars galaxy; a pack's own map has to show |
| 54 | **`starts_at`** on a character (§7): a declared opening world, winning over the placement roles; validation rule 15; day zero places it before the roles with no PRNG draw | TeeJ, 2026-09-22: every Allied leader opened at Britain because it was both first world and HQ |
| 55 | **`loyalty_bar`** in `display.json` (§10): the sides' order on the sector window's loyalty bar; rule 16; the Star Wars pack puts the Empire on the left | TeeJ, 2026-09-22: the bar followed faction order (Alliance left), which "will mess up long-time players awfully" against Fig 2.9 |
| 56 | **Corner glyphs** (§10 `icons`, rule 17): the sector window's four corner letters E/F/D/M and the "▲" uprising mark are pictures now - the engine's `assets/icons/` (our own silhouettes, tinted by faction) or the pack's own | TeeJ, 2026-09-22: "create the needed icons" |
| 57 | **Art sets** (§14, rule 18): the original's pictures leave the pack for the player's own art set; `art_sets`, per-faction `skin`, per-row `art`; packs load from `user://packs/` too | TeeJ, 2026-09-23: docs/original-art-plan.md, signed off |
| 58 | **`menu.monitors`** and `menu.monitor_fps` (§2): the Cockpit's monitor pictures, animated, from the art set; validated with rule 11 | TeeJ, 2026-09-23: "most of the icons are missing from the main menu" |
| 59 | **`adjective`** per faction (§3): the side as the battle sentences name it | TeeJ, 2026-09-24: the battle screens in the original's words |
| 60 | **`still`** on a `menu.monitors` entry (§2): a monitor that holds one frame | TeeJ, 2026-09-24: "lucas arts logo twitches, it does not move in the original" |
| 61 | **Brought up to date for pack authors.** "DRAFT" dropped; a *Making your own pack* section; §1's missing-field rule made accurate and `_` comments documented; §2's example is the real `pack.json`; §5 `family` a string, the unit-roles row moved to §6; §6 the real units and `weapons.json` (`kind`, per-unit weapon ranges, `observed_ranges` unread); §8 `rules.json` an array, the logistics fields and what reads them; §9 the real mission-table shape, which tables are read and which are not implemented, `available_to` read only by Assassination; §11 rules 11 and 12 in the list, 3 and 5 marked done, rules 19-22 | The pack editor's handoff (2026-09-23), item 5; TeeJ, 2026-09-24: help players make their own packs from the original, for their own use |
| 62 | **`card_image`** (§2): the picker card's picture when `map_image`'s art set is not imported; optional, never a load error when missing | TeeJ, 2026-09-24: the Milky Way on the Star Wars card before the art is imported |

---

## 14. Art sets — the original's pictures, from the player's own copy

**★ 2026-09-23 (docs/original-art-plan.md, TeeJ signed off).** The original
game's pictures are never shipped. A player who owns it exports them with
`tools/FactionWarsExporter` into an **art set** and imports that into the game;
a pack **declares** the art sets its original look comes from. A pack that
declares none - or whose art set the player has not imported - plays with the
engine's own art.

| Where | Field | Meaning |
|---|---|---|
| `pack.json` | `art_sets` | e.g. `["swr-original"]`. Known sets: `swr-original` (skins `alliance`, `empire`). |
| `factions.json`, per faction | `skin` | Which of the set's side looks the faction wears: title-bar colour, tab sets, message icons, GID stars, the Encyclopedia column. **Required when `art_sets` is declared.** A custom side can wear either: Separatists as `empire`, the Trade Federation as `alliance`. |
| any row (`characters`, `units`, `facilities`, `missions`, `map.json` planets) | `art` | `"[<set>:]<kind>/<id>"` - this row's pictures (Encyclopedia picture, portrait, miniature, mission pictures, description) are that row's in the art set. Optional: a row without it is looked up by its own id, so rows that keep the original's ids (a `shipyard`, a `mine`) need nothing. |
| `<pack>/art/...` | the pack's own pictures | The art set's layout (`portraits/<kind>/<id>.png`, ...), searched **first**. Only pictures the pack's author may share - never the art set's (the exporter's pack builder and the game's import refuse them). |
| `map_image`, `menu.image` | `"<set>:<path>"` | A picture from the art set (`swr-original:screens/galaxy.png`, `swr-original:screens/cockpit.png`). |

Where the engine looks (`src/ui/artwork.gd`): the pack's own `art/`, then for each
declared set `res://art/<set>/` (a checkout's exported folder, gitignored and
excluded from exports) and `user://art/<set>/` (imported). Nothing of an art set
is ever committed: CI fails a build that carries any. The art set's layout is the exporter's
(`tools/FactionWarsExporter/README.md`).

Packs load from `res://packs/<id>/` (shipped) and `user://packs/<id>/`
(imported; a shipped pack of the same id wins).
