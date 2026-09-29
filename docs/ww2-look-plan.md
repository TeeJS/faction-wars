# Charter: the WWII pack's command-room look

**Status: SIGNED OFF by TeeJ, 2026-09-28.** Font downloads approved (record
their provenance). The brand art (logo, its background, splash) was
commissioned from a local artist: attribution not required; TeeJ is asking
whether the artist would like a credit. Branch `ww2-axis-allies`,
worktree `D:\Github\faction-wars-axis-allies`. The brief is TeeJ's (2026-09-28):
a restrained 1940s strategic-command look for the Axis & Allies pack, every
picture and font of documented origin, attribution linked from the Cockpit.

## The five questions

| | |
|---|---|
| **1. The one thing it must do** | With the WWII pack loaded, the Cockpit, strategic map, messages, menus, dialogs and utility windows read as **one** 1940s map room, built from **one shared set of UI pieces the pack declares**, with the world map still the largest and clearest thing on screen. |
| **2. Wrong if shipped "working" without it** | The map shrunk, covered or harder to read. Any game function, window element, wording or navigation lost. One click on a side must still start the game. Panels themed one by one instead of through the shared pieces. A picture or font with no recorded origin, or no attribution reachable from the Cockpit. The Star Wars pack looking any different. Text clipped, low-contrast or printed on texture. |
| **3. Off-limits as a workaround** | `if pack == "ww2"` or any pack-id test in `src/`. Theming WWII through the art-set / original-look code (it is laid out to the original's 640×480 pixels and keyed alliance/empire). Moving or shrinking the map for a bezel. Gameplay, rules, pack gameplay data, or the save format changed. The original game's art or any third-party copyrighted art. National or party insignia, extremist symbols, propaganda imagery. The desktop build launching a browser or shell for a link (EDR; the game's convention is "the game starts no other program"). Features the game lacks, such as map routes or a message "source" field, invented to fill a mock-up. |
| **4. Target and backup** | This branch, as **one draft PR** to `main` with a commit per phase. TeeJ merges. Git is the backup. The web build publishes as always: main → CI → GHCR → Unraid. |
| **5. Done when** | See *Verification* below. |

## What exists today (the code, read 2026-09-28)

| Fact | Where |
|---|---|
| **No Theme exists.** Colours are literals in each scene: 20 window scenes each copy a slate `TitleBar` ColorRect `(0.18,0.22,0.28)`, plus about 154 font-size overrides. | `src/ui/*.tscn`; `project.godot` has no theme key |
| The WWII pack gets the **plain look everywhere**: no `art_sets`, `menu`, `skin` or `art/` folder. | `packs/ww2/pack.json`, `factions.json`; `artwork.gd:386-406` |
| On the Cockpit, the **side buttons are the launch**: one click starts the game. | `menu.gd:89-94` |
| The side buttons are hard-coded red and green, so "Allied Powers" shows **green** although its colour is `#2a62d2`. | `Menu.tscn:137,144` |
| Load Game and View Credits are placed over the Multiplayer button's lower edge. | `menu.gd:114-131` vs `Menu.tscn:164-167` |
| Credits are plain centred labels. Nothing links anywhere. | `credits_window.gd`; `menu.gd:207-223` |
| The pack's content hash covers `PACK_FILES` only, and a save is refused only on a different pack **id**. | `faction_registry.gd:35-37, 218-240` |

## Design

### One system: `look.json` → one Godot Theme
- **`packs/<id>/look.json`** (new and optional) holds the tokens: colours, fonts, sizes, spacing, corners, borders, focus, disabled, overlay opacity, and textures. It is **not** added to `PACK_FILES`, so the content hash and saves are untouched. It is documented in SCHEMA.md and validated like the other files.
- **`src/ui/look.gd`** builds one Theme from the tokens, with a named type variation per primitive, and applies it at the root. The scenes' inline literals are replaced by those names.
- **A pack without `look.json` gets no theme at all**: every scene keeps the colours it was drawn with, so Star Wars stays as it is. Before/after captures prove it. *(Changed 2026-09-28, phase 1: was "defaults equal to today's literals". Same result, and a stronger guarantee: nothing is re-created, so nothing can drift.)*

| Primitive | Used for |
|---|---|
| Panel / Inset panel | window bodies; recessed wells (lists, readouts) |
| Title bar | every window's bar |
| Command button | command console, dialog actions, Cockpit secondary actions |
| Selected tab / rail item | message categories, window tabs |
| List row | finders, message list, theatre directory |
| Heading / Divider | section labels (display face); brass rule |
| Status chip | day, speed, alerts, unread counts |
| Document surface | dispatches, briefings, credits sheet (parchment; texture on edges and header only) |
| Tooltip | field note |
| Modal frame + dim | dialogs over a dimmed map |

### Proposed WWII tokens (checked for contrast in phase 1)

| Token | Hex | Role |
|---|---|---|
| chassis / chassis_deep | `#1b1b19` / `#111110` | frame, recessed controls |
| parchment / parchment_edge | `#e9dfc6` / `#d8c9a3` | documents, information surfaces |
| ink | `#2a2620` | text on parchment |
| text / text_muted | `#e6dcc3` / `#a59d88` | text on charcoal |
| khaki / olive / olive_deep | `#b5a67a` / `#6b6f45` / `#4a4d31` | status, structure, selected fill |
| brass / brass_dim | `#a88a4e` / `#7d6a3f` | trim, dividers, selected edge, focus ring |
| allied_blue | `#4a6a8f` → **`#6f8fb5`** | faction differentiation in chrome only. *(Phase 3: the side colours are text too - the map mode's name - so both were lightened to 4.5:1 on the chassis: Allies `#6f8fb5`, Axis `#d06a55`; `look.json` `sides`.)* |
| signal_red | `#a8322a` | urgent, losses, blocked; used as a band or fill, not as small text on charcoal |

On the map, **faction markers keep `factions.json`'s colours** (`#d22a2a` / `#2a62d2`) so they hold contrast on the paper map. Chrome uses the muted tokens. `factions.json` is not touched.

### Type (all SIL OFL 1.1)
- **Oswald**, for section labels and headers. It reworks the "Alternate Gothic" faces used on period newspapers and signage.
- **Source Sans 3**, for data and body text: humanist and very legible, with tabular figures for aligned numbers.
- **Courier Prime**, for typed dispatch headings only. Courier itself dates from 1956, so it evokes a typewriter rather than being strictly period. Body text stays in Source Sans.

Downloads requested, all from the projects' official GitHub repositories:

| File | Source | Size |
|---|---|---|
| `Oswald[wght].ttf` + `OFL.txt` | github.com/googlefonts/OswaldFont (`fonts/variable/`) | 172,088 + 4,483 B |
| `VF-source-sans-3.052R.zip` | github.com/adobe-fonts/source-sans, release 3.052R | 795,927 B |
| `CourierPrime-Regular.ttf`, `-Bold.ttf` + `OFL.txt` | github.com/quoteunquoteapps/CourierPrime (`fonts/ttf/`) | 71,188 + 72,856 + 4,403 B |

They go in `packs/ww2/look/fonts/` with their licences, each hashed and recorded as `assets/fonts/README.md` does. `export_presets.cfg` gains the licence files, because `.txt` is not exported otherwise.

### Pictures and attribution
- **No photographs.** Map fragments are crops of `world_1941.jpg`, which is public domain and already credited. Textures (paper grain and fibres, desk grain, brass rules, stamps, map grid) are **generated by a committed, seeded script** (`tools/look/make_ww2_textures.py`), so they are original and reproducible. Faction marks are typographic, not insignia.
- **Every shipped picture and font gets a structured entry**: title, author, source link, licence and licence link, changes made, files. Pack assets go in `packs/ww2/credits.json` (outside `PACK_FILES`), engine assets in `assets/credits.json`. A test fails when any image or font has no entry.
- **The attribution link:** the Cockpit's existing **View Credits** opens a designed Credits sheet (a document surface). It holds the pack's credit lines, then **Artwork and fonts**, one entry per asset with its links. On the web a link opens a new tab. On the desktop it shows the address with a Copy button, as the picker already does.

### Surfaces (restyled in place; nothing moves out of its area)

| Surface | Existing part | Treatment |
|---|---|---|
| Cockpit | `Menu.tscn` button form | Desk chassis. The campaign dossier: title, `1939–1945` context line, summary, map fragment. Choices as selector rails. **Two launch plates, "Launch as Allied Powers" / "Launch as Axis Powers"**, each still one click. Secondary row: Load Game (which has Import Game), Multiplayer, View Credits, Exit. Static grain, plus a slow light drift that respects reduced motion. |
| Top strip | `TimeControls`, `Resources` | Operations strip: labelled readouts in tabular figures, brass separators, alert states |
| Left rail | `CommsPanel` categories | Dispatch-cabinet rail. Selected = notched shape + olive fill + brass edge. Unread = chip |
| Right list | `TaskbarPanel` pins | Theatre directory. The current theatre is marked by a tab and contrast |
| Command row | bottom `HBoxContainer` | Grouped console keys, visible focus, touch-size targets |
| Map | `galaxy_map.gd` | Bezel drawn in the existing gutters. The map area is unchanged. Markers, tier flares, theatre boxes, HQ burst and hover titles as ink plotting marks with a halo for contrast. The Sector window's selection ring likewise |
| Sector window | `sector_window.gd` (phase 8) | A theatre plate: the theatre's own map under a parchment wash, or a plotting sheet where the map would blur; ink-rimmed marks in the holder's colour, names on a paper halo, paper icon tabs, ink and olive bars |
| Messages | `MessageWindow` | Dispatch paper. Scan order: subject, theatre (when the message names a system), day, then body and actions. A small device per category (intelligence stamp, ledger rule, orders band, signal tag). Conflict and battle alerts carry a signal-red band. No flashing |
| Menus, dialogs, tooltips | PopupMenus, `AcceptDialog`/`ConfirmationDialog`, tooltips | Instrument-panel menus, an order sheet over a dimmed map, field-note tooltips |
| Utility windows | finders, Encyclopedia, Economy, Defense, Fleet, Personnel | Same primitives; density drives each layout |

### Defaults taken (reversible; say if any is wrong)
- **Cockpit secondary actions are the existing four.** No Settings button is added, because the plain Cockpit has none today and that would be new navigation.
- **Map routes and selection rings are not added**, because the main map does not draw them today. Only what exists is restyled.
- **Empty-state copy goes through `display.json` `terms`**, the existing pack-wording table. WWII gets "No dispatches received"; Star Wars keeps "No transmissions.". This changes WWII's content hash only, and saves are refused by pack id, not hash.
- **Reduced motion:** the light drift is off when the browser reports `prefers-reduced-motion`. A **Reduce motion** box goes in Game Options, because Godot cannot read the Windows setting. *(Phase 2: it sits in the Cockpit's own "Game Options" group, beside the lamp it stills, and is remembered with Provide feedback.)*
- **Loading states** are restyled only where the game shows one today. None are added.

## Phases (each ends with a stop, captures and a go/no-go)

| # | Phase | Contents |
|---|---|---|
| 0 | Baseline | `tests/capture_look.gd`: Cockpit, map, a message, a dialog and a finder, for WWII, plus Star Wars plain as the regression set |
| 1 | The system | `look.json` + `look.gd` + SCHEMA/validation; fonts; the texture script; credits files + completeness test; Star Wars captures unchanged |
| 2 | Cockpit | dossier, launch plates, secondary row, Credits sheet with links |
| 3 | Map shell | strip, rail, directory, console, bezel, markers |
| 4 | Messages | dispatch surface, category devices, urgency, empty state |
| 5 | Menus, dialogs, tooltips | plus one finder as the representative |
| 6 | Remaining windows | Encyclopedia, Economy, Defense, Fleet, Personnel, the other finders, empty and loading states |
| 7 | Write-up | primitives and rationale (`docs/ww2-look.md`); the before/after sheet |
| 8 | The sector window | *(Added 2026-09-29, TeeJ: "the sector view still looks like SWR"; chose option A.)* Every element and position kept (manual p025-p026). The ground: the theatre cut from a **sharper copy of the same 1941 atlas scan** (`map_detail`, origin in `packs/ww2/look/MAP-DETAIL.md`), lined up so each system sits on its own place. **Where that map would be magnified more than 4 times** (the four small European theatres), a plain plotting sheet instead, automatically (TeeJ chose (b)). Marks, names, corner icons and bars in ink, paper and the side colours. |

## Verification
- **Captures:** before/after for the Cockpit, map, a message and a dialog or finder, at 1440×850, 1920×1080 and a compact 1024×608 window. No text clipped anywhere.
- **Star Wars unchanged:** the plain-look captures (with an empty art root) are pixel-identical before and after, and the original look is untouched.
- **Contrast:** a test computes every text/surface token pair as ≥ 4.5:1 (≥ 3:1 for large labels and UI edges).
- **Keyboard:** Tab reaches every Cockpit and console control, with a visible brass focus ring. Disabled states stay readable.
- **Nothing lost:** each restyled window is checked element by element against `docs/window-checklists.md` and its manual passage.
- **No behaviour change:** the soak gate is byte-identical, `load_resave` and `ui_smoke` pass on both packs, and a WWII save made before loads after.
- **Origins:** the credits-completeness test passes. Every link on the Credits sheet resolves.
- **Web:** a local web export shows the fonts and textures and runs at full speed.
