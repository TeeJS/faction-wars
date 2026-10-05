# Generic names for the Star Wars pack

`star-wars-rebellion.json` lists every Star Wars name in the base pack's
characters, ships/troops/special forces, facilities, sectors and locations, and
the name that replaces it. **It is a draft and nothing reads it yet.** It is kept
apart from the pack on purpose: apply it once the pack and id work in progress
has landed.

Each row has the following fields:

| Field | Meaning |
|---|---|
| `id` | the row's id in `packs/star-wars-rebellion/` today |
| `new_id` | a proposed id; it is the same as `id` when the id holds no Star Wars word (e.g. `ion_cannon`) |
| `from` | the current `display_name` |
| `to` | the replacement |
| `string_id` | where the player's own `TEXTSTRA.DLL` holds `from` (for sectors and locations, use the low 16 bits) |

## What was changed, and what was kept

Changed means the name holds a word Star Wars coined or a signature Star Wars
term: every character, location and sector, plus *Corellian*, *Mon Calamari*,
*Nebulon*, *CC-*, *Star Destroyer*, *Death Star*, *TIE*, *X/Y/A/B-wing*,
*Stormtrooper*, *Dark Trooper*, *Wookiee*, *Sullustan*, *Bothan*, *Noghri*,
*droid* (a Lucasfilm trademark), *KDY*, *LNR* and *GenCore*.

Kept means the name is plain English words: Bulk Cruiser, Strike Cruiser,
Victory Destroyer, Interdictor Cruiser, Guerrillas, Mine, Refinery, and the
others. They are listed under `kept_unchanged`.

A few replacements follow from the locations that were renamed, so that they
stay consistent with each other:

| Location | Becomes | Which gives |
|---|---|---|
| Corellia | Calvessa | Calvessan Corvette, Calvessan Gunship, Calvessan sector |
| Mon Calamari | Nerith | Nerithian Cruiser, Nerithian Regiment |
| Sullust | Tarrow | Tarrowan Regiment |
| Kashyyyk | Vahruun | Vahruuni Regiment |
| Bothawui | Vessar | Vessari Spies |

## How the original names come back

All 351 names the pack carries were checked against the installed game's
`TEXTSTRA.DLL` (2026-10-04) and match exactly at the row's `string_id`. The
only facility without one is Headquarters, which keeps its name anyway. The
exporter can therefore read the original names from the player's own copy,
the same way it already reads the Encyclopedia text into `descriptions.json`.
That way no Star Wars name has to ship.

## Star Wars names these lists do not cover

| Where | What |
|---|---|
| Factions | Rebel Alliance and Galactic Empire |
| Missions | Death Star Sabotage, Jedi Training, Dagobah |
| Facility ids | `turbolaser_battery`; *turbolaser* is a Star Wars word, so `new_id` handles it |
| Other text | descriptions, advisor and message text, `display.json` terms, tests and docs |
