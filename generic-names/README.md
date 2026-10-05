# Generic names for the Star Wars pack

`star-wars-rebellion.json` lists the Star Wars names and words in the base pack
and in the text the game shows, each with its replacement. **It is a draft and
nothing reads it yet.** It is kept apart from the pack on purpose: apply it once
the pack and id work in progress has landed.

## The sections

| Section | Rows | What it covers |
|---|---|---|
| `characters` | 60 | every character, both sides |
| `units` | 32 | ships, fighters, troops and special forces |
| `facilities` | 6 | KDY-150, LNR Series I/II, GenCore Level I/II, Death Star Shield |
| `sectors` | 20 | every sector |
| `locations` | 200 | every planet |
| `factions` | 6 | each side's name, agent droid and message droid |
| `missions` | 3 | Death Star Sabotage, Jedi Training, Dagobah |
| `weapons` | 1 | Turbolaser |
| `terms` | 15 | words rather than rows (Jedi, Force, droid, Yoda, Luke alone…) |
| `other_text` | 125 | every other text that holds one of those names or words |

The row sections (`characters` through `weapons`) use these fields:

| Field | Meaning |
|---|---|
| `id` | the row's id in `packs/star-wars-rebellion/` today |
| `new_id` | a proposed id; it is the same as `id` when the id holds no Star Wars word |
| `from` | the current `display_name` |
| `to` | the replacement |
| `string_id` | where the player's own `TEXTSTRA.DLL` holds `from` (for sectors and locations, use the low 16 bits) |

In `other_text`, `at` is a JSON path for a pack file or a line number for a
source file. `kind` is one of the following:

| `kind` | Meaning | Count |
|---|---|---|
| `player` | text the player sees: messages, labels, the pack's card, briefing captions, victory tips | 47 |
| `editor` | rule names in `rules.json` and the pack loader's error messages, which only someone editing the pack sees | 53 |
| `log` | log lines (`[Force] …`, `[Story] …`) and debug keys | 15 |
| `keep` | text that names the original game as the source of files to bring in (save import, art import, credits) | 5 |
| `id` | a code word, such as the `"droid"` command or the `turbolaser` weapon id | 5 |

## Where the new names come from

- **Locations, sectors and the Dagobah mission** come from TeeJ's
  `planet_names.txt` (250 names, 2026-10-04). Each one got an unused name with
  the same first letter where one was left (173 of 220), and otherwise the next
  unused name. Dagobah got Vorlathe. The 24 names not used are kept under
  `planet_names_spare`.
- **Five names from that list were left out** because they are too close to
  another franchise (listed under `planet_names_left_out`): Sylvaneth, Izkandar,
  Fjordell, Lorkhaan and Elvandor.
- **Characters** each hint at the original, by sound or by meaning, so a
  player can guess who each one is without the original name being used.
  TeeJ's example: Luke Skywalker → Lucas Starrunner (2026-10-04).
- **Ships and terms** are drafts. Ships and troops named after a
  planet take that planet's new name, the way the Mon Calamari Cruiser takes
  Mon Calamari's: Corellia's corvette and gunship, Mon Calamari's cruiser and
  regiment, Sullust's and Kashyyyk's regiments, and Bothawui's spies.

## What was changed, and what was kept

A name changes when it holds a word Star Wars coined or a signature Star Wars
term. On TeeJ's call (2026-10-04), Victory Destroyer and Interdictor Cruiser
change as well. Plain-English names (Bulk Cruiser, Strike Cruiser, Guerrillas,
Mine, Refinery and the others) stay, and are listed under `kept_unchanged`.
"Rebel", "Empire", "Imperial" and "hyperspace" are ordinary words and stay.

## How the original names come back

All 351 names the pack carries were checked against the installed game's
`TEXTSTRA.DLL` (2026-10-04) and match exactly at the row's `string_id`. The
exporter can therefore read the original names from the player's own copy,
the same way it already reads the Encyclopedia text into `descriptions.json`.

## How `other_text` was found, and what it may miss

It comes from scanning for a fixed list of terms: every `from` above plus about
80 Star Wars words. The scan read every string in the pack's JSON files, the
string literals in `src/**/*.gd`, and the text lines in `src/**/*.tscn`. A Star
Wars word that is not on the term list would be missed. The scan did not cover
the following, which no player sees:

- tests, docs and `tools/`
- the pack's object keys, such as `report.luke_skywalker`; these are ids and change with `new_id`
- the pack's own id, `star-wars-rebellion`

The Encyclopedia descriptions and the advisors' spoken lines are not in this
repo: they come from the player's own copy, through the art set.
