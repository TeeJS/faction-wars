# Plan: the original's music in the game

Status: **proposed, 2026-09-26** - awaiting TeeJ's decisions at the end. Nothing is built.
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
| 1 | **Exporter**: the 16 tracks as Ogg Vorbis in the chosen file | Godot plays them; size stated |
| 2 | **Game**: the player, the music bus, Game Options' Play Music and volume (BACKLOG #41's greyed controls), the menu track | the Cockpit plays 300; the controls work; a movie silences it |
| 3 | **Game**: the in-play playlist and the battle alert, as phase 0 settles them | a test per moment; TeeJ hears them in play |

## Decisions for TeeJ

| # | Question | Recommendation |
|---|---|---|
| 1 | Where do the music files go: the **art set** (+3 MB), or the **movies file**? | **The art set**: small enough, and a player with the pictures has the music without importing a second file; the movies file stays optional |
| 2 | Before phase 0, play only the confirmed menu track, or also a **neutral playlist of all the long tracks** during play (not the original's exact choice)? | **Menu only** until phase 0 (the no-guess rule) - but it is your call: a plain playlist is a known deviation, easy to replace |
| 3 | Phase 0: will you listen in the original, or should I ask to read the binary's music selection? | **Listen** - one winning and one losing game per side, and a battle alert, answer all of it |
