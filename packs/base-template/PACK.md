# Base Template — the Star Wars pack, no pictures

Made 2026-10-08 (TeeJ: *"a pack of the base star wars rebellion with no images
in it ... I need the names included so we can edit them to new, non commercial
names"*). A copy of `packs/star-wars-rebellion/` that **plays the same and keeps
every name**, with the art set and everything it brings left out. Rename it
into a setting of your own.

## What is the same, what changed

| File | vs. `star-wars-rebellion` |
|---|---|
| `characters.json`, `facilities.json`, `map.json`, `mission_tables.json`, `missions.json`, `rules.json`, `setup.json`, `units.json`, `weapons.json` | **byte-identical** |
| `factions.json` | the two `skin` lines removed (a skin is an art set's side look; without `art_sets` the loader refuses one - SCHEMA.md rule 18) |
| `display.json` | `terms` lists **all 66** of the engine's words. The 30 the Star Wars pack left to the engine are written out at the engine's own default (`src/game/terms.gd`), so the screen reads the same and every word is here to rename |
| `pack.json` | new `id` / `display_name` / `summary`; `art_sets`, `card_image`, `menu`, `movies`, `music`, `advisor`, `voices`, `sounds`, `briefing`, `advice` and `report_backdrop` removed - every one is the player's art set or only applies to it. `menu.credits` became `credits`, less the Milky Way picture line |
| `credits.json` | names `blank_map.png` only |
| `blank_map.png` | **the one picture**: plain black, 640 x 480. The loader requires a map backdrop file (rule 9). It is the shape of the original's galaxy picture, so `map_image_rect` (unchanged) puts every system where the Star Wars pack does |
| `milky_way.jpg` | not copied |

## What playing it looks like

As the Star Wars pack does when played without its art set ("Continue without
artwork"), except that Play goes straight on: the engine's own art and
stand-ins, the button Cockpit, no movies, music, droid advisor, voices,
opening briefing or advice messages - and **no Encyclopedia descriptions**,
which are the art set's `descriptions.json` (`Art.Description`,
`src/ui/artwork.gd`). A pack may ship its own in `art/descriptions.json`
(SCHEMA.md section 14).

## Where the names are

Everything a player reads is a **text value**; change those freely.

| File | Fields |
|---|---|
| `pack.json` | `display_name`, `summary`, `neutral.display_name`, `victory_tips`, `credits` |
| `factions.json` | `display_name`, `adjective`, `short_name`, `loyalty_label`, `loyalty_label_short`, `agent_name`, `messenger_name` |
| `map.json` | each sector's and planet's `display_name` (20 + 200) |
| `characters.json` | `display_name` (60) |
| `units.json` | `display_name` (57) |
| `facilities.json` | `display_name` (15) |
| `weapons.json` | `display_name` (4) |
| `missions.json` | `display_name` (25) |
| `display.json` | `categories[].display_name`, each mode's `label` / `title` / `menu_label` / `control_label` and its tiers' `label`s, `special_power_ranks` ("Jedi Knight", ...), `terms` |

**Ids are names too** (`coruscant`, `luke_skywalker`, `death_star`, the faction
ids `alliance` / `empire`). They are the references between files: rename one
and every place that names it must follow (the loader refuses a dangling one -
rule 3).

**Not for the screen:** `rules.json` `Name` is for logs and debug readouts
(`RuleManager.NameOf`); `source_*` and `string_id` are provenance, the
original's table numbers (SCHEMA.md section 5); `_comment` keys are never read
as data.
