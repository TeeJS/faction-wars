# WWII flag comic cards — 2026-10-04

- All 88 cards installed: 83 style-only cards from 67 distinct flags, plus five approved 1939 replacements.
- 88 originals backed up under ../backup-originals-2026-10-04 with SHA-256 manifest.
- game-size/: installed 400x200 copies. Root PNGs: 1600x800 masters.
- generated-raw/: unmodified ImageGen output; original-sources.json: source attribution/licences.
- generation-manifest.json: prompts, input references and output paths. Brazil uses a full-bleed reference redraw after rejecting extra-star variants.
- assembly-manifest.json: original/generated flag rectangles and region reuse.
- installation-manifest.json: installed hashes and exact pixel preservation checks.
- contact-sheet-1..6.png: all 88 installed cards for review.
- 1939-proposals/: five approved replacement designs, installed on 2026-10-04. See its README for source/licence details.
- scripts/: assembly, packaging, review-sheet and verification scripts used for this batch.
- Both this directory and the backup have .gdignore; none of these archives are shipped by Godot.
- 37x37 planet_sprites and tools/look/ww2_flags.json remain unchanged. (Later the same day the 37x37 sprites - now art/location_sprites, this folder now art/locations - were cut from these cards by `tools/look/make_ww2_small_from_plates.py flags`.)

The 83 style-only cards preserve all pixels outside the flag interiors. The five approved replacement cards preserve original frames and labels, with new parchment interiors and balanced 2:1 flags. No Nazi symbols added; Germany remains black-white-red. United States retains 48 stars; Brazil retains 21; Venezuela retains seven. Korea retains the original historical taegeuk orientation. Hawaii retains the original canton four stripe-heights tall (an early prompt note said five, but the reference and selected output retain four).

Generation: built-in OpenAI ImageGen, style-transfer and precise-object-edit. Sources and original CC licences/attribution remain applicable. Fiji derivative is shared under CC BY-SA 3.0; Spain under CC BY-SA 4.0. AI output was reviewed against original designs and source references, including counts, emblem geometry and period inscriptions.

Restore a card by copying the corresponding original from the backup. Do not run make_ww2_flags.py to regenerate these comic cards; it produces the earlier flat rendering.
