# The original's save format (`SaveGame\SAVEGAME.nnn`)

Research toward importing *Star Wars: Rebellion* saves. Branch
`savegame-format`.

**Status (2026-09-27): the structure is decoded from the game's own save code;
the meaning of most fields is not yet named.**

| | |
|---|---|
| Reader | `tools/savegame/rebsave.py` — parses the whole game state; every self-offset marker is checked in sequence |
| Summary | `tools/savegame/summary.py SAVEGAME.001` — objects per class in each copy |
| Disassembly helpers | `tools/savegame/re/` (capstone + pefile, read `REBEXE.EXE` in the install folder, write nothing) |
| Binary | GOG `REBEXE.EXE`, sha256 `b3fe3997cab9a6e96403d638875dcba25484e4d8601751afec748471ac0ed6ab` |

## Verification

| Save | Markers verified in order | Parsed to | File size | Not parsed |
|---|---|---|---|---|
| `.001` (name "1", Alliance, day 5059) | 379 of 382 | 0x5CB27 | 0x6BC04 | 61 KB UI tail |
| `.002` (name "start", Empire, day 200) | 385 of 388 | 0x589A6 | 0x667D7 | 56 KB UI tail |

One wrong field length anywhere would desynchronise every marker after it, so
this is strong evidence the grammar is right up to the UI tail. Independent
cross-checks, both saves:

| Parsed | Independent source | Agrees |
|---|---|---|
| 6 major, 54 minor characters | `MJCHARSD.DAT` 6, `MNCHARSD.DAT` 54 | ✅ |
| 3 manager objects and 4 fleet containers per system | DarthTex: "three manufacturing areas", "four fleet areas" per system | ✅ |
| Object families | `GData\*.DAT` header families | ✅ |
| Header side 1 / 2 | Architect wiki: game_type 1 Alliance, 2 Empire | ✅ (not yet checked against which side TeeJ actually played) |

## Prior work checked

| Source | What it had |
|---|---|
| Architect wiki, *SaveGame* page | Header struct only. Its function addresses belong to a different build |
| DarthTex, swrebellion 4009 / 8795 (via `COMMUNITY-DIFF.md`, old repo) | Allegiance bytes 41 / 81 / C1; system ids = `SYSTEMSD.DAT`; blocks per system |
| `tdimino/open-rebellion` | Nothing: its save range is UI code, most archive files empty |

## Encoding (from the code)

| Primitive | Writer | Bytes |
|---|---|---|
| u32 | `0x5F4DB0` → `0x5F4D00` | 4, little-endian, **unaligned** |
| u16 | `0x5F4DF0` | 2 (character ratings use these) |
| string | `0x5F3590` → `0x5F38F0` | u16 length + bytes |
| marker | `0x5F4D70` | u32 = its own file offset. Load (`0x5F4D40`) checks it |

No record lengths anywhere: every class's field list is in the reader.

## File layout

| Writer | Contents |
|---|---|
| `0x411970` | name (string), 6 u32: ?, ?, single/multi, slot, side, ? |
| `0x4095B0` | marker, 4 u32 (the 2nd must be 2), marker |
| `0x41DE70` | marker, 7 u32 (4th = game day), marker |
| `0x51D2C0` game | marker; string list (`0x568A80`); 19 u32; 3 × 5 u32 (`0x539910`); then seven blocks each closed by a marker: a list (`0x536F70`), **timed events** (`0x54EB80` ×3), two lists (`0x568980`), a reference list (`0x568C80`) |
| `0x513DF0` galaxy | global reference list, then **the galaxy tree three times**: master, Alliance's copy, Empire's copy |
| `0x5685A0` | u32 1, then 50 u32 |
| `0x41DE70` cont. | marker, UI object (`0x435EC0`): 6 u32, two typed windows, u32 — **not decoded** |
| `0x4095B0` cont. | marker, `0x415F60` (1 u32 in both saves), marker. End of file |

### Timed events (`0x54EB80`)

count, then per event: type code (vtable +0x24), then the event's Save (+0x0C):

| Codes | Save | u32 after the code |
|---|---|---|
| 0x300–0x31D | `0x586470` | 14 |
| 0x320–0x321 | `0x586660` | 14 |
| 0x370–0x372 | `0x54F080` | 9 |
| 0x373 | `0x562E00` | 10 |
| 0x380–0x394 | `0x586360` | 12 |
| 0x3F0 | `0x5802F0` | 13 |

### The galaxy tree

Each object: `base` + `state` (master copy only) + class fields + `children`.

- **base** (`0x4F9450`): serial, flags, template (`.DAT` id), has-name, [name],
  7 u32. Flags: `0xC0` owner (0x40 Alliance, 0x80 Empire, 0xC0 neutral);
  `0x30` copy (0 master, 0x10 Alliance's, 0x20 Empire's). *(Owner bits: two
  sources; copy bits: from the code.)*
- **state** (`[obj+0x54]`, made by vtable slot `+0xE8`), master copy only.
- **children** (`0x53A350`): has-list; if so u32, count, marker when count > 0;
  then per child its class code (vtable +4) and the child's own object.
  The three tree roots are written without a class code.

| Class code | Kind | State (u32) | Class fields | Save |
|---|---|---|---|---|
| 0x08 | fleet | 5 | 1 | `0x4FEF70` |
| 0x10 | troop | 5 | 3 | `0x5046D0` |
| 0x14, 0x18 | capital ship, Death Star | 10 | 4 | `0x501F40` |
| 0x1C | fighter | 7 | 3 | `0x503660` |
| 0x20, 0x22–0x25 | HQ, defences | 5 | — | `0x526BE0` |
| 0x28–0x2A | manufacturing facility | 9 | 3 | `0x53ABA0` |
| 0x2C, 0x2D | mine, refinery | 9 | 6 | `0x55ACF0` |
| 0x30, 0x34, 0x35, 0x38 | characters | 13 | 8 u16, 5 u32, 16 u16, 5 u32 | `0x4EF940` |
| 0x31–0x33 | characters | 13 | same + 1 | `0x5728B0` |
| 0x3C | special force | 5 | 8 u16, 5 u32 | `0x534D20` |
| 0x41–0x73 | missions | 12 | 11 u32, 4 reference lists, 1 (+1 or 2 for 0x52/53/55/58/71) | `0x523910` |
| 0x80, 0x98, 0xF2 | sector, abode, unique | 5 | — | `0x4F29D0` |
| 0x90, 0x92 | system | 32 | 13 | `0x50E4E0` |
| 0xA0, 0xA2, 0xA4 | per-system managers | 5 + reference list | 10 u32 + string | `0x52A510` |
| 0xF1 | galaxy root | 5 | 20 (master only) | `0x518EF0` |
| 0xF3 | side | 5 | 12, two 3-u32 lists, 14, a 3-u32 list, 4 | `0x531020` |
| 0xF8 / 0xF9 / 0xFA | uniques | 5 | 5 / 4 / 2 (1 in views) | |

Reference lists (`0x4F5710`): count, then key + value per node (the global list:
key only).

## Not yet known

| | What would settle it |
|---|---|
| **Field meanings** — e.g. which of a system's 32 state words is support, energy, raw materials | Disassembling the getters that read each offset, or saves that differ by one known change |
| The UI tail: open windows and the message log | More disassembly (`0x486440`, `0x484F60`, `0x485990` and their typed lists) |
| Lists empty in both samples: game lists `0x536F70`, `0x568980`, `0x568C80`; global list | A save where they are non-empty |
