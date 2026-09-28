# Charter: saved games, import and export

**Status: SIGNED OFF by TeeJ, 2026-09-27 (five rows).**
Branch `savegame-format` (draft PR TeeJS/faction-wars#318). The format research
it builds on is in `SAVEGAME-FORMAT.md`.

## 1. The one thing it must do

The **Saved Games** screen (Game Options, manual p075-076) becomes the one
place to keep, bring in and send out games:

- **Five rows showing the five most recent saved games.** Hovering a row shows
  `Saved MM/DD/YYYY - Day N` (e.g. `Saved 09/27/2026 - Day 1083`).
- **The sixth row is replaced by three buttons: Import Game, Export Game and
  See all games.**
- **Import Game** opens a file dialog, **auto-detects** whether the file is an
  original *Star Wars: Rebellion* `SAVEGAME.nnn` or one of ours, and brings the
  game in. Its Saved date is the day it was imported.
  - For an original save, the game carries on from where it was: the same day,
    the same side, and the same galaxy.
  - That galaxy includes who holds each system, support, energy, raw
    materials, facilities, every fleet, ship, fighter and troop and where it
    is or is heading, every character (ratings, Force, injury, captured,
    location, mission), everything being built, research, and missions under
    way.
- **Export Game** saves **the game you are playing now** as a single file
  (format below). It is greyed from the Shuttle Cockpit, where no game is
  running, the same as the Save buttons are today. Any saved game can be
  exported from See all games.

### Saving: the name is the game's identity

The rows are always **the newest saved games, newest at the top**, by the
date and time each was last saved.

| You press Save on a row… | What happens |
|---|---|
| with its **name unchanged** | That game is **overwritten** with the game you are playing. Its saved date is now, so it moves to the **top** row. |
| after **changing the name** | A **new** saved game is made under the new name and goes to the **top** row. The row's old game is kept and moves **down** one place. If it falls off the bottom row, it is still in See all games. |
| on an **empty** row (fewer than five games saved) | A new saved game, as today |

**Example.** No other saves exist.

1. You save as "game 1".
2. Five minutes later you type "game 1 - death star" over it and press Save.
3. The rows now read, top to bottom: "game 1 - death star", then "game 1".

An **import** adds the game at the top, with its Saved date set to the import.
It never overwrites: if the name is already used, " (2)" is added to it. You
load it like any other row.

### See all games

A screen in the style of the Saved Games rows. **Every** saved game, newest
first, scrolling. One row per game, left to right:

| Save | Side icon | Name | Load | Export | Saved | Game day | Delete |
|---|---|---|---|---|---|---|---|
| as on the main screen | as on the main screen | as on the main screen | as on the main screen | to a file | `MM/DD/YYYY` | `Day N` | removes it |

- The Save and Load buttons work exactly as on the main screen.
- Delete asks first, in the original's alert box ("Delete this saved game?"),
  like Load does today.
- The column headings are in the screen's green heading lettering.
- It must look native. Someone who has never seen the game should not be able
  to tell this screen was added.

It must look native. Someone who has never seen the game should not be able
to tell the buttons or the See all games screen were added: they are built
from the original's own bitmaps and lettering, placed to this screen's grid.

This departs from the manual on purpose. p075 gives six slots, and TeeJ chose
five rows plus the buttons (2026-09-27).

## 2. What would be wrong if it "worked" without this

- **An imported original game must survive our own save and load.** A Faction
  Wars save is its command log, and a load rebuilds the game from the log's
  header (the seed). An imported game has no seed that produces it, so unless
  the header carries the imported state, its first save → load would give back
  a *freshly generated* galaxy.
- **Nothing is dropped silently.** Every object and field in an original save
  is either carried across or listed in an import report. The original has
  things we may not model, such as smuggling percent, maintenance capacity,
  each side's intelligence copy and the timer records. Each one is reported,
  never guessed.
- **No existing save is lost.** Games in today's six slots move into the new
  list, and older saves remain reachable through See all games.

## 3. Off-limits as workarounds

- Routing any of this through the **pack import** screen or its wording.
- A separate converter tool. Auto-detect is easy, so none is needed. Ours is
  JSON text; the original's file has a self-offset marker at byte
  2 + name length + 24.
- Buttons drawn by us (plain Godot buttons, invented shapes or fonts) in place
  of the original's art.
- Starting a new game and adjusting it to resemble an import.
- Any manual step beyond picking a file.
- Inventing a value or mechanic an original save does not contain
  (CLAUDE.md rule 2).
- Writing to, or depending on, the original install at run time.

## 4. Deployment target and backup

- **Target:** the game, in both the web build (served from Unraid by CI, as
  usual) and the desktop build.
  - In the browser, Import uses the browser's file picker and Export triggers
    a download.
  - On desktop, both use the system's file dialogs.
- **Without the art imported:** the plain windows that stand in for this screen
  get the same three functions.
- **Export format (my pick): one `.fwsave` file.** It is JSON text: the game's
  name, saved date, day and side, then the save itself (the command log, with
  the imported state for an imported game).
  - It is exactly what our own save holds, so an export imports back to the
    identical game.
  - It is readable and plain text, and needs no zip library in the browser.
- **Scope:** single-player games with the Star Wars pack. Original
  head-to-head saves are out of scope, since you cannot test the original's
  multiplayer.
- **Backup:** the code lives in git (worktree, branch, PR).
  - Import only reads the chosen file.
  - Moving today's six slots into the list keeps a copy of the old slot folder
    until the move is verified.

## 5. How we verify it is done

| # | Test | Pass |
|---|---|---|
| 1 | Import `SAVEGAME.001` and `.002` headless | A dump of the imported game matches `tools/savegame/report.py` line for line |
| 2 | Import original → play a day → save → load | Same day hash before and after |
| 3 | Export → import our own file | Same day hash, same name / day / side |
| 4 | Import report | Parsed objects = carried across + reported; zero unaccounted |
| 5 | The screen | Five newest games in order; hover text exactly `Saved MM/DD/YYYY - Day N`; an import shows the import date |
| 6 | Existing six slots | All six appear after the move, loadable |
| 6a | Save rules | The "game 1" / "game 1 - death star" example gives exactly that order; Save with the name unchanged overwrites and moves that game to the top; an import never overwrites |
| 6b | See all games | Every saved game, newest first, with its Saved date and Day columns; Delete asks, then removes it from both screens; Export writes a file that imports back identical |
| 7 | Normal new games | Soak gate unchanged |
| 8 | Looks native | Screenshots of the new Saved Games screen and of See all games, before you see them in play |
| 9 | You | Web build: import your `.001`, recognise your game, export it, import the export |

## Decisions

- **Five rows** (TeeJ, 2026-09-27), the sixth row's space holds the three buttons.

## Known risks

- Some original-save fields are still unnamed. If one matters, naming it
  needs more disassembly, which needs your approval each time.
- The original's random-number state cannot be carried over, so events after
  an import will play out differently. That is unavoidable, not a bug.
- Where the original tracks something we do not model, the import report
  lists it. Whether to build it is a separate question for you.
- The exact button bitmaps are not chosen yet. The design step picks them from
  the original's art and shows you screenshots before any are wired up.
