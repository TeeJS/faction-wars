# Faction Wars Exporter

A small Windows utility for people who **own Star Wars: Rebellion**. It reads
the original's pictures and text out of *their* installed copy into one file,
the **art set**, which they import into Faction Wars in the browser or on the
desktop. The repo and the web build never carry that art
(`docs/original-art-plan.md`). It also builds **faction-pack** files from a
folder, for people making their own packs.

## Use

Download `FactionWarsExporter-win-x64.zip` from the GitHub Release, unzip it
anywhere, and double-click `FactionWarsExporter.exe`. Nothing needs installing
and nothing needs admin rights.

1. **Game folder** is found automatically (see below). Change it if needed.
2. **Save to** defaults to `Documents\Faction Wars\swr-original.art.zip`.
3. Click **Export**. It takes a few seconds and writes about 1,080 files (~14 MB).
4. Import that file into Faction Wars. **Keep it**: if the browser ever forgets
   the artwork (cleared site data, a new browser or device), import the same
   file again.

Every version of the game has the same folder - the DLLs with `EData` beside
them - so any of these works as the game folder (`GameFolders.cs` looks in this
order):

| Version | Game folder |
|---|---|
| GOG | `C:\Program Files (x86)\GOG Galaxy\Games\Star Wars - Rebellion` |
| Steam | `<library>\steamapps\common\Star Wars - Rebellion`, in any library Steam lists in `steamapps\libraryfolders.vdf` |
| Old CD install | `C:\Program Files\LucasArts\Star Wars Rebellion` (manual p16), or `C:\Program Files (x86)\...` - only when `EData` is in it |
| The CD | the disc's `REBELLION` folder, e.g. `D:\REBELLION`; a mounted `.iso` works the same |

The CD's `REBELLION` folder holds the same files at the same sizes as the GOG copy
(checked 2026-09-23 against archive.org's file list of the retail disc; only
`REBEXE.EXE` differs, and only the mouse pointers come from it). The 1998 setup is
16-bit and will not run on 64-bit Windows, so CD owners export straight from the
disc. Installs from the CD usually left `EData` on the disc; if it is missing,
pick the disc instead.

### For pack authors

- **Export as folder...** writes the same art set to an empty folder, to look
  at or to work from.
- **Build faction pack...** zips a faction pack's folder (the one holding
  `pack.json`) into a file anyone can import. A faction pack is shared, so it
  must not carry the original's art: the build is **refused** if any file has
  the same contents as a file in your art set, or sits under an `original/`
  folder. Refer to the art set instead. Godot's `*.import` and `*.uid` files
  are left out.

## Command line

Runs without a window; exit code 0 = done, 1 = a problem (the log says which),
2 = failed.

```powershell
# the art-set file (log: <out>.log)
.\FactionWarsExporter.exe --gamedir 'C:\Program Files (x86)\GOG Galaxy\Games\Star Wars - Rebellion' --out "$env:USERPROFILE\Documents\Faction Wars\swr-original.art.zip"
```

```powershell
# the art set as a folder (log: <folder>\export.log)
.\FactionWarsExporter.exe --gamedir 'C:\Program Files (x86)\GOG Galaxy\Games\Star Wars - Rebellion' --folder 'D:\Temp\swr-original'
```

```powershell
# a faction-pack file, checked against the art set (log: <out>.log)
.\FactionWarsExporter.exe --build 'D:\Packs\my-pack' --out 'D:\Packs\my-pack.zip' --art "$env:USERPROFILE\Documents\Faction Wars\swr-original.art.zip"
```

Without `--art`, the build checks against the default art-set file, else reads
the art set in memory from the game folder (found, or `--gamedir`). With none of
those it warns and builds; the game checks again on import.

A development checkout keeps its own copy at `<repo>\art\swr-original` (gitignored,
and excluded from exports); run Godot's `--import` once after writing it:

```powershell
.\FactionWarsExporter.exe --gamedir 'C:\Program Files (x86)\GOG Galaxy\Games\Star Wars - Rebellion' --folder 'D:\Github\faction-wars\art\swr-original'
```

## The art-set file

A `.zip` of PNGs and JSON with `manifest.json` at its root:

```json
{ "format": 1, "kind": "art_set", "id": "swr-original",
  "title": "Star Wars: Rebellion - original artwork", "exporter": "2.1.0",
  "created_utc": "...", "files": { "portraits/characters/<id>.png": "<sha256>", ... } }
```

A faction-pack file is the same with `"kind": "faction_pack"` and the pack's id.
The game checks every hash on import.

```
characters/<id>.png   units/<id>.png   facilities/<id>.png
planets/<id>.png      missions/<id>.<faction>.png (alliance / empire, + .small.png)
icons/<glyph>.<faction>.png (+ .hover.png)   planet_sprites/<artwork_id>.png
windows/<name>.png                            tabs/<name>[.<faction>].png (+ .pressed / .grey)
buttons/<name>.png (+ .pressed / .disabled)   cursors/pointer.png, crosshair.png, hotspots.json
portraits/<kind>/<id>.png (80x80)   miniatures/<kind>/<id>.png (61x25)
gid/<faction>.<tier>.png  gid/unexplored.<tier>.png  icons/uprising.png (+ .hover.png)
alerts/<faction>.<category>.png (+ .lit.png)
screens/cockpit.png   screens/galaxy.png
descriptions.json     { "characters": { "<id>": "text" }, "units": ..., ... }
README.txt            keep it; do not share or upload it
```

Which row each picture belongs to comes from the Star Wars pack's own
`characters.json`, `units.json`, `facilities.json`, `missions.json` and
`map.json`, copied beside the exe at build time (`pack\`).

## What it reads, and how (verified against the installed game, 2026-09-22)

| Piece | Where | Key |
|---|---|---|
| Descriptions | `ENCYTEXT.DLL`, RCDATA resources | Encyclopedia id = the pack row's `string_id` − 4096 |
| Which picture | `ENCYBMAP.DLL`, a string table | the same id → `EDATA.nnn` |
| Pictures | `EData\EDATA.nnn`, 400×200 8-bit BMP | saved as PNG |
| Planets | 26 portraits shared by `artwork_id` | string 11100 + artwork_id − 1; no text |
| Missions | two pictures each | id − 4096 (Alliance), id (Empire) |
| Portraits and list miniatures | `GOKRES.DLL` bitmaps, 80×80 and 61×25 | per character, unit and facility, by the ids in `gokres_map.json` (from [open-rebellion](https://github.com/tdimino/open-rebellion)'s Ghidra-derived entity catalog; the 60 character portraits were checked by face) |
| GID stars | `STRATEGY.DLL` bitmaps 10146–10157, 10169–10181 | four sizes per side (red / green / blue) and in grey for unexplored worlds |
| Uprising flame | `STRATEGY.DLL` bitmaps 11608–11609 | two frames |
| Message Alert bar icons | `STRATEGY.DLL` bitmaps 10030–10068 | nine categories, dim and lit, per side; matched pixel-for-pixel against screenshots of the original |
| Sector-window corner icons | `STRATEGY.DLL` bitmaps 10771–10790 | factory, tower, ship, crest per side, normal + highlighted; blue = transparent |
| Planet sprites | `STRATEGY.DLL` bitmaps 10212–10237 | 26 by `artwork_id` (two ids ship no bitmap) |
| The Shuttle Cockpit | `COMMON.DLL` bitmap 20001, 640×480 | the Star Wars pack's menu picture (manual p021 Fig 2.2) |
| The galaxy map | `STRATEGY.DLL` bitmap 903, 607×437 | the map's backdrop, its edges mirrored out to 640×480 - the Star Wars pack's map frame, so `map_image_rect` places it as before |
| Window plates, parts, tabs and buttons | `STRATEGY.DLL`, `GOKRES.DLL` | every id is listed in `Importer.cs` |
| Mouse pointers | `REBEXE.EXE` cursors 3 and 4 | read as data, never run |

The DLLs are parsed from their bytes (`PeResources.cs`); nothing from the game is
loaded or executed, so a 32-bit DLL reads fine from this 64-bit tool and there is
nothing for endpoint protection to object to. The exporter starts no other
program and opens no network connection.

## Build

.NET 10 SDK. `build.ps1` publishes a self-contained win-x64 folder (a normal exe
beside its DLLs, nothing self-extracting; ~47 MB zipped) and zips it as
`FactionWarsExporter-win-x64.zip`:

```powershell
.\tools\FactionWarsExporter\build.ps1
```

For a release, sign it with Azure Trusted Signing. That needs the dlib and
`metadata.json` in `<repo>\.signing\` (gitignored; copy another signed repo's
`.signing` folder), the Windows SDK's `signtool.exe`, and a live
`Connect-AzAccount -UseDeviceAuthentication` session in PowerShell 7:

```powershell
.\tools\FactionWarsExporter\build.ps1 -Sign
```

It signs `FactionWarsExporter.exe` and `FactionWarsExporter.dll` (the runtime's
DLLs already carry Microsoft's signature), verifies both, and prints each file's
signature status.
