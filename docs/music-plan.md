# Plan: the original's music in the game

Status: **phases 1-2 built, phase 0 partial, 2026-09-26.** Decision 1 answered - TeeJ: "yes to
including the music with the art". Decision 3 answered - TeeJ approved reading the game's code and
Rebellion 2 (findings below; the in-game selector is not read yet). Decision 2 is open; until it is
answered only the confirmed menu track plays.
BACKLOG #41 (sound: music and sound effects); `docs/cutscenes-plan.md` left the music for
its own plan. This plan is the music only; the sound effects are a separate question.

## Charter

| | |
|---|---|
| **The one thing** | A player who owns Star Wars: Rebellion hears the original's score where the original plays it - from their own copy, desktop and web. |
| **Wrong if shipped without** | Game Options' **Play Music** and **music volume** working (manual p076 Fig. 3.16 - they are greyed today). Music never talking over a movie. The game unchanged without the music imported. |
| **Off-limits** | Any music in the repo, the web build or our servers (the art-set rule). A track played at a moment we guessed. |
| **Deploy target** | The exporter writes the music into a file the game imports (decision 1); desktop and web. |
| **Verified by** | Each mapped track plays at its moment; Play Music off silences it; the volume slider changes it; nothing plays during a movie. |

## What the original has (measured on the GOG copy, 2026-09-26)

`MDATA\MDATA.300`-`315`: **16 WAV files, mono, 11,025 Hz, 16-bit, about 18 minutes in all**. Every
track fades out at its end - they are pieces, not seamless loops. What each is, from
MetasharpNet's editor (`medias/MDATA/readme.txt`, which names the John Williams cue and
timestamps of each):

| Track | Length | John Williams cue |
|---|---|---|
| 300 | 0:35 | *Return of the Jedi*, The Battle of Endor I (0:00-0:35) |
| 301 | 1:56 | *A New Hope*, Rescue of the Princess + *Empire*, The Heroics of Luke and Han, the Wampa's Lair, the Training of a Jedi Knight |
| 302 | 1:51 | *A New Hope*, Main Title / Approaching the Death Star / Tatooine Rendezvous + *Jedi*, Main Title, The Emperor |
| 303 | 1:50 | *Jedi*, Brother and Sister, Father and Son, The Fleet Enters Hyperspace, Heroic Ewok |
| 304 | 1:58 | *Empire*, Carbon Freeze, Darth Vader's Trap + The Imperial Probe, Aboard the Executor |
| 305 | 1:02 | *Empire*, Lando's Palace |
| 306 | 2:29 | *Jedi*, The Emperor Arrives, The Death of Yoda, Obi-Wan's Revelation (3:45-6:14) |
| 307 | 0:29 | *Empire*, Attacking a Star Destroyer (0:59-1:32) |
| 308 | 0:29 | *Jedi*, Sail Barge Assault (alternate) (4:27-4:59) |
| 309 | 1:03 | *Jedi*, The Emperor Arrives medley (7:04-8:06) |
| 310 | 0:48 | *Empire*, The Imperial March (0:00-0:43 + 2:52-2:58) |
| 311 | 0:37 | *Jedi*, The Emperor Arrives medley (0:09-0:46) |
| 312 | 0:32 | *Empire*, The Battle of Hoth (0:39-1:11) |
| 313 | 0:50 | *Empire*, The Battle of Hoth (11:03-11:42, faded) |
| 314 | 0:43 | *Empire*, The Imperial March (2:15-3:03) |
| 315 | 0:48 | *Jedi*, The Battle of Endor III (3:40-4:28) |

## When the original plays them

| Moment | Source | Confidence |
|---|---|---|
| **The Cockpit (the menu): 300** | open-rebellion's media notes ("Battle of Endor shuttle-menu cue"), and Rebellion 2's menu track "battle-of-endor-1-medley" (`MainMenuController`) | **Two community sources agree**; not yet heard in the original (the research rule counts the community as corroboration, so one listen would confirm it) |
| **During play: a playlist.** "Neutral" tracks at random; every so many, one **strategic** track chosen by how the war goes - the player's colonized planets against the opponent's: a **strong advantage**, an **advantage** or a **disadvantage** track, per side | Rebellion 2's `StrategyMusicController` and `StrategyMusicTheme` (the cadence, the three thresholds, a multiplier when the opponent holds none) | **Single-source** - the model is Rebellion 2's reading of the original; its numbers and **which file is which** are in its private data |
| **A battle alert: a track of its own** | Rebellion 2's `BattleAlertWindowController` plays a music track with the alert | **Single-source**; which track is unknown (307 and 308, the two short action cues, are the likely pair - a guess) |
| The credits movie: the menu music fades out and comes back after | Rebellion 2's `MainMenuController` | Single-source |

**Not known, and needed before those moments are mapped:** which tracks are each side's neutral,
advantage, strong-advantage and disadvantage tracks; the thresholds and the cadence; the battle
alert's track. **What would settle them:** TeeJ listening in the original at those moments (a
winning and a losing game per side, a battle alert), or - only with TeeJ's approval (CLAUDE.md
1a) - the binary's music selection (open-rebellion's Ghidra export is where to look first).

## Phase 0 findings (2026-09-26, partial)

TeeJ approved reading the game's code and Rebellion 2 again (decision 3). The binary reading
stopped part-way: Claude Code's auto-mode classifier blocked further disassembly, so the
in-game selection function is **not read**.

### The original's player (REBEXE.EXE, read-only, capstone; open-rebellion's `ghidra/notes` for the entry points)

| Fact | Where |
|---|---|
| One player: plays entry *n* (0-15) of a track table from `MDATA\`, at the music volume | `0x417520` (open-rebellion `FUN_00417520.c`) |
| **The table is not in file order:** 0-6 = 300-306, 7 = 310, 8 = 311, 9 = 312, 10 = 307, 11 = 313, 12 = 308, 13 = 309, 14 = 314, 15 = 315 | pointer table `0x6a8478` |
| When a track ends, a looped track (started by `0x417610`) plays again; any other asks the selector for the next | MCI callback `0x417780` |
| The selector gets an object (`0x435a40`; inferred to be the running game); without one it returns with eax 0 - entry 0, **track 300** (the branch target `0x41d3c1` itself was not read); with one it asks it (`0x4369a0` → `0x487fb0`, **not read**) | `0x41d3b0` |
| Music starts when a window is created (`WM_CREATE`; inferred to be the main window) and when Play Music is switched on; Play Music and the volume live in the registry (`MusicSwitch`, `MusicVolume`) | `0x405050`, `0x4176e0`, `0x4173c0` |

### Rebellion 2's mapping (its `Assets/Resources/Configs/FactionThemes.xml`, deleted from the repo 2026-08-01; read from history at `7dffc9f`)

Its track names are the John Williams cues, matched to MDATA by the table above:

| Moment | Alliance | Empire |
|---|---|---|
| Neutral, at random | 301, 302, 303 | 301, 302, 303 |
| Strong advantage (colonized planets ≥ 3:1) | 305 | 311 |
| Advantage (≥ 2:1) | 306 | 310 |
| Disadvantage (≤ 1:2) | 310 | 306 |
| Between them | a neutral track | a neutral track |
| Battle alert | 307 | 307 |
| Battle result: victory / defeat or draw | 308 / 315 | 314 / 315 |

Cadence: one strategic track, then 3 neutral; with the opponent on no planets the player's count
×10 stands for the ratio. Unused: 309, 313.

**Where the two sources meet.** Before `7dffc9f` Rebellion 2 had **six** tiers ("decisive",
"strong", plain; then disadvantage), dropped three as unreachable *in its own code*. In order,
Alliance best to Empire best, they were 304, 305, 306 | 310, 311, 312 - **exactly the original
table's entries 4-9**. That is how its two ambiguous names are read (311, not 309; 312, not 313),
and it suggests the original's selector walks one six-step scale from the Alliance's best to the
Empire's best. Entries 10-15 hold Rebellion 2's battle and result tracks (307, 308, 314, 315)
and the two it never uses (313, 309).

### Confidence

| Claim | Confidence |
|---|---|
| Menu = 300 | **Confirmed**: open-rebellion's notes and Rebellion 2, and the binary agrees (no game → entry 0 = 300, with the two inferences above) |
| Neutral = 301-303 | Single-source (Rebellion 2); fits the table (entries 1-3) |
| The advantage tracks per side | Single-source (Rebellion 2); the order matches the table, the rule does not have a second source |
| The thresholds (3:1, 2:1, 1:2), 3 neutral between, ×10 | Single-source (Rebellion 2), origin not stated |
| Whether the original has six tiers (304 and 312 included) | **Unknown** |
| Battle alert 307; results 308 / 314 / 315 | Single-source (Rebellion 2) |
| 309, 313 | **Unknown** - the original has slots for them |

**What settles the rest:** the in-game selector, `0x487fb0` (open-rebellion's full export may
have it), and the callers of `0x417610` (the looped tracks - likely the battle and result cues).

## How

1. **The exporter** reads the 16 WAVs (plain PCM - no decoder needed) and encodes them as Ogg
   Vorbis with the libvorbis it already carries (`native\fwxiph.dll`): about **3 MB** for all 16
   (mono, 11 kHz). They go into a file (decision 1) as `music/<nnn>.ogg`.
2. **The pack** maps moments to tracks, as `movies` does (SCHEMA.md): e.g.
   `"music": {"menu": "swr-original:music/300.ogg", "battle_alert": ..., "play.alliance": {...}}`.
   Only confirmed moments are mapped (the charter's no-guess rule).
3. **The game**: one music player (Godot's `AudioStreamOggVorbis.load_from_file`), a "music" bus
   the volume slider drives, Play Music on/off; stopped while a movie plays and resumed after.
   The web keeps the music as it keeps the art set (3 MB is small enough for its memory).

## Phases (stop after each)

| # | Phase | Done when |
|---|---|---|
| 0 | **Settle the moments** - TeeJ listens in the original (or approves reading the binary) | each side's four roles and the alert's track are named |
| 1 | **Exporter**: the 16 tracks as Ogg Vorbis in the chosen file | Godot plays them; size stated - **done**: `Music.cs` in the art export, 16 tracks, 4.0 MB, each as long as its WAV; Godot 4.7.1 loads them |
| 2 | **Game**: the player, the music bus, Game Options' Play Music and volume (BACKLOG #41's greyed controls), the menu track | the Cockpit plays 300; the controls work; a movie silences it - **built** (`src/ui/music.gd`, pack field `music`, rule 24; tests/music.gd) |
| 3 | **Game**: the in-play playlist and the battle alert, as phase 0 settles them | a test per moment; TeeJ hears them in play |

## Decisions for TeeJ

| # | Question | Recommendation |
|---|---|---|
| 1 | Where do the music files go: the **art set** (+3 MB), or the **movies file**? | **The art set**: small enough, and a player with the pictures has the music without importing a second file; the movies file stays optional - **answered: the art set** (TeeJ, 2026-09-26) |
| 2 | Before phase 0, play only the confirmed menu track, or also a **neutral playlist of all the long tracks** during play (not the original's exact choice)? | **Menu only** until phase 0 (the no-guess rule) - but it is your call: a plain playlist is a known deviation, easy to replace |
| 3 | Phase 0: will you listen in the original, or should I ask to read the binary's music selection? | **Answered 2026-09-26:** read the game's code and Rebellion 2 (findings above) |
