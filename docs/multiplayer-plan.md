# Multiplayer over the web — plan

**Status:** PLAN, 2026-09-03. Nothing implemented. TeeJ answered every decision
(room #89, #90; recorded in §5 and §6); awaiting the explicit go for M0. Author: Lord Vader. For review:
C3PO (screens vs manual Ch5), Doof (architecture).

Sources read for this plan: manual Chapter 5 "Head-to-Head Games", manual
p156–p167 (PDF p152–p163, offset +4 in this chapter), Figs 5.1–5.11; the port's
determinism proof (HANDOFF steps 0b and 2: 503 of 503 day hashes identical to the
C# source); Godot 4 docs on WebRTC/WebSocket in Web exports; the port's own
mutation entry points (grep of `src/ui/*.gd`).

---

## 1. Charter (directive 6)

| | |
|---|---|
| **The one thing** | Two people, one the Alliance and one the Empire, play one game against each other from two browsers, with the head-to-head features the manual names: chat through the message system, a shared game speed, a pause the opponent sees, and a host-only save. |
| **Wrong if shipped without it** | **The two machines must hold the same game.** Any drift - a fleet here that is not there - makes the game meaningless. The port's proven determinism (same seed, same orders → same hashes) is the whole basis of this plan, and every step below is gated on hashes matching across two clients. |
| **Off-limits workarounds** | (a) One client runs the game and streams the screen or a state dump to the other - that is not two players, it is one player and a viewer, and it doubles bandwidth for nothing. (b) Silently dropping a manual feature: the manual's head-to-head chapter lists chat, shared speed, opponent-visible pause, host save. Each is built or its absence is written down here with TeeJ's initials. (c) Inventing rules the manual does not state (who wins a tie, what happens on disconnect) without saying so. |
| **Deployment target** | Static web build (already exporting) on any static host, plus one small relay service on the Unraid box behind NPM Plus with TLS (e.g. `wars-relay.schmitzplex.com`). Backup: everything is in git (schmitz-wars on GitHub; the relay in its own repo). No new listener on any workstation. |
| **How we verify it is done** | 1. Two headless clients joined through the relay play 200 scripted days and print identical day hashes. 2. Two browsers on two machines play a game start to finish; chat, speed, pause and save behave as manual p162–p163 describe. 3. Kill one browser mid-game, rejoin, and the rejoined client's hash equals the other's. 4. Every screen in Figs 5.1–5.11 re-checked element by element (rule 0). |

---

## 2. What the manual specifies (Chapter 5, head-to-head)

The interface is part of the feature (CLAUDE.md rule 0). Every element below is a
requirement unless marked *n/a* with a reason.

| Manual element | Where | Requirement for the web port |
|---|---|---|
| **Multiplayer Panel** in the Shuttle Cockpit: "the small panel at the lower left that depicts a Rebel soldier and an Imperial stormtrooper facing off" (Fig 5.1) | p156 | A Multiplayer control on the main menu, lower left. No artwork exists; a labelled button stands in (noted deviation, same as the rest of the menu). |
| **Multiplayer Configuration screen** (Fig 5.2): a list of service providers, "the provider that is currently selected appears in red"; **Setup Game** / **Connect to Game** ("the currently selected option will be depressed and the text will appear dark"); right arrow proceed, left arrow back, **X** cancel to the Shuttle Cockpit | p157 | Same screen. The provider list has ONE honest entry, "Internet connection" (IPX, modem and direct serial are *n/a* in a browser; listing them would be a lie). Setup/Connect toggle, proceed/back/cancel exactly as described. |
| **Host Game screen** (Fig 5.3): **Player Name** ("defaults to your Windows 95 user's name"), **Game Name** ("defaults to your computer's name"), proceed/back/cancel | p158 | Same two boxes. A browser exposes neither name: defaults become the last name used (browser storage) or "Player" / "Game N". Recorded deviation. |
| Modem answer / serial / modem connect dialogs (Figs 5.4, 5.5, 5.7) | p158–p160 | *n/a* - no modem or serial in a browser. Fig 5.7 (Modem Connection: phone number, modem list, Configure, Connect, Cancel) is the join-side twin of Fig 5.4. |
| **Locate Session** / TCP-IP dialog (Fig 5.6): "Enter the computer name or IP address of the session host, or leave blank to search"; **OK** proceeds to the Join Game screen, **Cancel** backs out; "If you are playing on a TCP/IP LAN, leave the box blank and click OK" | p159–p160 | Same dialog: one text field, OK, Cancel. Blank + OK lists every game waiting on the relay (the manual's search). A typed value is a **game code** for a private game - the web deviation from an IP address, recorded here. |
| **Join Game screen** (Fig 5.8): Player Name; "select a game to connect to from the following list"; proceed/previous/cancel | p160 | Same screen, list fed by the relay. |
| **Multiplayer Options screen** (Fig 5.9), host only: **choose your side** (red Alliance / green Empire symbols), **galaxy size** standard/large/huge, **Standard Game / HQ Only Victory** (Standard: "Rebel Win Conditions: Capture Coruscant and capture Emperor Palpatine and Darth Vader. Imperial Win Conditions: Destroy the Rebel headquarters and capture President Mon Mothma and Luke Skywalker"; HQ Only: "Rebel Win Conditions: Capture Coruscant. Imperial Win Conditions: Destroy the Rebel headquarters"), **Load Game** ("only available if you have saved a game from a previous session with your current opponent. If you are loading a saved game, it will use the game size and difficulty settings from your previous game"), **chat** ("click to the right of Chat>, type, Enter"), chat/settings view, **checkmark** Start Game (host), previous, cancel | p161–p162 | Same screen. Both victory variants are what VictoryManager already evaluates (HQOnlyVictory). Load restores size and the victory setting from the save; difficulty is fixed at the **Multiplayer** column in every head-to-head game, so there is nothing to restore there - no difficulty choice appears, matching the manual (`Enums.Difficulty.Multiplayer`, `side_lottery.json` "mp"). The guest sees the host's choices and the chat, and waits. |
| **Messages (Chat)**: "processed through SD-7 or R2-D2's messaging system"; **Chat Messages** tab in the **Display Message Index** (Fig 5.10); "**Double-click a message to view it**"; "the button on the bottom right-hand side of the window to send a message"; **Compose Chat Message** window (Fig 5.11): "Type your message here", **Send message**, **Cancel**, **Close button**, **Return to Display Message Index** | p162–p163 | `MessageCategory.Chat` and the Chat tab already exist in MessageWindow. Add: double-click on a row opens the message (the manual's gesture; today's window opens on single click - both must work); the compose button at bottom right; the Compose Chat Message window with the five controls named exactly as the figure labels them. A chat line becomes a `GameMessage` in the Chat category on both clients. |
| **Game Speed**: "can be adjusted by either player ... the game plays at the SLOWEST speed set on either computer. Pause, Very Slow, Slow, Medium, Fast" | p162–p163 | Each client's speed choice is a command; the effective speed is min(both). Pause is one of the five. |
| **Pausing**, two paths: (a) "bring up the Game Options Screen. Your opponent will receive a **Waiting for Opponent** message, until you return to the game"; (b) "pause on the Game Speed menu until you are ready to play. Then just click on the checkbox to resume play" | p163 | Both paths kept. (a) Opening the in-game menu sends a pause command; the opponent sees the modal "Waiting for Opponent" until the menu closes. (b) Choosing Pause on the Game Speed menu (the checked radio item that exists today) sends the same command; the pauser's own pause box is the single-player one with its Resume checkbox, and clicking it resumes both. |
| **Saving**: "only the host player can save the game. Star Wars Rebellion will create a saved game on both computers in the same saved game slots"; Load only from the Multiplayer Options screen, "only available if you have saved a game from a previous session with your current opponent" | p163–p164 | The order log IS the save (§3). Host-only Save writes the log to the relay's store and to both browsers' storage **under the same slot id** (game code + slot number), so "the same saved game slots" holds literally on both machines; Load lists saves whose two player names match. |
| Internet Gaming Zone, WINIPCFG, PING (p164–p167) | | *n/a* - 1998 matchmaking and Windows 95 utilities. The relay's game list is the matchmaking. |
| Standard Game win conditions restated (Rebels: Coruscant + Palpatine + Vader; Imperials: Rebel HQ + Mon Mothma + Luke) | p162 | Already what VictoryManager implements; nothing new. |

---

## 3. Architecture: deterministic lockstep over a thin relay

### Why lockstep, not a server-authoritative simulation

| | Lockstep (recommended) | Server-authoritative (C3PO's #85) |
|---|---|---|
| Who runs the simulation | both browsers, identically, from the same seed | a headless Godot on the server; browsers render state |
| What crosses the wire | the players' commands (a few per day) + a 64-char hash per day | full state deltas every tick (150 planets, 60 characters, fleets...) |
| Server | a dumb relay + append-only log (~300 lines of Bun/Node) | a Linux headless Godot build of the whole game, kept in step with the client build, plus a delta protocol |
| Cheating | possible for someone who edits their wasm; irrelevant for two friends | prevented |
| Reconnect / save | replay the log from the seed; free | server snapshot; must be built |
| What we already have | 503/503 hash parity proves the sim is deterministic across runs | nothing |

Lockstep costs one thing: **every mutation must become a command** so both sides
apply the same thing in the same order. That is §4 step M1, and it is the bulk
of the work. Server-authoritative would need the same command layer anyway (the
server has to validate and apply commands), so lockstep is strictly less work.
If cheating ever matters, the same relay can be promoted to run the sim later
because it will already hold the command log.

### The tick

- The **day** is the lockstep step. A client's `AdvanceDay` runs only when the
  relay has delivered the opponent's command batch for that day (an empty batch
  counts). Commands for day N are applied in a fixed order (faction order from
  the pack, then sequence number) before day N advances - on both clients.
- Within a day the UI stays live: an order issued at 10:00 of the day is
  queued locally, sent, and applied by both at the next tick. The player sees
  their fleet marked "orders pending" until then. At Slow (15 s/day) that is at
  most 15 s of latency; at Fast (1.3 s) it is imperceptible.
- **Speed**: each client sends its chosen speed as a command; both run the tick
  timer at min(both). **Pause** is speed 0; the other side shows "Waiting for
  Opponent".
- **Hash**: after each day both clients send `GameSignature` SHA-256 (already
  built for the parity gate). A mismatch stops the clock and offers resync: the
  client replays the log from the seed (a few seconds at 10 ms/day) and compares
  again. Desync is a bug report with a reproducible log attached, never a silent
  drift.
- **PRNG**: one stream, consumed identically because both sides apply identical
  commands to identical state. Anything that rolls on the UI's own clock breaks
  this - see the tactical limitation below.

### Entity identity in commands

Commands name things, so every thing a command can touch needs a stable id
that is identical on both clients:

| Entity | Today | Needed |
|---|---|---|
| Planet, Sector, Faction, Character | by name (unique in the data) | nothing |
| Fleet | serial (`Fleet.NextSerial`, deterministic) | nothing |
| Unit (ship, squadron, regiment, SpecForce) | object reference only | a deterministic serial assigned at creation, mirroring the fleet serial |
| Facility | object reference only | planet name + slot index at creation |
| Mission | object reference only | a deterministic serial |
| Message (for Delete) | object reference only | a per-game sequence number |

### The command set (from the UI's mutation entry points today)

Move fleets / units / characters; board fleet; load aboard / unload / disembark;
run blockade (with the evacuation confirmation resolved by the owner); queue
facility / unit (with count and destination); cancel build; scrap facility /
unit; retire character; take command (rank); launch mission (type, team,
origin, target, decoys, victim, object); abort mission; bombard (mode);
planetary assault; battle answer (simulate / retreat); agent droid toggles
(manage production / garrisons); delete messages; **chat** (text); **set speed**;
**pause / resume**. About 20 kinds. Each carries `{day, seq, faction, kind,
args}`; args are ids. The AI stays inside the simulation (it is deterministic
and needs no wire) - but in head-to-head no faction is AI-driven.

### The relay

- One WebSocket service (Bun or Node, ~300 lines) behind NPM Plus with TLS.
  Rooms keyed by game code; each room stores host, guest, settings, and an
  **append-only command log** (the save). Endpoints: list games, create, join,
  send batch, fetch log from N, chat. Auth: the game code; no accounts.
- Client side: `WebSocketPeer` is in every Godot Web export without an
  extension. (WebRTC also is, but needs a signaling server anyway and adds NAT
  traversal failures; the relay is simpler and also gives us the log store.)
- EDR note (directive 16): the listener lives on the Unraid box, never on a
  workstation. Nothing in the browser opens a port.

---

## 4. Work breakdown, gates first

| # | Step | Gate (hard) | Size |
|---|---|---|---|
| **M0** ✅ | **Done 2026-09-03** (`docs/m0-audit.md`). **Audit**: the simulation must give identical results whichever faction is local. `GameSettings.PlayerFaction` is read 45 times in 19 files under `src/game/`; each read is classified as *presentation* (message wording, who gets a Battle Alert), *rule column* (RuleManager - neutralised by the Multiplayer column), or *simulation branch* (a real bug for MP). Introduce `GameSettings.LocalFaction` for the UI and keep the sim free of it. Add unit / facility / mission serials. | 200-day soak with the local faction set to Alliance, then Empire, then none: **identical hashes all three ways**. Single-player 503/503 still passes. | 2–3 days |
| **M1** ✅ | **Done 2026-09-03** (`docs/m1-plan.md`; commits 21cd17a..c3d9a23). **Command layer**: `Command` type, `CommandLog`, `CommandApplier`; every UI mutation entry point (the ~20 above) issues a command instead of calling the backend; in single player the command applies immediately (so nothing changes for TeeJ) and is logged. `--replay=log` boots a game and replays the log. | A recorded 200-day single-player session replays to identical hashes. The step-2 soak still passes 503/503. | 4–6 days |
| **M2** | **Lockstep locally**: two headless clients + a local relay stub in the test harness, scripted commands on both sides, day gating, speed = min, pause, hash exchange, resync-by-replay. | 200 days, two clients, scripted orders both sides: identical hashes every day; a forced desync is detected and repaired by replay. | 3–4 days |
| **M3** | **Relay service** on Unraid behind NPM Plus (TLS, `wars-relay.schmitzplex.com`), game list, create/join, log store. Web build talks to it. | Two browsers on two machines play 50 days; hashes identical; both logs identical. | 2–3 days (+ TeeJ for the NPM Plus host and DNS) |
| **M4** | **The manual's screens**, element for element: Multiplayer Panel, Configuration, Host Game, Join Game (relay list), Multiplayer Options with chat, Compose Chat Message window and the Chat Messages tab, "Waiting for Opponent", shared speed. Checklist per Fig 5.1–5.11 in `docs/window-checklists.md`. | Every element in §2 present or listed as *n/a* with reason; C3PO review. | 4–5 days |
| **M5** | **Save / Load / reconnect**: host-only Save = log to relay + both browsers' storage; Load from Multiplayer Options when a save with the same two names exists; drop and rejoin mid-game. | Rejoin after a kill: hash equal to the surviving client's. Load: game resumes at the saved day with identical hash. | 2 days |

Sizes are working days for the agent team at the pace of steps 2–4 and are
estimates, not commitments.

---

## 5. Decisions (TeeJ, room #89 and #90, 2026-09-03)

| # | Question | Decision |
|---|---|---|
| 1 | Take Command in head-to-head | **Deferred to v2.** "I know this is possible in the original but let's save it for v2 - implement auto/retreat at this time." v1 Battle Alert offers Simulate Results and Retreat; Take Command shown disabled with the reason. Stays flagged in HANDOFF as a v2 item. |
| 2 | AI stand-in for a disconnected player | **No, not at this time.** The clock waits ("Waiting for Opponent"). |
| 3 | Provider list with one honest entry | **Yes.** |
| 4 | Default player / game names | **Yes.** |
| 5 | Relay hostname | **`wars.schmitzplex.com` for dev**, "assuming we can change it later" - it can: the hostname lives in one client setting and one NPM Plus host entry. |
| 6 | Where the static build is hosted | Pros and cons requested - see §6. |
| 7 | Single player also goes through the command log from M1 | **Yes.** |

---

## 6. Hosting the static build - pros and cons (for decision 6)

Facts that drive the choice: the build is `index.wasm` 39.5 MB (9.6 MB gzip,
7.5 MB brotli) plus a 1.2 MB pack and a few small files; a browser caches it
after the first load, so per-player traffic is one download per version. The
schmitz-wars repo on GitHub is already **public**, so nothing in the pack is
more exposed by any option below. The relay runs on Unraid in every option.

| Option | Pros | Cons |
|---|---|---|
| **A. Unraid, same origin as the relay** - one container serves the static build and the WebSocket relay at `wars.schmitzplex.com` behind NPM Plus | One hostname, one NPM Plus entry, TLS already there; **same origin** so no cross-origin allowances; Authelia can gate it if you ever want the game private; brotli/gzip on by nginx; the files are static, so moving them elsewhere later is a copy. | First load per player rides your home upload (7.5-10 MB, then cached); the game is up only while Unraid is; one more container to run (or the relay serves the files itself, which is ~20 lines). |
| **B. GitHub Pages** from the schmitz-wars repo, published by an Actions workflow that runs the export | Free CDN, no home bandwidth, a public link anyone can open; limits (1 GB site, 100 GB/month soft) are far above need. | Public to everyone, no Authelia; the build must be produced in CI (the export templates are a 1.2 GB download per run unless cached) or committed as a 40 MB binary per version; cross-origin to the relay, so the relay must allow the Pages origin; two places to keep in step. |
| **C. Cloudflare R2 public bucket + custom domain** (Cloudflare Pages is ruled out: its per-file limit is 25 MiB and the wasm is 39.5 MB) | CDN and Cloudflare Access for auth; no home bandwidth for the files. | A third platform and an upload step per version; still cross-origin to the relay; the most moving parts for two players. |

**Recommendation: A for dev and v1.** Same origin, one host entry, nothing new
to learn, and the relay has to be on Unraid anyway. If a public audience ever
appears, B is a workflow file away because the build is static.

Remaining open question: none. **M0 starts on TeeJ's go.**
