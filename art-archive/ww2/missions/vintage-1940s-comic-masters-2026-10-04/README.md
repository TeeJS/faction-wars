# WWII mission vintage 1940s comic style redraws

> **Moved 2026-10-04** from `packs/ww2/art/missions/` to `art-archive/ww2/missions/`, so the
> pack folder holds only what the game uses. Below, "the parent directory" and
> `art/missions/` mean the pack's `packs/ww2/art/missions/`; `../backup-originals-2026-10-04/`
> still sits beside this folder.

Created 2026-10-04 with built-in image_gen at the user's request, following the approved WWII facility redraw direction. All 14 PNGs directly in art/missions were backed up, redrawn in vintage 1940s comic style, and replaced at their existing 400 x 200 size. Construction Battalion is the shared style reference.

- Original PNGs: ../backup-originals-2026-10-04/ (SHA-256 manifest.json).
- Full-resolution generated masters: this directory, original filenames.
- Installed-size copies: game-size/.
- Review image: contact-sheet.png, all 14 plates at actual game size in plate-number order, 181 through 194.
- Exact per-image prompts and source paths: generation-manifest.json.
- Original and replacement hashes: installed-manifest.json.

All artwork was redrawn through image_gen. Mechanical downsampling used System.Drawing HighQualityBicubic. Reviewed every full-resolution plate and the game-size contact sheet for caption accuracy, plate numbers, scene identity, figure poses, and vehicles. Backups and installations verified with SHA-256. Original .png.import sidecars retained; Godot can reimport changed images on its next project scan. No game session run.

The existing tools/look/make_ww2_missions.py generates the previous engineering-plate art and would overwrite this set if rerun. Restore these redraws from saved game-size masters as needed. Archival folders have .gdignore to exclude them from Godot imports.
