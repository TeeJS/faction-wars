---
name: research-game-rules
description: Establish how Star Wars Rebellion actually works before implementing any rule. Use for ANY question about game mechanics, costs, rates, formulas, thresholds or behaviour - what a facility costs, how fast something builds, what gates an action, what a stat means. Runs a source hierarchy (binary .DAT tables, the in-game Encyclopedia in ENCYTEXT.DLL, manual page scans, community reverse-engineering, empirical measurement) and cross-validates. NEVER invent a rule the sources don't state.
---

# Researching how the game actually works

Two rules this exists to enforce:

**1. Never invent a game mechanic.** If the sources do not state it, say so and
stop. Do not substitute a plausible rule, and do not "flag it as a stand-in" and
ship it anyway - flagging an invention is not permission to invent.

**2. Never ask the user something you can find yourself.** Work the whole source
list below first. **Presenting options is asking** - offering "A, B or C" where
one option is "go research it" is the same failure as asking outright. Go and
research it.

When you genuinely must ask, **state which sources you checked and what each one
failed to yield.** A question without that list is not acceptable.

Run this **autonomously**, without being asked, whenever a mechanics question
comes up. Do not make the user be the researcher.

---

## Source hierarchy

Work down this list. Stop when two independent sources agree.

### 1. The original binary tables — `GData/*.DAT`

**The most authoritative source for numbers.** Costs, stats, capacities,
thresholds.

```
C:\Program Files (x86)\GOG Galaxy\Games\Star Wars - Rebellion\GData\
```

NOT in the repo (LucasArts data, and the repo is public - `*.DAT` is
gitignored). Extractors live in `data/parse_*.py` and take `--gamedir`.

Common record layout: a **16-byte header** of four little-endian uint32
`(version, record count, first family id, last family id + 1)`, then fixed-size
records of 4-byte little-endian ints.

To crack an unfamiliar table:

```python
raw = open(path,'rb').read()
hdr = struct.unpack('<4I', raw[:16])          # version, count, first, end
body = len(raw) - 16
for n in (11,12,13,14,15,16):                  # find the record width
    if body % (n*4) == 0: print(n, body//(n*4))
```
Record width is the one where `count` matches the header. Then dump every field
across all records and look at **distinct-value counts**: constant fields are
padding or flags, 200-distinct fields are ids, small ranges are enums.

Known tables: `SYSTEMSD` planets, `CAPSHPSD` capital ships, `FIGHTSD` fighters,
`TROOPSD` troops, `SPECFCSD` SpecForces, `MJCHARSD`/`MNCHARSD` characters,
`DEFFACSD` defensive facilities, `MANFACSD` manufacturing facilities,
`PROFACSD` mine+refinery, `ALLFACSD` the Alliance HQ, `GNPRTB`/`SDPRTB` rules,
`FLEETSD` fleets, `UPRIS1TB`/`UPRIS2TB` uprisings.

### 2. The in-game Encyclopedia — `ENCYTEXT.DLL`

**Best source for rules prose, placement requirements and definitions**, and it
reads straight off disk with no need to launch the game:

```bash
grep -aoE "[ -~]{30,600}" "$GAME/ENCYTEXT.DLL" | grep -i "<term>" | sed 's/  */ /g' | sort -u
```

This is how the "one unused energy point and one unused raw material point"
placement rules were found, and the decisive *"Construction yards are used to
build all types of facilities on **any system controlled by your side**"*.

`TEXTSTRA.DLL` holds strategic-layer UI strings; `ENCYBMAP.DLL` the artwork.

### 3. The manual page scans — `manual/pages/`

All 167 pages rendered at 150 dpi. `GAMEPLAY.md` is the digest with per-page
citations; `manual/ILLUSTRATIONS.md` says which figures carry rules;
`manual/PAGE-MAP.md` maps PDF page to printed page (offset varies 0-3).

**Always say "PDF pN" or "manual pN", never a bare number.**

⚠ **Figure callouts have crossing leader lines.** Reading "the upper label points
to the left box" off a 150-dpi scan produced a confidently wrong conclusion that
`parse_military.py` had its cost fields swapped. Verify field order against the
in-game window or the Encyclopedia, never against a scan alone.

### 4. Community reverse-engineering

Steam discussions (app 441550) and swrebellion.net. **Corroboration only - never
a sole source.** Players state their own uncertainty, and several report failing
to derive formulas.

Its real value is **mutual corroboration**: when community-measured rates
(mine 5, refinery 5, manufacturing 4) match `.DAT` field values exactly and
neither derives from the other, that is strong evidence.

### 5. Empirical measurement in the running game

For anything the above cannot settle. See the measurement protocol below.

---

## Reading the game

Start menu entry: **"SW - Rebellion Window Mode"** (`REBEXE.EXE -w`).
Windowed mode is also settable permanently - `FullscreenMode=borderless` in
`DDrawCompat-REBEXE.ini`, which needs **elevated** PowerShell since it lives
under Program Files.

⚠ **Computer-use CANNOT drive this game.** Clicks and keystrokes are reported
as delivered but the game does not act on them. **Screenshots work fine.** So
the division of labour is: the user clicks, Claude reads the screen and does
the recording and arithmetic. Do not make the user transcribe numbers - take
the screenshot and read it.

The **Encyclopedia in-game** states build and maintenance costs directly and is
the tiebreaker when a manual figure is ambiguous.

---

## Measurement protocol

Used to settle the maintenance formula and the production rates.

1. Launch windowed, start a game, pause immediately (`Alt+P`).
2. `Alt+O` — **Galaxy Overview** gives item / count controlled / total
   maintenance, in one screen. Use it rather than clicking planets.
3. Record: day, facility counts, and all three monitors (Raw, Refined,
   Maintenance).
4. Run **90+ days building nothing**, with the agent's Manage Production and
   Manage Garrisons **off** - they build things on their own and corrupt the run.
5. Re-read everything, and re-check the Overview to prove nothing changed hands.

**Design the run so one variable is isolated.** The scarcer facility type is the
bottleneck:

| starting position | isolates |
|---|---|
| refineries > mines | the **mining** rate (Raw stays ~0) |
| mines > refineries | the **refining** rate (Raw accumulates) |

**One run is never enough.** A single run at 14 mines / 1.04 per day supports
both "0.0746 per mine" and "flat ~1/day". Vary the input and re-measure. Two runs
at different ratios is the minimum.

Cumulative production is **Raw + Refined**, since raw converts into refined.

⚠ `game_rules.json` has `Resource Event - Frequency` and
`Natural Disaster - Frequency` entries - random perturbations are expected, so
trust the long-run average and never a single interval.

---

## Day-zero baseline — the apples-to-apples reference

Compare against these. Both read off the original at **novice difficulty,
standard galaxy** (our menu: **easy / small**), which is the agreed default for
all comparisons.

| | worlds | mines | /world | refineries | /world | maintenance |
|---|---|---|---|---|---|---|
| **Empire** | 4 | 12 | 3.0 | 20 | 5.0 | 176 avail (600 cap − 424) |
| **Alliance** | 5 (4 + Yavin) | 16 | 3.2 | 11 | 2.2 | 194 avail |

Both sides control **4 systems** (the manual's "four loyal systems"), the
Alliance getting Yavin on top. The Alliance held **three core worlds out of
five**, so both sides draw from the same slot distributions - there is no
core/rim faction split, and the apparent 20/12 vs 11/16 difference is within the
noise of samples this small.

Other confirmed day-zero facts: **capacity = 50 x min(mines, refineries)**,
verified exactly on four galaxies; both material stockpiles start at **0**; and
the maintenance monitor shows **available**, not capacity.

⚠ **Two samples cannot distinguish a rule from noise.** A per-side "asymmetry"
and a 1:1 mine/refinery ratio were both inferred from single galaxies here, and
both were wrong. Get a third before believing a pattern.

## Traps that have already cost time

- **Status windows show CURRENT state; tables hold BASE values.** A facility
  en route or idle reports `Standard Processing Rate: 0`. This caused a correct
  field to be renamed `Unknown13` and a solved rate to be declared unsolvable.
- **"Not implemented today" ≠ "cannot happen."** A grep found no facility-removal
  code, which was taken as proof facilities are never removed - while the manual
  lists five removal paths (scrap, auto-scrap on maintenance shortfall, sabotage,
  bombardment, uprising). Derive from the RULES, not from today's code.
- **Committed data can be wrong.** `planets_data.json` carries misparsed
  `BaseEnergy` (ranges to 26 against a documented cap of 15) and `BaseMaterials`
  (constant 1 for all 200 planets). Sanity-check extracted data against
  documented limits before trusting it.
- **Randomised per game vs static.** Per-planet energy and raw ratings are rolled
  at generation from the rules table, not stored in `SYSTEMSD.DAT`. Check which
  before hypothesising that something is a per-planet property.

---

## Reporting

State the confidence level explicitly, every time:

- **Confirmed** — two independent sources agree, or a measurement matched a
  prediction exactly. Cite both.
- **Single-source** — say which, and what would corroborate it.
- **Unknown** — say so plainly, say what would settle it, and **stop**. Do not
  fill the gap.

Record findings in `ECONOMY-NOTES.md` (economy) or `GAMEPLAY.md` (rules), with
the citation, so the same ground is never re-covered.
