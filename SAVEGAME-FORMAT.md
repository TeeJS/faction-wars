# The original's save format (`SaveGame\SAVEGAME.nnn`)

Research toward importing *Star Wars: Rebellion* saves. Branch
`savegame-format`.

**Status (2026-09-27): the structure is decoded from the game's own save code,
and the fields an import needs are named from the exe's own property strings.**
After the game, the human player's block is decoded too (2026-09-28): it holds
the player's message list. The AI player's block is not decoded; it is stepped
over (*The players*, below).

| | |
|---|---|
| Reader | `tools/savegame/rebsave.py` — parses the whole game state; every self-offset marker is checked in sequence |
| Summary | `tools/savegame/summary.py SAVEGAME.001` — objects per class in each copy |
| Report | `tools/savegame/report.py SAVEGAME.001` — systems, fleets, characters, build queues, sides, timers, named from the pack |
| Players | `tools/savegame/players.py SAVEGAME.001` — finds the human player's block and prints its message list |
| Disassembly helpers | `tools/savegame/re/` (capstone + pefile, read `REBEXE.EXE` in the install folder, write nothing) |
| Binary | GOG `REBEXE.EXE`, sha256 `b3fe3997cab9a6e96403d638875dcba25484e4d8601751afec748471ac0ed6ab` |

## Verification

| Save | Markers verified in order | Parsed to | File size | Not parsed |
|---|---|---|---|---|
| `.001` (name "1", Alliance, day 116) | 379 of 382; the last 3 by `players.py` | 0x5CB27, then the human to 0x616C6 | 0x6BC04 | the AI player, 42 KB (0x616C6–0x6BBF0) |
| `.002` (name "start", Empire, day 5) | 385 of 388; the last 3 by `players.py` | 0x589A6; the human 0x61EFC–0x667C3 | 0x667D7 | the AI player, 38 KB (0x589A6–0x61EFC) |

One wrong field length anywhere would desynchronise every marker after it, so
this is strong evidence the grammar is right up to the players. The human's
block has no markers of its own; it is proven by ending exactly on the file's
closing words (*The players*). Independent
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
| `0x41DE70` | marker, 7 u32 (4th = the sub-tick count), marker |
| `0x51D2C0` game | marker; string list (`0x568A80`); 19 u32 (+0x0C sub-tick, **+0x10 day**, +0x1C ticks per day, +0x20 tick in day); 3 × 5 u32 (`0x539910`); then seven blocks each closed by a marker: a list (`0x536F70`), **the scheduler's three queues** (`0x54EB80` ×3: +0xA8 timers, +0xAC, +0xB0), two lists (`0x568980`), a reference list (`0x568C80`) |
| `0x513DF0` galaxy | global reference list, then **the galaxy tree three times**: master, Alliance's copy, Empire's copy |
| `0x5685A0` | u32 1, then 50 u32 |
| `0x41DE70` cont. | marker, UI object (`0x435EC0`): 6 u32, **the two players** (each a type word and its Save: *The players*), u32, marker |
| `0x4095B0` cont. | marker, `0x415F60` (1 u32 in both saves), marker. End of file |

### Scheduler queues (`0x54EB80`)

count, then per item: type code (vtable +0x24), then the item's Save (+0x0C).
Every item starts with two u32, the **target key** (+0x3C) and six context
words; timers add the **fire day** (+0x40) and a copy of the target's timer
record (+0x44). A timer fires only if the target's record still matches, which
is how the game cancels one (open-rebellion `ghidra/notes/timer-scheduler.md`,
same build; every fire day in both saves is on or after today).

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

## Field names

### How fields were named

Every settable property has a setter that stores the field and calls a vtable
hook; a second hook further down the same vtable posts a notification and
pushes the property's **name string** (e.g. `0x511C90` pushes "SystemEnergy").
Within a class the two blocks are in the same order, so hook slot + a fixed
delta = notification slot. Anchors:

- the 32 "Invalid X value!" strings name their setter directly, and every one
  agrees with the slot alignment;
- bit flags: each bit setter passes its mask to `0x53A640`, naming the bit.

| Confidence | Fields |
|---|---|
| **Confirmed** (exe name + a second source) | character ratings (exe order = the `.DAT` base + variance ranges, 14 characters checked); system Loyalty = Alliance support % (Alliance-held systems average 80, Empire-held 26, neutral 50); the day (timer fire days); flag bits open-rebellion's timer notes also use (system Uprising, character FastHeal / CanEscape / EscapeAttempt, mission ReadyForNextPhase) |
| **exe only** | everything else named below |
| **Unnamed** | fields shown as `fNN` / `sNN` in `rebsave.py` |

### Base object (every class)

| Offset | Field |
|---|---|
| +0x18 | serial |
| +0x24 | control kind: bits 6–7 owner (1 Alliance, 2 Empire, 3 neutral), bits 4–5 copy |
| +0x2C | template (`.DAT` id) |
| +0x34 | name |
| +0x38 | Builder (key) |
| +0x3C | DestinationLocationAtDeparture (key) |
| +0x40 | bytes: DestroyedReason, DeploymentCount, DestinationCount |
| +0x44 | ETA |
| +0x50 | status bits 0–17: Usable, Created, Completed, Destroyed, Enroute, EnrouteActive, Existing, ObservedByAlliance, ObservedByEmpire, Damaged, —, HyperdriveActive, Autorouting, AutoscrapRequest, Locked, ReadyForDelete, Constructed, Deployed |

Location is the tree: an object's parent (fleet, system) is where it is. Keys
elsewhere are `class << 24 | serial`.

### Per class

| Class | Fields in save order |
|---|---|
| System | Loyalty (Alliance support %), Energy, EnergyAllocated, RawMaterial, RawMaterialAllocated, SmugglingPercent, ProductionModifier, TroopRegWithdrawPercent, **flags** (bits 0–20: Populated, Explored, Uprising, NeverBeenControlled, Battle, Blockade, Bombard, Assault, Garrisoned, Suppressing, CombatUnitFastRepair, DeathStarNearby, BattlePending, LoyaltyCausedCurrentControlKind, BattlePendingCausedCurrentBlockade, —, Uprising / Informant / Disaster / Resource incident, BlockadeAndBattlePendingManagementRequired), control kinds (packed: BattleWon, BattleWithdrew, Uprising, BattleReady), TroopRegSurplus, TroopRegRequired, ControlData |
| Character, role part | BaseDiplomacy, BaseEspionage, BaseShipyardRD, BaseTrainingFacilRD, BaseConstructionYardRD, BaseCombat, BaseLeadership, BaseLoyalty (u16); Mission, MissionSeed, ParentAtMissionCompletion, LocationAtMissionCompletion (keys); role flags (Decoy, MovingBetweenMissions, MissionRemoveRequest, MissionResignRequest, CanResignFromMission, IsDecoying, Adrift, OnMission, OnHiddenMission, OnMandatoryMission) |
| Character | Enhanced… (the same eight, u16), Force, ForceExperience, ForceTraining, LeadershipAdjustment, Injury, CommandKind, State, MissionHyperdriveModifier (u16); Encounter, TraitorDiscovered, ForceUserDiscovered, Commanding (keys); flags (Captured, CanHeal, FastHeal, —, ForceAware, ForcePotential, Healing, DiscoveringForceUser, CanEscape, EscapeRequest, EscapeAttempt) |
| Special force | the role part only |
| Capital ship | detector flags (IsDecoyed), combat flags (UnderRepair, FastRepair), HullValueDamage, allocations (4-bit fields: shield, weapon, tractor, speed, primary hyperdrive, backup hyperdrive) |
| Fighter | detector flags, combat flags, SquadSizeDamage |
| Troop | detector flags, troop flags, WithdrawPercent |
| Fleet | fleet flags: bits 4–7 Battle, Blockade, Bombard, Assault; bits 0–2 unnamed (1 on real fleets, 2 / 4 on the per-system containers) |
| Manufacturing facility | ProcFacilState, ETC, flags (Suspended, PointPresent, PointProcessed, Processing, OnStartupCycle); mines and refineries add two words and ProductionModifier |
| Build manager (0xA0 / A2 / A4) | RemainingGameObjCount, CompletedPointCount, OverflowPointCount, SeedKey, RequiredPointCount, TotalRequiredPointCount, Reserved, ProductKey, DeploymentKey, TargetKey, ProductName |
| Mission | UserID, UserID2, TaskStatus, CompletionStatus, Phase; OriginLocation, Objective, Target, TargetLocation, Leader, LeaderSeed (keys); Team, Decoys, Captives, Members (lists); flags (ReadyForNextPhase, ImpliedTeam, Mandatory) |
| Side (0xF3) | MaintState (capacity, allocated) ×3, MaintRequired, 1 unnamed (always = MaintRequired), **raw material on hand, refined material on hand, refineries waiting for raw, factories waiting for refined, the two waiting queues** (named from the code, below), 3 unnamed, ShipyardRdOrder, TrainingFacilRdOrder, ConstructionYardRdOrder, 1 unnamed, ShipyardRdDone, TrainingFacilRdDone, ConstructionYardRdDone, RecruitmentDone, VictoryConditions, 2 unnamed, a list, two timer records |

The **state block** (`[obj+0x54]`) holds the object's timer records (counter +
arm word: bit 0 armed, bits 1–15 spread, 16–31 minimum delay) and their
parameters; e.g. the base record at +0x10 is the arrival timer.

### Observed, not a rule

Rim systems carry Populated in the original's saves (27 of 70 on day 5, 29 on
day 116), while the pack marks every rim system uninhabited. Not investigated.

## What the importer established (2026-09-27)

Found while building the import (branch `original-save-import`), both saves.

| Finding | Evidence | Confidence |
|---|---|---|
| **The rules column is the galaxy root's word `x[2]`** (object `+0x64`): 0 Development, 1–3 Alliance Easy/Medium/Hard, 4–6 Empire Easy/Medium/Hard, 7 Multiplayer | `0x518DC0` → `0x513F70` → `0x53E0A0` stores `[galaxy+0x64]` in `0x6B904C`; `0x53E390` → `0x585840` reads column `c` (0..7) of a GNPRTB entry. Column order: the community editor's `GNPRTB.cs`. `.001` = 1 (Alliance Easy), `.002` = 4 (Empire Easy), each matching its header side | Confirmed (code + the side agreeing in both saves) |
| **ETA (`+0x44`) is an absolute day** | Remaining days reproduce the travel formula (`sub_55C090`): Yavin → Chandrila 96 days by formula, 95 left a day after leaving; four more pairs agree | Confirmed |
| **A moving object is filed under its destination**; `DestinationLocationAtDeparture` names where its target was when it left (a unit joining a carrier that has since moved names the carrier's old system) | every `Enroute` object in both saves | Confirmed (data) |
| **Building items are real objects** without `Completed`; a finished item still being shipped is `Completed` + `Enroute` without `Deployed`, and its `Builder` is its build manager | manager `ProductKey` / reference list name exactly those objects | Confirmed (data) |
| **Build managers**: `0xA0` facilities, `0xA2` ships and fighters, `0xA4` troops and Special Forces. `SeedKey` is the product's type (`class << 24 \| .DAT id`); the reference list holds one object per item still to build; `RequiredPointCount` is the item's refined cost | every manager with work in both saves; costs match `units.json` / `facilities.json` | Confirmed (data + pack) |
| **Unique `0xF2` is limbo**: minor characters not yet recruited (ratings all zero, status 0) and destroyed facilities | its children in both saves | Single-source (data) |
| **Missions `0x41`–`0x44` move people** (the pack's scripted `unnamed_01..04`): team of one, target = destination, the person carries its own ETA | every one in both saves | Single-source (data) |
| **Mission phases**: 4 travelling, 8 at work, 11 finished | open-rebellion `timer-scheduler.md` (timer `0x38B` acts at phase 8, `0x38C` at 11) + the saves | Confirmed |
| **Command kind**: 2 Admiral, 3 General | the names the save stores: "Admiral Screed" 2 (commanding a fleet), "General Drayson" / "General Griff" / "General Ozzel" / "General Needa" 3 (commanding a system) | Confirmed (two fields agree) |
| **Side `lc8` list**: per-type counts `(?, count, class << 24 \| .DAT id)` — the numbering of fleets and ship classes ("Fleet 9", "Imperial Star Destroyer 2") | counts match the highest numbers in the names | Confirmed (data) |
| **Side `f90`/`f94`/`f98`** are recomputed totals, not research | open-rebellion: timer `0x381` sums three per-system lists into side `+0x90/+0x94/+0x98` | Single-source |
| **Each side's chart is its own copy of the galaxy**: the master copy marks every system Explored; the Alliance's copy 32, the Empire's 31 | serials are identical across the three copies | Confirmed (structure) |
| **A side's copy is what the original shows it of a world it does not hold** — its last look, however stale, the same on every restore. `.002`: the Empire's Yavin holds Leia, Luke, Han, Wedge, Chewbacca, Dodonna, the Bothan Spies and the Alliance's Fleet 1 (the live Yavin: Fleet 2, Chewbacca, the Bothan Spies); its Umgul two planetary shields and no troops (the live Umgul: a regiment, no shields); its Chandrila 2 mines, 5 refineries, no troops. Copies of such worlds hold no missions and no unfinished objects, and their build managers are empty (remaining 0, product none, status 0) in both saves | TeeJ's screenshots of the original restoring `.002` (2026-09-28): the Yavin personnel tab, Umgul's two GenCore Level I shields, no troops at Umgul or Chandrila; repeated restores always the same | Confirmed (save + the original's screens) |
| **The live timer** for an object is the queue entry whose record copy equals one of the object's state records (both words) | open-rebellion `timer-scheduler.md` (`FUN_005862A0`); e.g. Rieekan's diplomacy: entries rec 5 and 7 on day 121, the mission's `rec20` is 7 | Confirmed |
| **Material on hand is the side's `+0x78` (raw) and `+0x7C` (refined)** — no name strings, named from the code: a mine's finished point adds 1 raw (`0x530670`), a refinery's adds 1 refined (`0x5307E0`), both reached from `0x516360` by class range (0x2C / 0x2D); a refinery takes 1 raw (`0x52FB30`), a factory 1 refined per point (`0x52FB80`); a scrapped item refunds half its cost as refined (`0x530270`, the manual's refund). `+0x80` / `+0x84` count the queues `+0x88` / `+0x8C` of refineries waiting for raw and factories waiting for refined (`0x533570`/`0x5335C0`, `0x533610`). The side's three `MaintState` pairs are min(mines, refineries) × 50, mines × 50, refineries × 50. `.001`: Alliance 1 raw / 0 refined, Empire 0 / 12; `.002`: Alliance 1 / 8, Empire 1 / 2 | REBEXE (setters `0x52EF90`/`0x52EFF0`/`0x52F050`/`0x52F0C0` and every caller); the Empire's 2 waiting in `.001` = its 2 queued refineries (class 0x2D) | Confirmed (code + data) |
| A character's own `State` field shares a name with the state block: `rebsave.py` read the field over the block. Renamed `character_state` | — | fixed |

## The players (2026-09-28)

After the UI object's 6 words come the two players, Alliance then Empire: a
type word (1 human, 2 remote, 3 AI) and that player's Save. Branch
`original-import-messages`; `players.py` and `src/data/original_save.gd` read it.

| Player | Save | Read |
|---|---|---|
| 1 human | `0x486440` | in full |
| 3 AI | `0x485990` | **not decoded** — deeply nested plans; not needed |

**Finding the human without the AI.** The file closes with a word, two markers,
a word, a marker: its last 20 bytes. Human first: read it, the next word must be
3, and the closing words must check at length − 20. AI first: at each word 1
after it, read a human block; the one that ends exactly at length − 20, with the
closing markers checking, is it. `.001` human first, `.002` human second.
Confirmed (code + an exact end in both saves).

### The human's block (`0x486440`)

| Part | Writer | Contents |
|---|---|---|
| Player base | `0x4886D0` → `0x48A8A0` | side, u32, flag (a `0x440910` object follows when non-zero — 0 in both saves, not decoded), u32, 2 u32, a typed list (`0x536F70`, types from factory table `0x6B6FE0`: type 1 = `0x440AD0`, 11 words), 6 u32, key, u32 |
| | | 2 u32 (+0x50, +0x54) |
| Message queue | `0x4BEF30` → `0x4E4EB0` | groups: id, count, u32, then that many UI messages — type (table `0x6B2FD8`, 97 types, 7 layouts), 5 u32, key, the layout's words. **Empty in both saves**, so what it holds in play is inferred: notices not yet shown |
| Screens | `0x488AC0` | 2 u32; **windows — the message list**; windows; pairs (`0x5F5DA0`: u16 count × 2 words); 3 u32; windows |
| Side view | `0x4397A0` | per-system (7 u32, 2 u16, 23 u32) and per-sector (5 u32, 3 u16, 36 u32) view records, a list of lists, typed entries `0x14`/`0x15`/`0x17`; meanings not needed |

**Windows** (`0x437720`): u16 count, then per window its type (prototype table
`0x6B1F40`) and Save. The base (`0x4C4F30`) is u32 u32 u32 u16 u32 u32 u16 u16
u16 u16 u32 u32; **its third word is the tick the window was posted**. Most
types extend `0x4C4C90`: base, title, text, 2 keys — the first key is the
object the message is about. `0x4C51F0` is the same with its keys as two words.

| Type | After the base |
|---|---|
| 1 | 5 u32, 4 reference lists, 5 strings |
| 2 | 4 u32, 2 reference lists, 2 strings |
| 8 | 2 strings |
| 3, 4, 0xC, 0x13, 0x20, 0x22, 0x2B | title, text, 2 keys, 1 u32 |
| 5–7, 0xA, 0xB, 0x18–0x1A, 0x1C, 0x1D, 0x24–0x27, 0x29, 0x2A, 0x2C, 0x2D | title, text, 2 keys |
| 9, 0xD, **0xE** (units deployed), 0x10, 0x14, 0x28 | title, text, 2 keys, 2 u32 |
| 0xF | title, text, 2 keys, 4 u32, 4 reference lists |
| **0x16** (a mission report asking "Do you wish the mission to continue?") | title, text, 2 keys, 7 u32 |
| 0x17 | title, text, 2 keys, 6 u32 |
| 0x21 | title, text, 2 keys, 3 u32 |
| 0x15 / 0x1E, 0x1F / 0x23 (`0x4C51F0`) | title, text, 2 u32, then 3 / 1 / 0 u32 |

**The saves' message lists.** `.001`: 3, all posted at tick 5022 (day 116) —
"Diplomacy Mission Report" (Sullust, about Rieekan's diplomacy mission, which
the save has active), "Ship Design Research Mission Report" (Commenor), and
"Guerrillas Deployed to Selonia". `.002`: none. The import carries them as
messages on the day posted; a tick before today is dated back by today's day
length in ticks (an importer choice — the day length follows the speed setting).

## Not yet known

| | What would settle it |
|---|---|
| What `ShipyardRdOrder` and its two siblings count exactly (the importer reads them as the research order reached: `.001` Alliance ships 1, all else 0) | A save with research done, or their readers |
| Unnamed words (`fNN`, `sNN`, the galaxy root, several side and state words) | Their setters carry no name string: reading the code that uses them |
| The AI player's block (`0x485990`) | Its typed lists' Saves — not needed for the import |
| What the human's message queue holds in play (empty in both samples) | A save taken while notices are pending |
| Lists empty in both samples: game lists `0x536F70`, `0x568980`, `0x568C80`; global list | A save where they are non-empty |
