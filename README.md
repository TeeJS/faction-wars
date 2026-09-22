# Faction Wars

A re-implementation of *Star Wars: Rebellion* (LucasArts, 1998) in GDScript on
Godot 4.7, built as an engine that loads a **faction pack**: the setting - its
factions, characters, planets, units, missions and rules - is data under
`packs/`, and the engine selects on role tags, never on a name. It runs in the
browser, single-player against the built-in AI or head-to-head over a relay.

**Play it:** https://faction-wars.com (also https://wars.schmitzplex.com - a
second relay with its own games).

## What is here

| Path | What it is |
|---|---|
| `src/` | the game: `core`, `game` (the simulation), `command` (every player order as a logged command), `net` (lockstep session, relay client, transports), `ui`, `data` (pack loading and validation) |
| `packs/` | the faction packs. `active.json` names the one the engine loads; `star-wars-rebellion/` is the only pack so far |
| `SCHEMA.md` | the contract between the engine and a pack - the live copy; every pack file is validated against it on load |
| `data/` | the original game's binary tables (`GData/*.DAT`) as JSON - the source the Star Wars pack is built from by `tools/build-*-json.py` |
| `GAMEPLAY.md` | how the original game works, read from the manual page by page, with citations. The rulebook this port is measured against |
| `relay/` | the multiplayer relay: one Bun file, an append-only log per game, a Dockerfile, the Unraid template and the Fly config. See `relay/README.md` |
| `tests/` | headless GDScript tests and the fixtures they compare against |
| `tools/` | the runners: `run-gd.ps1` (one headless test), `soak-gate.ps1` (the AI gate), `lockstep-local.ps1` and `mp-flow-local.ps1` (multiplayer through a local relay), `feedback-local.ps1`, and the pack builders |
| `docs/` | the plans and audits: multiplayer (`m0`-`m3-plan.md`, `multiplayer-plan.md`, `multiplayer-ui-design.md`), the AI framework (`ai-framework/`), `window-checklists.md`, `FEEDBACK-PROCESS.md`, `BACKPORT-LOG.md` |
| `BACKLOG.md` | the single tracker: done, in progress, missing features, backlog, known bugs |
| `HANDOFF.md` | how the port came to be, and its status line |
| `CLAUDE.md` | the working rules for anyone - or any agent - changing this repo |

Not in the repo, on purpose: the game's `.DAT` files and DLLs, and the manual
scans (copyrighted). They live in the installed game and in the source repo.

## Where it came from

This is the GDScript port of `sol-conflict-revolution`, a C# port of the same
game. The port was made so the game could run in a browser (`HANDOFF.md` §2).
Its day-by-day simulation was proved identical to the C# original before any
rule changed here; since then **the port is the game** - rule changes land
here and are logged in `docs/BACKPORT-LOG.md` for the C# side.

The repository was `schmitz-wars` until 2026-09-22.

## Running it

- **Godot 4.7.1**, the non-Mono build, GL Compatibility renderer. Open
  `project.godot`; the main scene is `Menu.tscn`.
- **A headless test:** `.\tools\run-gd.ps1 tests\<name>.gd` (imports the project
  first if needed, hard timeout, never opens a window).
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

Tick "Provide feedback" on the New Game screen and the game shows a feedback
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
