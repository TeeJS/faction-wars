# Faction Wars

A re-implementation of *Star Wars: Rebellion* (LucasArts, 1998) in GDScript on
Godot 4.7, built as an engine that loads a **faction pack**: the setting - its
factions, characters, planets, units, missions and rules - is data under
`packs/`, and the engine selects on role tags, never on a name. It runs in the
browser, single-player against the built-in AI or head-to-head over a relay.

**Play it:** https://faction-wars.com.

The original's pictures are not in this repo or the web build. A player who
owns the game exports them from their own copy with the **Faction Wars
Exporter** and imports that file, the **art set**, into the game (see *The
original's art* below). Without it the game plays in its own plain look.

## What is here

| Path | What it is |
|---|---|
| `src/` | the game: `core`, `game` (the simulation), `command` (every player order as a logged command), `net` (lockstep session, relay client, transports), `ui`, `data` (pack loading and validation) |
| `packs/` | the faction packs, `star-wars-rebellion/` and `ww2/`. The game opens on a picker with one card per pack (`PackPicker.tscn`); `active.json` is the headless default, and `--pack=<id>` overrides both. **The pack files are hand-edited; they are the contract.** Each row keeps `source_family_id` / `source_id` as its trail back to the original tables |
| `SCHEMA.md` | the contract between the engine and a pack - the live copy; every pack file is validated against it on load |
| `GAMEPLAY.md` | how the original game works, read from the manual page by page, with citations. The rulebook this port is measured against |
| `relay/` | the multiplayer relay: one Bun file, an append-only log per game, a Dockerfile, the Unraid template and the Fly config. See `relay/README.md` |
| `tests/` | headless GDScript tests and the fixtures they compare against |
| `tools/` | the runners: `run-tests.ps1` (every headless test, one line each, then the red ones), `run-gd.ps1` (one headless test), `soak-gate.ps1` (the AI gate), `lockstep-local.ps1` and `mp-flow-local.ps1` (multiplayer through a local relay), `feedback-local.ps1`, `dto-parity.ps1` (the pack hydration regression) |
| `tools/FactionWarsExporter/` | the **Faction Wars Exporter**: a signed Windows utility that reads the original's pictures and text out of a player's own installed copy into an art set, and builds faction-pack files. Released as `FactionWarsExporter.exe` on this repo's GitHub Releases (`exporter-vX.Y.Z`). See its `README.md` |
| `assets/` | the game's own pictures: the Faction Wars logo and launch-screen background (`brand/`), the splash, and the plain look's icons |
| `docs/` | the plans and audits: the art sets (`original-art-plan.md`), multiplayer (`m0`-`m3-plan.md`, `multiplayer-plan.md`, `multiplayer-ui-design.md`), the AI framework (`ai-framework/`), `window-checklists.md`, `ui-port-notes.md`, `FEEDBACK-PROCESS.md`, `BACKPORT-LOG.md` |
| `BACKLOG.md` | the single tracker: done, in progress, missing features, backlog, known bugs |
| `HANDOFF.md` | how the port came to be, and its status line |
| `CLAUDE.md` | the working rules for anyone - or any agent - changing this repo |

Not in the repo, on purpose: the original's pictures and text (the art set;
a checkout keeps its own exported copy in the gitignored `art/` folder), the
game's `.DAT` files and DLLs, and the manual scans (copyrighted). They live in
the installed game and in the old C# repo.

## Where it came from

This is the GDScript port of `sol-conflict-revolution`, a C# port of the same
game. The port was made so the game could run in a browser (`HANDOFF.md` §2).
Its day-by-day simulation was proved identical to the C# original before any
rule changed here; since then **the port is the game**. The C# repo is
reference only now - the manual scans, the strategy guide and the installed
game's files are read there, and nothing here depends on it.
`docs/BACKPORT-LOG.md` records the rule changes made here up to 2026-09-20.

The repository was `schmitz-wars` until 2026-09-22.

## The original's art

1. Download `FactionWarsExporter.exe` from this repo's GitHub Releases and run
   it on a Windows PC with the game installed (GOG, Steam or the CD). It finds
   the game and writes `Documents\Faction Wars\swr-original.art.zip`.
2. In the game, press **Play** on *Star Wars: Rebellion*. Without the art the
   artwork window opens: **Import artwork file...**, or drag the file onto the
   game. It is kept in the browser's storage (or the desktop game's user
   folder); keep the file, and import it again if the browser forgets it.
3. The game names the exporter version an art set was made with, and asks for
   a new export when the game needs a newer one (`MIN_EXPORTER` in
   `src/ui/pack_import.gd`).

## Making your own pack

A faction pack is a folder of JSON files (`SCHEMA.md` is every field) plus
any pictures the author adds. Copy a shipped pack and change what you like,
by hand or with the pack editor,
[`TeeJS/faction-wars-editor`](https://github.com/TeeJS/faction-wars-editor).
Zip it (the editor's *Export*, or the exporter's *Build faction pack...*) and
import it with the **+** card on the game's first screen. A pack may carry any
pictures, the original's included - the original came with its own editor, and
a mod is the modder's to make. The import refuses a pack only when its file is
damaged, it reuses a shipped pack's id, or the game could not load it - and
says why.

## Running it

- **Godot 4.7.1**, the non-Mono build, GL Compatibility renderer. Open
  `project.godot`; the main scene is `PackPicker.tscn`, which loads the chosen pack and goes on to its Cockpit, `Menu.tscn`.
- **A headless test:** `.\tools\run-gd.ps1 tests\<name>.gd` (imports the project
  first if needed, hard timeout, never opens a window).
- **Every headless test:** `.\tools\run-tests.ps1` (`-Match <text>` for some).
  Run one suite at a time: the tests share the project's user folder.
- **The AI gate:** `.\tools\soak-gate.ps1` - four headless soaks whose day
  hashes must match `tests/fixtures/gate/` byte for byte. A change that is
  meant to alter the AI's decisions re-baselines in the same commit and says so.
- **Web export:** the `Web` preset in `export_presets.cfg` → `build/web/`
  (gitignored). CI does this on every push to `main` and bakes the result into
  the relay image.

## Multiplayer

Two players share one relay room; every order is a command in an append-only
log, both sides hash each day, and a client that drops rejoins by name and
rebuilds from the log. The relay never runs the game. `relay/README.md` covers
running and deploying it; `docs/m3-plan.md` is the design.

The relay image `ghcr.io/teejs/wars-relay` is built by
`.github/workflows/relay-image.yml` and runs on Fly.io (`relay/fly.toml`) and
on Unraid (`relay/unraid/my-wars-relay.xml`).

## Tester feedback

Tick "Provide feedback" on the Cockpit (the new-game screen) and the game shows a feedback
panel; a note typed there goes to the relay with the day, seed, settings and
the session log (or is kept under `user://feedback/` if the relay is away). `docs/FEEDBACK-PROCESS.md` is what
happens to it from there. Reading reports takes the relay's `FEEDBACK_TOKEN`.

## Working on it

Read `CLAUDE.md` first. The short version: the manual is the spec, including
the windows it describes; research a rule before implementing it (the
`research-game-rules` skill runs the source hierarchy); never invent a rule;
label every statement as *how the game works* or *what the code does*; branch
and PR, never on `main`.

No license has been declared for this repository.
