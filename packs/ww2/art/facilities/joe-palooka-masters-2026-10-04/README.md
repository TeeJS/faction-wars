# WWII facility Joe Palooka redraws

Created 2026-10-04 with the built-in image_gen tool at the user's request. All 15 root facility PNGs were backed up, redrawn in the style of Joe Palooka by Ham Fisher, and replaced at their existing 400 x 200 size. The previously generated construction battalion plate serves as the shared style reference and its replacement.

- Original PNGs: ../backup-originals-2026-10-04/ (SHA-256 hashes in manifest.json).
- Full-resolution generated masters: this directory, under the original filenames.
- Installed-size copies: game-size/.
- Review image: contact-sheet.png, all 15 plates at 400 x 200, in plate-number order.
- Exact per-image prompts and source paths: generation-manifest.json.
- Original and replacement hashes: installed-manifest.json.

Mechanical downsampling used System.Drawing HighQualityBicubic. Artistic edits were performed by image_gen. Every plate number, caption, and major scene element was visually checked in the generated images and the game-size contact sheet. Original .png.import sidecars are retained; Godot can reimport the changed images on its next project scan. No game session was run.

The existing tools/look/make_ww2_facilities.py generates the previous engineering-plate art and would overwrite these replacements if rerun. Use the saved game-size masters to restore this new set. Portraits and miniatures were outside this request and remain unchanged.

Backup and master directories have .gdignore files to keep these archival copies out of Godot's resource imports.
