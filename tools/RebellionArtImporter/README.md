# Rebellion Art Importer

A small Windows utility for people who **own Star Wars: Rebellion**. It copies
the Encyclopedia pictures and descriptions out of *their* installed copy into
the Faction Wars pack, so the game can show the original artwork. The repo never
distributes that artwork: the output folder (`packs/star-wars-rebellion/original/`)
is gitignored, and the tool reads only from the folder the player points it at.

## Use

Double-click `RebellionArtImporter.exe`, check the two folders (the GOG install
and the pack folder are found automatically when they are where expected), click
**Import**. About 300 pictures and 150 descriptions are written in a few seconds.

From a script:

```powershell
.\RebellionArtImporter.exe --gamedir 'C:\Program Files (x86)\GOG Galaxy\Games\Star Wars - Rebellion' --pack 'D:\Github\faction-wars\packs\star-wars-rebellion'
```

runs without a window and writes `original\import.log` (exit 0 = done).

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

The DLLs are parsed from their bytes (`PeResources.cs`); nothing from the game is
loaded or executed, so a 32-bit DLL reads fine from this 64-bit tool and there is
nothing for endpoint protection to object to.

## Output

```
packs/star-wars-rebellion/original/
  characters/<id>.png   units/<id>.png   facilities/<id>.png
  planets/<id>.png      missions/<id>.<faction>.png (alliance / empire)
  icons/<glyph>.<faction>.png (+ .hover.png)   planet_sprites/<artwork_id>.png
  portraits/<kind>/<id>.png (80x80)   miniatures/<kind>/<id>.png (61x25)
  gid/<faction>.<tier>.png  gid/unexplored.<tier>.png  icons/uprising.png (+ .hover.png)
  alerts/<faction>.<category>.png (+ .lit.png)
  descriptions.json     { "characters": { "<id>": "text" }, "units": ..., ... }
  README.txt            the do-not-redistribute note
```

## What the game does with it

`src/ui/artwork.gd` reads the folder (or `user://original/<pack id>/` for an
exported build). The sector window shows the original's corner icons in their
own colours and the planets as their sprites, with the system name coloured by
side as the manual has it. The Character Status, Unit Status and Message windows
show the portraits; personnel lists show the miniatures. Anything the folder
lacks falls back to the engine's own art, so nothing here is required.

## Build

.NET 8 SDK. Framework-dependent, so the exe is a normal signable binary (no
single-file packing):

```powershell
dotnet publish tools\RebellionArtImporter -c Release -r win-x64 -p:SelfContained=false -o build\RebellionArtImporter
```

Sign `build\RebellionArtImporter\RebellionArtImporter.exe` with Azure Trusted
Signing before handing it out. Players need the .NET 8 Desktop Runtime; Windows
offers the download if it is missing.
