# Character card redraws — 2026-10-04

67 of 71 Encyclopedia cards were redrawn with the built-in AI image-generation
tool in the requested Joe Palooka / Ham Fisher newspaper comic ink style.
Hitler, Himmler, Raeder and Leclerc were rejected by the image tool and remain
unchanged; see `generation-failures.json`. No substitute image was installed.

## Files

- `game-size/<id>.png`: installed 400 x 200 cards.
- `<id>.png`: 1600 x 800 assembled masters with the original card frame enlarged.
- `generated-raw/<id>.png`: full-resolution AI output before frame assembly.
- `contact-sheet-01.png` through `contact-sheet-05.png`: all 67 reviewed cards.
- `original-sources.json`: the original source data supplied by the user.
- `generation-manifest.json`: per-person source, prompt, output path, reference and corrections.
- `installed-manifest.json`: original/final hashes, dimensions, installed status.
- `references/download-manifest.json`: attempts to retrieve full source photographs.

All original card PNGs are in `../backup-originals-2026-10-04/` with a SHA-256
manifest. Twenty-eight full-resolution source photographs were retrieved and
verified against the source SHA-1; other downloads returned HTTP 429, so those
portraits used the existing source-derived photograph on the card. Raw reference
photographs are kept in the local task cache outside the repository because some
contain the insignia the finished cards must exclude. They are not game assets.
The source photo for Student is itself a drawing; its existing likeness is retained.
Menzies uses Stewart, the man on the right of the credited 1914 source photograph.

## Attribution and licence

The historical photographs, authors, attribution and licence URLs are recorded
in `../../PORTRAITS.md`, `../../../credits.json` and each generation record. The
comic cards are adaptations of those credited sources. CC BY and CC BY-SA
attribution remains in force; CC BY-SA adaptations are distributed under the
same listed source licence. Source public-domain status is not a new claim about
the legal status of AI-generated additions. This is generated artwork inspired
by the requested comic style, not artwork authored by Ham Fisher.

## Review and restoration

All 67 finished cards were visually reviewed for likeness, framing and Nazi
symbols. Plain German clothing avoids emblems and decorations. Nimitz and
Spruance's malformed collar pins were removed; Model and Messe were reframed
with more cap headroom; Zhu De was corrected to match the younger source portrait.
Original backup hashes, 400 x 200 game size, 1600 x 800 master size and exact
exterior pixel preservation outside the portrait aperture were verified.

Only the direct `art/characters/*.png` cards were changed. The separate 80 x 80
portraits and 61 x 25 miniatures retain their original photos. `.gdignore` keeps
this archive and the original backup out of Godot imports/exports.

To restore the comic cards after running `tools/look/make_ww2_portraits.py`, copy
only `game-size/*.png` into the parent `art/characters/` folder. To restore the
original set, copy the 71 PNGs from the original backup instead.
