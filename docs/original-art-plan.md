# Plan: the original's art out of the repo, imported by owners (Option A)

Status: **done, 2026-09-23.** Every phase is complete (PRs #114-#118, the exporter-v2.1.0
release, the history rewrite and the GHCR purge). One optional follow-up is TeeJ's: the
GitHub Support ticket (see 5b).
Stop after every phase with a go/no-go read-out.

## Charter

| | |
|---|---|
| **The one thing** | A player who owns Star Wars: Rebellion sees the original look in the web and desktop game, while the public repo, the web build and the GHCR image contain none of the original's art. |
| **Wrong if shipped without** | Import once per browser, surviving restarts. A saved file that restores a lost import without re-running anything. Custom faction packs (e.g. Separatists vs Trade Federation) that use the original's UI and shared pictures (shipyards, mines) with their own characters, ships and troops. Beta testers use the same path as the public. |
| **Off-limits** | Hosting the art anywhere (Unraid, cloud storage, a private repo, GHCR). A checked-in copy "for now". Asking players to copy files into a game folder by hand. A custom pack that carries the original's art inside it. An exporter that runs a shell, opens a socket, self-extracts or ships unsigned. |
| **Deploy target** | Web: push to main -> CI -> GHCR -> Unraid (unchanged). Desktop build. The exporter: a GitHub Release asset on TeeJS/faction-wars, signed with Azure Trusted Signing. |
| **Backup** | Git covers the code. Before the history rewrite (phase 5b): a `git clone --mirror` to `D:\Backup\faction-wars\`. |
| **Done when** | See "Verification" at the end. |

## Three kinds of content

| | What it is | Who makes it | Shareable? |
|---|---|---|---|
| **Art set** `swr-original` | every picture, text and cursor taken from the player's own install | the exporter, on the player's PC | **Never.** It is the player's own copy. |
| **Faction pack** | the data (factions, map, units, characters, rules...) plus, optionally, the author's own pictures | us (Star Wars, WWII) or anyone | Yes. It contains no original art. |
| **Pack file** | one `.zip` carrying either of the above, plus `manifest.json` | the exporter, or the exporter's "build from folder" | Art-set files: player's backup only. Pack files: freely. |

A faction pack **declares** which art set it uses. The Star Wars pack becomes an
ordinary faction pack that declares `swr-original`, so it gets no special
treatment and a custom pack works the same way.

### What a faction pack declares (new, optional fields)

| Where | Field | Meaning |
|---|---|---|
| `pack.json` | `"art_sets": ["swr-original"]` | the original look switches on when the player has this art set installed; without it the pack plays with the engine's own art |
| `factions.json`, per faction | `"skin": "alliance"` or `"empire"` | which of the original's two side looks this faction wears: title-bar colour, tab sets, alert icons, GID stars, Encyclopedia column. Separatists could wear `empire`, the Trade Federation `alliance`. |
| any row (character, unit, facility, mission) | `"art": "swr-original:facilities/orbital_shipyard"` | use that picture from the art set. When omitted, the row's own id is looked up in the art set, so rows that keep the original's ids (shipyards, mines) need nothing. |
| `packs/<id>/art/...` | the author's own pictures | same layout as the art set; they come first |

Where the engine looks for a picture: the pack's own `art/` first, then the declared
art set (by `art` reference, else the same id), then the engine's plain look.

### Today's code, and what has to change

| What the code does now | Where | Change |
|---|---|---|
| Art is looked up under the **active pack's id** (`res://packs/<pack>/original/`, then `user://original/<pack>/`) | `artwork.gd:246` `_texture`, `:217` `_json`, `:183` `Description` (read in full) | look under the declared art sets instead, plus the pack's own `art/` |
| Side art is keyed by the **faction id** (`tabs/<name>.<faction>`, `alerts/<faction>.*`, `gid/<faction>.*`, `icons/*.<faction>`) | `artwork.gd:31-66` | key by the faction's `skin` |
| The original side is hard-coded as `"alliance"` or `"empire"` | `confirm_window.gd:29`, `draggable_window.gd:712`, `message_window.gd:586`, `encyclopedia_window.gd:321`, `original_ui.gd:82` (spot-checked) | read the faction's `skin` |
| Packs are found only under `res://packs` | `faction_registry.gd:15`, `:60` `ListPackIds` (read in full) | also `user://packs`, so imported faction packs appear in the picker |

## How it works for a player

1. Download **Faction Wars Exporter** (signed) from the GitHub Release.
2. It finds the game itself (GOG, any Steam library, an old CD install, the CD or a
   mounted `.iso`; `GameFolders.cs` already does this). Program Files is no problem,
   because it runs natively. Click **Export**. It writes
   `swr-original.art.zip` (~15 MB) to `Documents\Faction Wars\`. **That file is their backup.**
3. In the game (browser or desktop), click **Import pack file...** or drag the file onto
   the game. The original look appears without a reload and stays until they clear
   the site's data.
4. Lost it, or moved to a new device or tablet? Import the same file again. On a tablet:
   copy it via iCloud or Google Drive, then tap Import.
5. Custom faction pack: import its pack file the same way. If it declares
   `swr-original` and the art set is installed, it wears the original look.

## Phases

### Phase 0: inventory (no code)
- Original-derived files in the repo:
  - `packs/star-wars-rebellion/original/`: 2217 files, 14.7 MB, commits `947ab66` through `28867e7`.
  - `packs/star-wars-rebellion/cockpit.png`: "the original's Cockpit, cropped" (`9d4845f`).
  - `packs/star-wars-rebellion/galaxyShaded.bmp`: came with step 3 (`961029e`); its source is **unverified** and it is treated as the original's until shown otherwise.
  - `assets/icons/*.png` are ours (drawn by `tools/draw_corner_icons.py`, `6e13257`).
- Find the DLL bitmaps behind the cockpit and the galaxy map, so the exporter can produce
  them. If there are none, the Star Wars pack falls back: the button menu (the `menu`
  field is optional) and a map with no backdrop.

**Phase 0 results (2026-09-23, done):**

| File | Source in the player's install | How it was confirmed | What the exporter writes |
|---|---|---|---|
| `cockpit.png` (1442x1080) | `COMMON.DLL` bitmap **20001**, 640x480 | shrunk to 640x480, it differs from 20001 by 4.6/255 on average; the rest is the scale-up and the scrubbed brackets (`5918997`) | 20001 as it is. The `menu` regions are in picture pixels and scale with the picture, so the pack's rects need scaling by 640/1442. |
| `galaxyShaded.bmp` (640x480) | `STRATEGY.DLL` bitmap **903**, 607x437 | template match at (0,0) at 1:1: the same spiral and star field, visually identical in shape. It is an **edited** copy: shaded bluer and extended by 33 px right and 43 px down (7% of pixels identical). The edit's source is unknown. | 903 with its edges mirrored out to 640x480 (exporter 2.1.0), so `map_image_rect` is unchanged and the map sits exactly where it did. The bluer shading is lost; it looks like the original's own map. (First planned as rect scaling; that zoomed the map 5% and left a strip, so it was changed.) |
| `packs/star-wars-rebellion/original/` | the importer's output (all traced to DLL ids in `Importer.cs`) | by construction | the art set |

Nothing else original-derived is committed: all 9 images outside `original/` were
checked (the 5 corner icons and the splash are ours, `world_1941.jpg` is public domain),
and no other media type (fonts, video, audio, gif, svg) is in the repo.
Full-screen bitmaps in the install, for later use: `COMMON.DLL` 10100-10103, 20001-20002;
`STRATEGY.DLL` 900-903; `TACTICAL.DLL` 1000.

### Phase 1: the exporter (`tools/RebellionArtImporter`, renamed)
- Outputs:
  - an art-set pack file (the default);
  - a folder (for authors and TeeJ's checkout);
  - "build pack file from folder" for faction packs. It **refuses a faction pack that contains any file matching the art set's hashes** (the leak guard).
- Its existing headless mode stays, with new flags `--out <zip>`, `--folder <dir>` and `--build <dir>`.
- Retarget from .NET 8 to .NET 10 LTS: .NET 8 support ends 2026-11-10; 10 runs to 2028-11-14.
- Signed with TeeJ's existing Azure Trusted Signing identity, locally.
- Still only reads the DLLs' bytes; it runs nothing from the game.

### Phase 2: art sets and skins in the engine
**Done 2026-09-23** (`tests/art_sets.gd`, `tests/pack_validation.gd` rule 18). The member is
`ArtSkin` in code (`Skin` is a Godot class); the JSON key is `skin`. Packs also load from
`user://packs/` already (phase 3 fills it). SCHEMA.md section 14.

- `pack.json` `art_sets`, `factions.json` `skin`, row `art` references, and the pack's own `art/` folder. SCHEMA.md and the validator get the rules.
- Replace the five hard-coded `"alliance"`/`"empire"` sites and the faction-keyed art lookups with `skin`.
- The Star Wars pack declares `art_sets: ["swr-original"]` and skins its two sides.
- TeeJ's checkout keeps working: `art/swr-original/` at the repo root, gitignored, which the exporter's folder mode writes.
- Tests: a tiny two-faction fixture pack (new factions with swapped skins, a shipyard by original id, one row by `art` reference, one character with its own picture) renders the original look. Without the art set it falls back.

### Phase 3: import in the game (web and desktop)
**Done 2026-09-23** (`src/ui/pack_import.gd`, `tests/pack_import.gd`, `tests/pack_picker.gd`).
Checked in a real browser (the Browser pane, a web export without the committed art):
the Import button imported the exporter's 1,082-file set; it survived a reload, a
re-import replaced it, Remove survived a reload, and with it gone the game fell back
to the button menu and the plain map in the same layout. Drag and drop was not
exercised in the browser (the engine's own drop handler feeds the same import).
The exporter (2.1.0) mirrors the galaxy map's edges out to 640x480 so the map keeps
its placement.

- An **Import pack file...** button on the pack picker. Drag and drop anywhere (the web build accepts dropped files; `display_server_web.cpp`). Desktop uses the native file dialog. Web uses the browser's file picker, which works on tablets too.
- Unzip, check `manifest.json` and every SHA-256, then write:
  - an art set to `user://art/<set>/`;
  - a faction pack to `user://packs/<id>/`, which the picker lists.
- Refuse a faction pack carrying art-set files (the same leak guard).
- Ask the browser to keep the storage (`navigator.storage.persist()`).
- Show each art set's status: installed, file count, date. Add **Remove**.
- Tests: an import round trip, a bad manifest refused, a hash mismatch refused, Remove clears it.
- TeeJ checks the browser build and a tablet.

### Phase 4: a real custom pack (optional proof)
**Done 2026-09-23** in the browser (web export, no committed art). A "Separatists vs
Trade Federation" pack made from the Star Wars JSON: its sides renamed and recoloured,
the Separatists with skin `empire` and the Trade Federation with `alliance`, map and
Cockpit from `swr-original`, one `art` reference and one picture of its own. The
exporter's Build faction pack made the file (checked against the art set: clean), the
picker imported it beside the art set, and it played: the Separatists' worlds as the
Empire's green stars with the Empire's icons, the Trade Federation's Coruscant in the
Alliance's red, and the original's sector window. The generator is not committed; the
same pack is built in `tests/art_sets.gd`.

- TeeJ's Separatists vs Trade Federation, or a minimal one: imported from a pack file into the web build, wearing the original look.

### Phase 5: take the art out (destructive; a separate go for each step)
- **5a (a normal PR):** **Done: #117, merged 2026-09-23** after the exporter-v2.1.0 release; its CI
  build passed both art checks. The picker's download link went in with it; #118 added the
  exporter's version to its title and the picker, and `MIN_EXPORTER` (2.1.0) to the game. Also: the Star Wars `pack.json` takes
  `swr-original:screens/galaxy.png` and `swr-original:screens/cockpit.png` (menu rects divided by
  2.25, x less 1: cockpit.png was 20001 at x2.25 from x 1); Artwork's legacy roots are gone; the
  exporter's `--pack` mode is refused (a checkout uses `--folder <repo>\art\swr-original`).
  It was merged only after the exporter release was published, so the testers always had a
  way to get the art.
  - delete the Phase 0 files and re-ignore them;
  - add `export_presets.cfg` exclusions;
  - add a CI step that **fails the build** if anything from the art set is in the export.
  - After merge, the beta testers import their file.
- **5b (history rewrite):** **Done 2026-09-23.**
  - Backup: `D:\Backup\faction-wars\faction-wars-20260923-1518.git` (a full mirror: 27 branches,
    the tag, 118 PR refs).
  - `git filter-repo --invert-paths` on `packs/star-wars-rebellion/original/`, `cockpit.png`,
    `galaxyShaded.bmp` (both under the pack and the old `data/`) and their `.import` files.
    Every art path that ever existed was checked first.
  - Checked before the push:
    - no art object left;
    - every branch and tag differed from the old only by those paths;
    - main's tree was byte-identical;
    - 7 art-only commits dropped (391 to 384);
    - the pack went from 14.7 MB to 3.3 MB.
  - The agent's force-push was blocked by its permissions, so TeeJ pushed all 27 branches and
    the tag. Main is now `fa9206d`, and the exporter-v2.1.0 release followed its tag.
  - Checked after the push: a fresh clone holds no art object, GitHub lists no commit touching
    `original/`, and CI passed on `fa9206d`. TeeJ's checkout was reset to the new main.
  - **Still open (optional, TeeJ):** the old commits stay reachable by SHA through PR refs
    #1-#118 until GitHub Support dereferences them. The first changed commit is `961029e`
    (it added the old galaxy map), so all 118 PRs are affected. Support handles "sensitive
    data" at its discretion and may decline artwork.
- **5c (GHCR):** **Done 2026-09-23.** TeeJ ran the purge script (scratchpad `ghcr-purge.ps1`),
  granting the gh token `read:packages,delete:packages` for the run only.
  - 159 versions were deleted, every build from before #117.
  - Kept: `latest` and the builds of `fa9206d`, `58d3b4b` and `68a7ab5`, each of which passed
    the CI art check.
  - Confirmed anonymously against the registry: those 4 tags are all that remain, and `latest`
    pulls. Unraid keeps pulling `latest`.

## Not in this plan
- **Cutscenes:**
  - `MDATA`: 368 MB, 15 Smacker videos.
  - Godot plays only Ogg Theora, so the exporter would convert them.
  - In the browser they must go in the browser's private file storage, read on demand. Godot's `user://` holds everything in memory, which is fine for 15 MB of pictures and wrong for video.
  - This needs its own plan.
- **Extraction inside the browser** from raw game files, for owners without Windows. Only if needed.
- **Touch controls:** right-click is used in 11 places and needs a long-press; also the tablet layout.
- **BACKLOG:** ships and fleets named like the original; message subject pictures.

## Decisions (TeeJ, 2026-09-23: all as recommended)

| # | Question | Decided |
|---|---|---|
| 1 | Does the Star Wars pack's **data** (the JSON) leave the repo too? | No, not in this plan. It is hand-edited engine data, and the game must stay playable without an import. |
| 2 | The cockpit and galaxy map | They go with the art (phase 0 finds their sources; otherwise the fallbacks above). |
| 3 | Exporter packaging | .NET 10, self-contained folder zip: no runtime install and no admin. Size to be measured in phase 1. |
| 4 | Signing | Locally with the existing Azure Trusted Signing identity. A CI service principal is a user-only setup step. |
| 5 | Mirror backup location before 5b | `D:\Backup\faction-wars\faction-wars-<yyyyMMdd-HHmm>.git` |

## Verification (results 2026-09-23 in brackets)
- Fresh browser profile, no import: the engine look everywhere, no errors. [yes: button menu, plain map in the same layout]
- Import the art-set file: the original look without a reload. Close and reopen the browser: still there. [yes, Browser pane]
- Clear the site's data: gone. Re-import the saved file: back. [Remove survived a reload; a re-import replaced the set]
- A tablet imports it through the file picker. [not tested]
- The fixture custom pack with new factions: the original look with its skins. The shipyard shows the original's picture, and its own character shows its own picture. [yes: tests/art_sets.gd, and phase 4 in the browser]
- A faction pack containing an art-set picture is refused by the exporter and by the game. [yes, both]
- CI fails a build containing any art-set file. After 5b, `git log --all` over those paths is empty. After 5c, no GHCR version contains them. [the guard pattern matched real art paths and passed an art-free pck; 5b and 5c as above]
- The exporter: `Get-AuthenticodeSignature` reports Valid, and SmartScreen names the publisher. [Valid, CN=Thomas Schmitz; SmartScreen not observed]
