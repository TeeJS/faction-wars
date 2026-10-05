# WW2 unit redraws — 2026-10-04

> **Moved 2026-10-04** from `packs/ww2/art/units/` to `art-archive/ww2/units/`, so the
> pack folder holds only what the game uses. Below, "the parent directory" and
> `art/units/` mean the pack's `packs/ww2/art/units/`; `../backup-originals-2026-10-04/`
> still sits beside this folder.

All 77 unit PNGs were redrawn in the requested vintage 1940s comic style, with historical subject research recorded in REFERENCES.md. Original filenames, plate numbers, captions and 400 × 200 game dimensions were preserved.

- Parent directory: the 77 installed game PNGs.
- This directory: 77 full-resolution generated masters, generation-manifest.json, installed-manifest.json and six contact sheets showing every plate at its native 400 × 200 game size.
- game-size/: the exact 400 × 200 PNGs installed in the parent directory.
- ../backup-originals-2026-10-04/: all 77 original PNGs and SHA-256 manifest.json.
- .gdignore in both archive directories keeps backup and master assets out of Godot imports.

The generation manifest retains prompts, historical source URLs, chosen subject descriptions and the most recent correction prompt. Installed-manifest.json links original and redraw hashes. Mechanical resizing used System.Drawing high-quality bicubic interpolation; image content was generated and corrected using ImageGen.

Each master was visually reviewed, obvious generation errors were corrected, and all six game-size contact sheets were inspected before installation. Backup hashes were checked again before overwriting game assets. Every installed PNG was decoded, checked for 400 × 200 dimensions and matched against its staged copy. No Godot runtime preview was performed.

Aircraft variants and generic formation examples are listed in REFERENCES.md. The Zero uses Hinomaru roundels, yellow leading-edge accents and a single-pilot framed canopy. In keeping with established pack art guidance, German Nazi symbols, runes, eagles and cross insignia were omitted.

To restore: copy the 77 PNGs from ../backup-originals-2026-10-04/ into the parent units directory, preserving filenames. To reinstall these redraws: copy the 77 PNGs from game-size/ into the parent directory. Do not run the old procedural unit-art generator for these assets: it would recreate the earlier diagram illustrations.

