# Art archives

The working files behind a pack's pictures: generated masters, the originals
they replaced, prompts, manifests, contact sheets and source records. They are
kept here, **outside the pack folders**, so a pack holds only what the game
uses (TeeJ, 2026-10-04). The pack editor reads every file in a pack folder, and
its Export Zip and "Make my own copy" carry them all, so a 1 GB archive inside
`packs/ww2` made every WWII mod over 1 GB.

`.gdignore` here keeps Godot from importing or exporting any of it.
`tests/pack_folders.gd` fails if an archive turns up inside a pack again.

| Here | Was (until 2026-10-04) | What it is |
|---|---|---|
| `ww2/<kind>/vintage-1940s-comic-masters-2026-10-04/` | `packs/ww2/art/<kind>/vintage-1940s-comic-masters-2026-10-04/` | The vintage 1940s comic-style redraws: 1600 x 800 masters, game-size copies, raw generations, manifests, contact sheets |
| `ww2/<kind>/backup-originals-2026-10-04/` | `packs/ww2/art/<kind>/backup-originals-2026-10-04/` | The 400 x 200 pictures those redraws replaced, with SHA-256 manifests |

`<kind>` is `characters`, `units`, `facilities`, `missions` or `locations`
(`locations` was `planets` until the same day). The manifests and archived
scripts inside are records of how each batch was made and keep the paths they
were written with. Read `packs/ww2/art/<kind>/` for the pack's folder in them.

`tools/look/make_ww2_small_from_plates.py` reads the masters here to cut the
small pictures (portraits, miniatures, map sprites).

A new batch of artwork goes in `art-archive/<pack>/<kind>/<batch>/`. Only the
finished pictures the game uses go in `packs/<pack>/art/`.
