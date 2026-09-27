# Plan: the droids speak - the original's advisor voices and the opening briefing

Status: **phases 0-2 built, 2026-09-27** (TeeJ: "go - continue independently until done"): the exporter (2.6.0, #275) and the game side - the droids, the characters' lines, Translate Counterpart, the sound effects volume, the cockpit's sounds (TeeJ: "include those this round"). Phase 3 has no source; phase 4 next.
TeeJ, 2026-09-27: "What about the dialogue, like emperor's 'you have not adequately
supported'" ... "yes write the plan". BACKLOG #41 (sound) stays for the sound effects.

TeeJ's decisions (2026-09-27): **1** the art set; **2** include the briefing, **Esc skips it**;
**3** build from Rebellion 2's map; **4** the Emperor's line plays "when playing as empire and
his mission fails"; **5** no subtitles.

## Charter

| | |
|---|---|
| **The one thing** | A player who owns Star Wars: Rebellion sees and hears the Command Center's droids as the original has them: the message droid (R2-D2 / SD-7) reporting each event and the agent (C-3PO / IMP-22) saying it aloud - from their own copy, desktop and web. |
| **Wrong if shipped without** | **Translate Counterpart** working (the agent menu, Alt+V; "on by default" - manual, GAMEPLAY.md "The agent menu"): off, the agent stays quiet. Game Options' **sound effects volume** (greyed today) driving the voices. Nothing talking over a movie. The game unchanged without the files imported. |
| **Off-limits** | Any of the original's recordings or frames in the repo, the web build or our servers (the art-set rule). A line played at a moment we guessed without saying so (the music plan's rule: a single-source map is marked as one). |
| **Deploy target** | The exporter writes the recordings and the talking animations into a file the game imports (decision 1); desktop and web. |
| **Verified by** | Each mapped event plays its animation and line; Translate Counterpart off silences the agent (the droid still reports); the volume changes it; a movie holds it; a test per moment. |

## What the original has (measured on the GOG copy, 2026-09-27)

| File | What | Recordings | Length | Other |
|---|---|---|---|---|
| `ALSPRITE.DLL` / `EMSPRITE.DLL` | the droids of each side: their animations and their lines | 213 / 216 | 10.6 / 11.4 min | mostly 11,025 Hz mono 16-bit (a few 22 kHz stereo 8-bit); animations as type-302 delta frames on RT_BITMAP anchors (1,640 / 2,348 frames; the exporter already decodes them for the idle runs, `Importer.cs` DroidRuns); 752 / 753 RT_RCDATA (not identified) |
| `VOICEFXA.DLL` / `VOICEFXE.DLL` | more voice | 153 / 132 | 7.1 / 7.1 min | 11 kHz mono 8-bit; **what they are is unknown** - Rebellion 2's advisor uses none of them |
| `ALBRIEF.DLL` / `EMBRIEF.DLL` | the opening briefing (Mon Mothma / the Emperor) | 17 / 22 | 2.9 / 3.1 min | their animations (2,684 / 2,738 frames). ⚠ In TeeJ's install both are renamed `.DLL.OLD`, so his copy skips the briefing (why is unknown) |
| `STRATEGY.DLL` | the interface's sound effects | 66 | 6.7 min | not dialogue - BACKLOG #41 |

**The spoken words are not in any text file** (TEXTSTRA, TEXTCOMM, ENCYTEXT - searched for
"adequately"): the lines are audio only.

## When the original plays them

| Moment | Source | Confidence |
|---|---|---|
| The message droid reports every event; the agent translates it aloud when Translate Counterpart is on | manual (GAMEPLAY.md: the droids' roles table, the agent menu); Rebellion 2's `StrategyAdvisorController` (the agent's line only with "announcements enabled") | **Confirmed** (the manual and Rebellion 2) |
| Which event gets which animation and recording | Rebellion 2's `FactionThemes.xml` (`StrategyAdvisor`, read from its history at `7dffc9f`): the original's event number ("TableID", 25-75) → the droid's and the agent's animation (first frame + frame count) and recording, **by the original's own resource ids** - 57 recordings for the Alliance, 53 for the Empire | **Single-source** (Rebellion 2). Its music map proved exact against the binary (docs/music-plan.md), which argues for this one; the binary would confirm |
| How often | Rebellion 2: a notification per event type, queued by priority, living a few days (5-10 ticks), the same type not repeated within 60 ticks | Single-source |
| The agent answers an order at once: an invalid destination ("C-3PO or IMP-22 indicates the error", manual p102), a unit in transit, a unit still being built; Manage Garrisons / Manage Production on and off; not enough maintenance (manual p047) | the manual, and Rebellion 2's authored responses (`InvalidOrderRejected`, `InTransitOrderRejected`, `UnitUnderConstructionOrderRejected`, the four toggles) | **Confirmed** for the moments the manual names; the recordings single-source |
| "Good news about support for the Alliance" when a system joins | manual p043 | Confirmed (the moment); which recording, Rebellion 2 |
| The opening briefing, a new game; then the Message Index opens on Agent Advice | manual p022; Rebellion 2's `PlayBriefing` (segments: an animation, a recording, a map focus) - its data not in the snapshot | The moment **confirmed**; the segments unknown |
| The other ~155 recordings per side, VOICEFX, and TeeJ's "You have not adequately supported..." | - | **Unknown** (phase 0) |

## Phase 0: the map (2026-09-27, from Rebellion 2's last in-repo data)

Source: Rebellion 2 at `f4d4386` (the last commit before its content left the repo, 2026-08-01):
`Assets/Resources/Configs/FactionThemes.xml` (`StrategyAdvisor`), `Assets/Resources/Data/Officers.xml`,
and `Assets/Scripts/Game/Messages/MessageFactory.cs` / `Message.cs`. We take **facts** from it
(which of the original's recordings and frames goes with which event), none of its code
(PolyForm Noncommercial; its licence excludes game data).

**The chain.** A message carries an advisor **code** - the original's own event numbers,
gaps and all: 1 positive support, 2 negative support, 3 manufacturing, 4 research, 5 fleet
arrived, 6 units arrived, 8 capital ship repaired, 9 starfighter repaired, 12 maintenance,
13 blockade initiated, 14 blockade detected, 20 field personnel, 21 agent report, 22-27 a
major character's report, 28 planetary status, 30-35 a major character captured, 36-40
released, 41 intercepted communication, 44 / 45 (one per side, unnamed), 46 bombardment,
47 planetary assault. The code gives an **entry** and a **lifetime** (5 or 10 days); the
entry gives the message droid's animation and sound, and the agent's animation and
recording (first frame, frame count, recording id) - the agent's only with Translate
Counterpart on. Pending entries play lowest entry number first; the same entry not again
within 60 days; frames every 0.067 s.

**The characters' own lines**, by line type (order acknowledged, arrived, mission success /
failure / abort, released, recovered, enemy detected, traitor discovered, and per character
more: the Force, Dagobah, bounty hunters, the Emperor's seat of power): Luke 29, Leia 15,
Han 14, Emperor 10, Vader 9, Mon Mothma 7. **The Emperor's mission failure is recording
1387** - TeeJ's line (confirmed: his report and Rebellion 2 agree).

| | Mapped | In the files |
|---|---|---|
| The droids' lines, Alliance (`ALSPRITE.DLL`) | 35 codes → 33 entries, 57 recordings | 57 of 57 |
| The droids' lines, Empire (`EMSPRITE.DLL`) | 35 codes → 31 entries, 53 recordings | 52 of 53 - **1580 is in neither file** |
| The characters' lines | 84 recordings | all, in both files |

**Which events send which code** (Rebellion 2's message builders): fleet arrived (5), ships
arrived (6), a producer idle (3), repaired (8 / 9), sabotage, a facility lost, maintenance
auto-scrap (12), research (4), blockades (13 / 14), personnel arrived (20, or the character's
report), an enemy mission foiled (21), uprisings and a system joining / leaving by support
(1 / 2 / 28), bombardment (46), assault (47); a major character's report, capture and
release by the character (22-40).

**Not mapped** (not in Rebellion 2's data): VOICEFXA/E (285 recordings - Rebellion 2 uses
none); the briefing (its briefing data came after its content left the repo - phase 4 reads
the briefing files' own order); the instant answers to orders (later Rebellion 2 versions
only, by name); about 45 recordings per side nothing references; the names of codes 44/45.

## What the code does today

| | |
|---|---|
| The droids | pictures: their idle runs, exported by `Importer.cs` (`windows/droid_<agent|messenger>.<side>`), drawn by `src/ui/command_frame.gd`. No voice, no talking animation |
| Translate Counterpart | on the agent menu, greyed: "Not built - the message droid's announcements are not voiced" (`src/ui/ui_manager.gd`) |
| The sound effects volume | greyed on Game Options (`src/ui/original_options_screen.gd`) |
| The hook | every event is already a message (`EventBus`, `Enums.MessageType`) - what Rebellion 2 keys its advisor on |

## How

1. **The exporter** writes the recordings as Ogg Vorbis (as the music: 11 kHz mono, about
   **10 MB for all 753** - 42 minutes at the music's 4 MB per 18) and the talking animations
   as frame strips (the idle runs'
   decoder), into the file of decision 1.
2. **The pack** maps the engine's events to lines, per side (like `music`): event → the
   message droid's animation and sound, the agent's animation and recording, a pool where the
   original has several. Other packs can voice their own.
3. **The game**: an advisor player on the Command Center - a queue with Rebellion 2's
   priority, lifetime and cooldown; the droid's report, then the agent's line when Translate
   Counterpart is on; an "Effects" bus driven by the sound effects volume; held under a movie;
   the instant answers to orders; the briefing at a new game (decision 2).

## Phases (stop after each)

| # | Phase | Done when |
|---|---|---|
| 0 | **Map the lines**: Rebellion 2's table, checked against the binary (TeeJ's approval each time, manual mode) and by listening; what VOICEFX is; where TeeJ's line is | every mapped event has a named recording and a confidence - **done** from Rebellion 2's map (decision 3), every recording checked in the files (above) |
| 1 | **Exporter**: the recordings and the talking animations | the game can play them; size stated - **built** (2.6.0, #275): 890 sounds 13.8 MB, 110 runs 14.9 MB |
| 2 | **Game**: the droids report events; Translate Counterpart; the effects volume | a test per event; TeeJ hears them - **built**: `src/ui/advisor.gd`, `sound.gd`, `fwa.gd`; the pack's `advisor`, `voices`, `sounds` (rules 25-27); news tagged where the simulation writes it (GameMessage.Advisor / Voice); the cockpit's sounds (open-rebellion's map of COMMON.DLL); tests/advisor.gd. TeeJ's listen owed |
| 3 | **Game**: the instant answers (invalid order, in transit, under construction, the droid toggles, maintenance) | a test each - **no source**: Rebellion 2's last in-repo data has no ids for them, and none other maps them; the binary would (TeeJ's approval) |
| 4 | **Game**: the opening briefing (decision 2) | it plays at a new game, **Esc skips it**, then Agent Advice opens |

## Decisions for TeeJ

| # | Question | Recommendation |
|---|---|---|
| 1 | Where do the voices go: the **art set** (+~10 MB, plus the animations), or a **voices file** of its own like the movies? | **Answered: the art set** |
| 2 | Build the **opening briefing** too? Your copy has it switched off (the `.OLD` files) - do you know why? | **Answered: yes, Esc skips it** |
| 3 | Build from **Rebellion 2's map** (as the music was), or read the binary first? | **Answered: Rebellion 2's map** |
| 4 | "You have not adequately supported..." - which side, and when did you hear it? | **Answered:** the Emperor, playing the Empire, when his mission fails - recording 1387 |
| 5 | The lines have no text in the game's files. Show nothing, as the original, or subtitles (they would have to be transcribed)? | **Answered: none** |
