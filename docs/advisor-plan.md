# Plan: the droids speak - the original's advisor voices and the opening briefing

Status: **phases 0-4 built, 2026-09-27** (TeeJ: "go - continue independently until done"): the exporter (2.6.0, #275) and the game side - the droids, the characters' lines, Translate Counterpart, the sound effects volume, the cockpit's sounds (TeeJ: "include those this round"), the opening briefing, the agent's answers. The briefing's views are read off recordings of the original (phase 4, below); a build short only of maintenance now lets the agent answer (#280).
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
| `ALBRIEF.DLL` / `EMBRIEF.DLL` | the opening briefing, spoken by the agent droid (C-3PO / IMP-22; the frames show him, 67x116 / 106x133, the agent's own size) - not Mon Mothma or the Emperor as this row first said | 17 / 22 | 2.9 / 3.1 min | their animations (2,684 / 2,738 frames). ⚠ In TeeJ's install both are renamed `.DLL.OLD`, so his copy skips the briefing (why is unknown) |
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
| The opening briefing, a new game; then the Message Index opens on Agent Advice | manual p022; the original's own script (GData `C3POACT.SPT` / `IMP22ACT.SPT`, below) | The moment **confirmed**; the lines and their order **confirmed** (the script, and every record's frame count equal to its run's); how the original shows the "key systems he points out" **unknown** |
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
none); the briefing (its briefing data came after its content left the repo - phase 4 read
the original's own script instead); the instant answers to orders (later Rebellion 2 versions
only, by name); about 45 recordings per side nothing references; the names of codes 44/45.

## Phase 4: the briefing (2026-09-27, from the original's own files)

**The script.** `GData\C3POACT.SPT` / `IMP22ACT.SPT` are the agent's action scripts: a u32 count, then per
script a u32 id, a u32 type, a u32 step count, 4 bytes, and 14-byte steps (u16 fields). A step names an RC
record of the side's briefing DLL: 10xxx / 11xxx -> `(4, 4xxx)` -> `(0, recording, 13, frames, run)` - so
4155 is `(0, 1155, 13, 137, 2101)`: recording 1155 with run 2101, 137 frames (the run has 137). Script **41 /
74 is the briefing**, **40 / 73 the skip**. Between lines a step `(10000 / 11000, 0, 0, 2, 0, n, 0)`: the agent
at rest and a number `n` - the pack's `focus`. What each line is about (machine transcription with Windows'
own recogniser - **inferred**, rough) says `n` is what he points out:

| focus | Alliance line | About (transcribed) | Empire line |
|---|---|---|---|
| 12 | 1155 | C-3PO and R2-D2 introduce "a report on the current state of the galaxy" | 1147 |
| 1 | 1220 | "as you can see on the galactic information display, the galaxy is in a state of turmoil" | 1220 |
| 14 / 15 | 1221 / 1222 | systems drawn to the Alliance / still loyal to the Empire | 1221 / 1222 |
| 16 / 17 | 1223 / 1224 | the core systems / the rim, "excellent bases" | 1223 / 1224 |
| 18 | 1157 | the base on Yavin, "which you can see indicated here"; evacuate it | 1149 |
| 3 / 4 | 1158 / 1159 | the Alliance headquarters / the Imperial capital, Coruscant | 1150 / 1151 |
| 5 / 6 | 1160 / 1161 | the fleet ("begin a shipbuilding program") / troops, fighters, defences, facilities | 1152 / 1153 |
| 7 / 19 / 20 | 1225 / 1226 / 1163 | Mon Mothma at headquarters / Luke / Vader and the Emperor | 1225 / 1226 / 1155 |
| 9 / 10 | 1164 / 1168 | the briefing ends / "we await your orders ... may the Force be with you" | 1156 / 1160 |
| 11, 13 | - | the end (also around the skip's line) | - |
| skip | 1165 | "I do hope you know what you're doing" | 1157 |

16 lines a side; the DLL's 17th recording is the skip's (the Empire's 22 add SD-7's five clicks).
**Built:** the pack's `briefing` (rule 28), `src/ui/briefing.gd` - at a new single-player game, the agent
speaks the lines in his place, the clock held and the droids' news waiting; Esc or a left click (manual
p022) stops the line and plays the skip's; then the Message Index opens on Agent Advice. tests/briefing.gd.
**The views (2026-09-27).** Watched on two recordings of the original's briefing (YouTube: SuperPaulGames,
"Let's Play Star Wars Rebellion - Part 1 As the Rebels", 4:55-7:47; "Star Wars: Rebellion Let's Play |
Galactic Empire: Part 1", 1:37-4:46). At each focus step the display changes: a caption where the mode's
name goes (TEXTSTRA 5652-5674 hold them all), only the systems the line is about lit in their side's star,
every other system its smallest grey star; or the display off - the bright galaxy (STRATEGY 902, not the
map's dimmed 903) and no systems.

| focus | Alliance | Empire |
|---|---|---|
| 12, 9, 10 | display off | display off |
| 1 | Popular Support (the mode) | Popular Support |
| 14 / 15 | Systems Loyal to the Alliance / to the Empire | to the Empire / to the Alliance |
| 16 | Systems Under Military Control | the same |
| 17 | Unexplored Systems (lit cyan) | the same |
| 18 | Yavin | Coruscant |
| 3 | Alliance Headquarters | Yavin |
| 4 | Coruscant | Unexplored Systems |
| 5 | Idle Fleets (the mode) | Idle Fleets (by its caption's length) |
| 6 | All Defenses | All Defenses (by its caption's length) |
| 7 / 19 | Mon Mothma / Luke Skywalker (their system) | Emperor Palpatine / Darth Vader |
| 20 | Coruscant | Yavin |
| after | Popular Support again | the same |

Which systems "Military Control" and "All Defenses" light is **inferred**: held short of popular support
(a garrison requirement, manual p089), and any defenses the player knows of. **Built** (exporter 2.6.1
for 902; the pack's `views`; `GalaxyMap.ShowView`). Esc: community sources (GOG forum, open-rebellion's
GAME-FLOW) say it does not skip on modern Windows and players rename the briefing DLLs instead - which is
why TeeJ's are `.OLD`; ours skips, as the manual says. The clock is held (TeeJ: "game clock is paused";
both recordings show no day until it ends). Head-to-head has none: no source shows a head-to-head start
(the one multiplayer recording found starts single-player); REBEXE would settle it.

**Two things the recordings show that differ from us** (not changed here): after the briefing **no Message
Index opens** in either recording, where manual p022 says it opens on Agent Advice (ours follows the
manual); and before the briefing **the side's shuttle film plays** - Cloud City for the Alliance, the Star
Destroyer for the Empire (MDATA 003 / 004) - which #269 removed on TeeJ's report from his own copy.

**A lead for phase 3.** The same scripts hold the agent's other actions (C3POACT's 1-39 and 69-85 name one
record each; 42-68 pair a message-droid record with a C-3PO one). Transcribing their lines as above would
say which is "that destination is invalid" and the others - by content, not by the binary's own map.

## Phase 3: the agent's answers (2026-09-27)

The agent's action scripts (phase 4's) name every recording he has; what each says (transcribed, **inferred**)
picks the answer. The moments are the manual's (p102 "C-3PO or IMP-22 indicates the error"; p047 "C-3PO will
tell you if you don't have the maintenance capacity") and Rebellion 2's (in transit, under construction, the
toggles). The Empire's recordings say the same at the same ids.

| Answer | Script (Alliance / Empire) | Recording | Says (transcribed) | Where the game answers |
|---|---|---|---|---|
| `in_transit` | 1 / 1 | 1096 / 1596 | "no messages may be sent to units in transit; wait until they arrive" | a fleet order refused, in transit |
| `not_controlled` | 2 / 2 | 1097 / 1597 | "... system we control" | personnel or the headquarters sent to a world not ours |
| `no_mission` | 3 / 3 | 1098 / 1598 | "none of the personnel ... capable ... no mission can be performed" | No Mission Available (p102) |
| `no_maintenance` | 10 / 10 | 1105 / 1105 | "your order ... cannot be carried out; we don't have the maintenance capacity" | a build queued short of its number (p047) |
| `garrisons_on` / `_off` | 36-37 / 29-30 | 1137-1138 / 1135-1136 | "you won't need to supervise the garrisons" / "relinquish control of the garrisons to you" | the agent's menu |
| `production_on` / `_off` | 38-39 / 31-32 | 1139-1140 / 1137-1138 | "maximize the output of our mines and refineries" / "... satisfactory" | the agent's menu |

**Also in the scripts, not wired** (no moment in our interface yet): "that unit is still under construction"
(1214), "you cannot move those units to the selected target" (1215), "you can't move a facility once it has
been deployed" (1203), "the Empire has blockaded that system" (1213), a fleet's capacity (1102-1104), energy
and raw materials (1106-1109), "Special Forces cannot be assigned as decoys alone" (1212). **Our interface greys
the orders the original lets you try and then answers** (a unit in transit or under construction, a build
without the maintenance - the Build button is greyed): making them live is TeeJ's call.

## Phase 5: the agent's advice messages (2026-09-27)

TeeJ: "there are no advice messages loaded when the briefing ends", with a screenshot of the original's
Advice tab (Alliance): Victory Conditions; Mon Mothma, Luke Skywalker and other Rebel Leaders; The Galactic
Information Display; Positioning Fleets; The Battle Alert; Manufacturing New Items; Adjusting Time;
Furthering Our Cause; Advice Available.

| | Source | Confidence |
|---|---|---|
| The texts: TEXTSTRA.DLL RCDATA, the Alliance's from 0x6000, the Empire's from 0x6800. The base holds the count (31 a side); message n (from 1) is three records from base + 3n: a u16 group and a u16 key, the title, the text | read off the DLL; the original's advice message reads title 0x6001 + 3n and text 0x6002 + 3n by side (FUN_0048b2e0, open-rebellion's Ghidra notes) | **Confirmed** (the data, the decompilation) |
| A game opens with **group 7**: the nine above, in the list's order | the nine group-7 messages are exactly TeeJ's screenshot, in its order; the advice's start posts every group-7 entry (FUN_00439f20) | **Confirmed** (screenshot, decompilation) |
| The picture: STRATEGY.DLL 1071 (C-3PO) / 1072 (IMP-22), 400x200 | the advice message takes 0x42f / 0x430 by side (FUN_0048b2e0) | **Confirmed** (decompilation; the pictures are the agents) |
| The advice message also names STRATEGY.DLL WAVE 1121 / 1122 (0x461 / 0x462, ~3.5 s each) | FUN_0048b2e0 | When it plays is **unknown** - not played |
| The rest (groups 1, 2, 3, 5, 6; keys 100-310, a tutorial sequence): each of five first-time events posts the next pending tip of its group (bit 1 -> group 6, 2 -> 2, 4 -> 3, 8 -> 5, 16 -> 4; FUN_0043a0b0); a periodic pass posts the next pending tip whose group's event has happened, group 1 always (FUN_00439fb0) | open-rebellion's Ghidra notes | The model **single-source**; **which events** set the five bits and **how often** the pass runs are **unknown** - their callers are not in the published notes; REBEXE would settle it |
| Showing the Advice tab drops the game to Very Slow; any other tab or closing the Message Index restores the speed | open-rebellion's message-index evidence (FUN_004697b0 -> FUN_00487ff0) | **Single-source** - not built |

**Built** (exporter 2.6.2 writes `advice.json` and `windows/advice.<side>.png`): the pack's `advice` (rule 29)
names the list, `opening` 7 and the picture per side. **Agent Advice** is the agent's menu's check item
and Alt+A (manual p078); "Agent Advice only appears in an Easy game. If you wish for advice in Medium or
Hard games, you must enable Agent Advice on the Agent menu" (manual p022, read in the OCR at the old repo's
research/SWR_Manual.txt) - so it starts on in Easy only. While it is on the side has its opening advice,
posted to the Advice category (`src/ui/advice.gd`) in the list's order - the Message Index shows same-day
messages in the order they came, so top to bottom as the original: at a new game in Easy, or when switched
on, once a game. With no briefing to play (an art set without its recordings - the GOG copy's briefing DLLs
are `.OLD`, and the exporter reads either name) the Message Index opens on Agent Advice at once. All
Messages' unread count leaves advice out, as its list does (p079). The Message Summary keeps a text to the
box measured on TeeJ's screenshot (four lines) and the mouse wheel moves through a longer one -
how the original shows the rest is **unknown** (its window has scroll commands 0x96 / 0x9a). Not in
head-to-head, as the briefing. Messages are not saved (game_message.gd), so a loaded game has none.
**Not built**: the later tips, the Very Slow drop, the 1121 / 1122 sound.
tests/advice.gd.

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
| 3 | **Game**: the instant answers (invalid order, in transit, under construction, the droid toggles, maintenance) | a test each - **built** from the agent's own action scripts (phase 3 section): `Advisor.Answer`, the pack's `answer_*`, `Result.code` where the engine refuses; tests/advisor.gd. Not built: the answers to orders our interface greys (under construction, a build without the maintenance) |
| 4 | **Game**: the opening briefing (decision 2) | it plays at a new game, **Esc skips it**, then Agent Advice opens - **built** from the original's own script (above): `src/ui/briefing.gd`, the pack's `briefing` (rule 28), tests/briefing.gd; its views from recordings of the original |
| 5 | **Game**: the agent's advice messages (TeeJ's report) | a new game in Easy opens with the original's nine; Agent Advice switches them on in Medium / Hard - **built** (phase 5 section): exporter 2.6.2 `advice.json`, the pack's `advice` (rule 29), `src/ui/advice.gd`, the agent's menu and Alt+A; tests/advice.gd. The later tips **not built** (their triggers unknown) |

## Decisions for TeeJ

| # | Question | Recommendation |
|---|---|---|
| 1 | Where do the voices go: the **art set** (+~10 MB, plus the animations), or a **voices file** of its own like the movies? | **Answered: the art set** |
| 2 | Build the **opening briefing** too? Your copy has it switched off (the `.OLD` files) - do you know why? | **Answered: yes, Esc skips it** |
| 3 | Build from **Rebellion 2's map** (as the music was), or read the binary first? | **Answered: Rebellion 2's map** |
| 4 | "You have not adequately supported..." - which side, and when did you hear it? | **Answered:** the Emperor, playing the Empire, when his mission fails - recording 1387 |
| 5 | The lines have no text in the game's files. Show nothing, as the original, or subtitles (they would have to be transcribed)? | **Answered: none** |
