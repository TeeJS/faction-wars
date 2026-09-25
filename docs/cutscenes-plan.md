# Plan: the original's cutscenes in the game

Status: **proposed, 2026-09-25** - awaiting TeeJ's sign-off on the charter and the
decisions at the end. Nothing is built. Stop after every phase with a go/no-go read-out.

TeeJ, 2026-09-25: "please generate a plan for bringing the cut scenes into the game".
`docs/original-art-plan.md` left them out on purpose ("This needs its own plan").

## Charter

| | |
|---|---|
| **The one thing** | A player who owns Star Wars: Rebellion sees the original's movies at the moments the original plays them - the opening, the credits, the Death Star's work, victory and defeat - taken from their own copy, in the desktop and the web game. |
| **Wrong if shipped without** | The movies at the right moments (a movie player with no triggers is not the feature). Skipping by click or Esc (manual p022). The game clock stopped while one plays. Working with no movies imported (the game as it is today). |
| **Off-limits** | Any movie in the repo, the web build, the GHCR image or any server of ours (the art-set rule). An exporter that runs a shell or another program (e.g. spawning `ffmpeg.exe`) - EDR. A movie triggered by a guess: an unmapped movie stays unplayed until its moment is known. |
| **Deploy target** | The exporter (a new version, signed, GitHub Release) makes a **movies file**; the game imports it like the art set. Desktop and web. |
| **Verified by** | Each mapped movie plays at its event in a real game (desktop and browser), skips on click/Esc, the clock resumes; with no movies file nothing changes; the web page's memory stays reasonable with the file imported. |

## What the original has (measured on the GOG copy, 2026-09-25)

`MDATA\`: **15 Smacker (SMK2) movies**, 345 MB, 15 fps, 640x324 (widescreen; `MDATA.000`
640x480), 11 kHz 16-bit stereo sound - about 25 minutes. Also `MDATA.300`-`315`: 16 WAV
music tracks (mono, 30-150 s each), not movies (see *Related*).

What each shows, from stills across its length (the movie itself is the source; the
moment it plays is a second question, answered in the next table):

| Movie | Length | Shows |
|---|---|---|
| `000` | 17 s | the LucasArts and Coolhand logos |
| `001` | 2:49 | the STAR WARS title, the opening crawl ("It is a dark time for the Rebellion..."), a fleet battle, opening credits |
| `003` | 0:55 | a Lambda shuttle leaves orbit and lands in a desert city |
| `004` | 0:58 | a Lambda shuttle flies into a Star Destroyer's hangar past stormtroopers |
| `005` | 2:00 | the full credits, cast included ("Special Thanks to George Lucas") |
| `101` | 0:22 | the Death Star fires on a planet; it explodes |
| `102` | 0:58 | TIE fighters attack Cloud City; it explodes and sinks |
| `103` | 1:05 | a Rebel fleet over a city-world; fighters attack its towers |
| `104` | 0:45 | inside the Death Star: its reactor, a countdown ("27"), a fighter escapes, it explodes |
| `105` | 2:20 | a battle, then the crawl "The yoke of Imperial tyranny has been removed... United in victory" |
| `106` | 2:05 | C-3PO and R2-D2 at the Command Center, then "The Alliance is doomed... The Emperor's reign is secure" |
| `107` | 2:37 | the Imperial Command Center, then "Your failure is now complete. The Galactic Empire lies in ruins... The Emperor and Lord Vader are lost" |
| `108` | 1:55 | Star Destroyers crush a Rebel ship, then "This insignificant Rebellion has been crushed..." |
| `201` | 0:39 | an X-wing trench run; the Death Star explodes |
| `202` | 0:22 | an X-wing trench run; no explosion |

## When each plays (game) and what our game has (code)

| Movie | When the original plays it | Confidence | Our event (code) |
|---|---|---|---|
| `000`, `001` | at launch, before the Cockpit ("To skip the introductory graphics, click the mouse", manual p022) | **Single-source** (the manual names intro graphics; the movies are the only candidates) | the game's start (`PackPicker` -> Cockpit) |
| `005` | the Cockpit's **View credits** | **Inferred** (the only credits movie; the Cockpit has a credits region) | `menu.gd` credits action (text credits today) |
| `003` / `004` | after **Start the game as the Alliance / Empire**: the shuttle to the side's command post | **Inferred** from content; TeeJ can confirm in one start per side | the Cockpit's start actions |
| `101` | the Death Star destroys a system (manual p124) | **Confirmed** (manual event + content) | `BombardmentManager` `DestroySystem` |
| `104` | a Death Star Sabotage mission succeeds (manual p124, p106) | **Confirmed** (manual event + content) | `mission_manager.gd` Death Star Sabotage result |
| `201` | the Death Star is destroyed by a fighter "Death Star run" in a tactical battle (manual p124) | **Inferred** from content | **not found** in the tactical code (searched "Death Star run", "superweapon"; not read in full) |
| `202` | a Death Star run that fails | **Unknown** - inferred only | as `201` |
| `105` / `108` | the Alliance / the Empire wins | **Confirmed** (the crawl says so) | `victory_manager.gd` |
| `106` / `107` | the Alliance / the Empire loses | **Confirmed** (the crawl says so) | `victory_manager.gd` |
| `102` | **unknown** (Cloud City destroyed: an HQ? a system destroyed by other means?) | **Unknown** | - |
| `103` | **unknown** (a Rebel assault on a city-world: Coruscant captured?) | **Unknown** | - |

Sources checked for the moments: the manual (GAMEPLAY.md: p022, p090, p106, p124), the
movies' own content, open-rebellion's notes (`agent_docs/game-media.md` calls 101-108
"story event cutscenes" with no triggers; its plan maps victory/defeat to 201/202, which
the crawls in 105-108 contradict - its docs are its own choices, not findings). **What
would settle the rest:** TeeJ playing the original to those moments (a screenshot of the
movie's first frames names it), or - only with TeeJ's approval (CLAUDE.md 1a) - the
binary's calls into its movie player.

## How

### 1. The pack says which movie plays at which event

The movies are the setting's, so the pack maps engine events to art-set references, the
way `menu` and `map_image` do (SCHEMA.md gets the field and a validator rule):

```json
"movies": {
  "launch": ["swr-original:movies/000.ogv", "swr-original:movies/001.ogv"],
  "credits": "swr-original:movies/005.ogv",
  "start.alliance": "swr-original:movies/003.ogv",
  "start.empire": "swr-original:movies/004.ogv",
  "system_destroyed": "swr-original:movies/101.ogv",
  "superweapon_sabotaged": "swr-original:movies/104.ogv",
  "victory.alliance": "swr-original:movies/105.ogv",
  "defeat.alliance": "swr-original:movies/106.ogv",
  "defeat.empire": "swr-original:movies/107.ogv",
  "victory.empire": "swr-original:movies/108.ogv"
}
```

Engine events are named by role, never by Star Wars name (`system_destroyed`, not "Death
Star"). A pack without `movies` (WW2) plays none. Unknown moments (`102`, `103`, `202`)
stay out of the map until known.

### 2. The exporter converts the movies (Godot plays only Ogg Theora)

Godot 4 plays **Ogg Theora** (`VideoStreamTheora`) and nothing else, so the Smacker files
are converted once, on the player's PC, by the exporter. Measured with a test conversion
of `MDATA.101` (22 s): Theora quality 5 -> 0.77 MB, quality 7 -> 1.45 MB, about 4x
faster than real time. **All 15: ~52 MB at q5, ~100 MB at q7**, ~6-7 minutes to convert.

| Option | What | For | Against |
|---|---|---|---|
| **A** | Link FFmpeg's libraries in process (LGPL shared build, P/Invoke) | one library decodes Smacker and encodes Theora/Vorbis; proven | +40-80 MB exporter; LGPL notices; a large native dependency to sign |
| **B** | Run `ffmpeg.exe` | simplest | **off-limits**: spawning a program is an EDR red flag |
| **C (recommended)** | Decode Smacker in C# (the format is public; FFmpeg's `smacker.c` is ~1,000 lines to port) and encode with **libtheora/libvorbis/libogg** (Xiph, BSD, ~1 MB of DLLs, P/Invoke) | small, permissive licence, in process, every DLL signable with the existing Azure Trusted Signing | the most work: a decoder port and its tests (checked frame-for-frame against FFmpeg's output here, as a dev-only reference) |
| **D** | Decode Smacker to a frame sequence and play it with our own player | no video codec | ~450 MB for 25 minutes; too big for a browser |

### 3. A separate movies file

The art set is ~14 MB and the web game keeps `user://` in memory; 50-100 MB of movies must
not ride along with it. So the exporter writes a **second, optional file**,
`swr-original.movies.zip` (manifest `kind: "movies"`), and the game imports it the same way
(the artwork window gains "Import movies file..."; `pack_import.gd` gains the kind).

- **Desktop:** written to `user://movies/<set>/`, played from disk.
- **Web:** kept out of Godot's in-memory `user://`: the movies go to the browser's own
  storage (OPFS/IndexedDB through `JavaScriptBridge`), and one movie is copied into
  `user://` only while it plays, then deleted. Measured target: page memory +<=15 MB while
  a movie plays, +0 otherwise. Web is phase 5 so desktop ships first.

### 4. The player

One `MoviePlayer` scene: black full-screen, the 640x324 frame scaled to fit
(letterboxed, nearest), click or Esc skips (a sequence skips one movie at a time, as the
original's intro), the game clock paused while it plays and restored after, a movie
missing from the file skips silently. Triggered from the events above; victory/defeat
play before the result screen.

## Phases (stop after each)

| # | Phase | Done when |
|---|---|---|
| 0 | **Settle the moments** - TeeJ confirms 003/004/005 (one start per side, View credits) and, if he wants them, the unknowns (102, 103, 202) by playing the original | the table above has no "Inferred" left for what we map |
| 1 | **Exporter: Smacker decoder** (C#) with a dev-only check against FFmpeg's decoded frames | every frame of all 15 movies matches (PSNR, stated) |
| 2 | **Exporter: Theora/Vorbis encoding + the movies file** (option C), signed; exporter 2.5.0 | a movies file of ~52 MB (q5; TeeJ picks the quality) that Godot plays |
| 3 | **Game: import + player + pack field** (desktop) - `movies` in SCHEMA.md and the validator, the import kind, `MoviePlayer`, the launch and credits movies | tests: the pack field validates, the import round-trips, the player skips and restores the clock; TeeJ sees the intro on desktop |
| 4 | **Game: the event triggers** - start per side, system destroyed, sabotage, victory/defeat | a test per trigger (the event fires the right movie, once); TeeJ sees them in play |
| 5 | **Web** - browser storage, one movie at a time | the web game plays them; memory measured as above |

## Decisions for TeeJ

| # | Question | Recommendation |
|---|---|---|
| 1 | Converter: A (FFmpeg libraries) or C (own Smacker decoder + Xiph libraries)? | **C**: smallest, BSD, no big native blob; A if speed to ship matters more than size |
| 2 | Quality: q5 (~52 MB total) or q7 (~100 MB)? | **q5** to start; the originals are 15 fps, 11 kHz - look at both on one movie first (phase 2) |
| 3 | Movies as a separate optional file, or inside the art set? | **Separate** (browser memory, and not every player wants 50+ MB) |
| 4 | Map only what is confirmed, or also the inferred ones (003/004/005) before phase 0? | **Confirmed only** until TeeJ's check (the charter's no-guess rule) |
| 5 | A Game Options switch to turn movies off? | Only if the original has one - **check the original's Game Options screen first** (not in our notes) |

## Related, not in this plan

- **The music:** `MDATA.300`-`315` are 16 WAV tracks (mono, 11 kHz, the score). Playing
  them (when, looping, the Sound options) is its own plan; the exporter could carry them
  in the same movies file.
- **The Death Star run** in tactical battles (the event for `201`/`202`) is not in our
  tactical code as far as searched; the movie waits on that feature.
