# Multiplayer screens - design from the manual's figures (M4 + the M5 screens)

**Status:** BUILT, all sections (2026-09-03; gates `tests/mp_screens.gd` 58/58 and `tools/mp-flow-local.ps1 -Days 16 -Load` 15/15 + 15/15, which also exercises chat, the Game Options pause and a slower opponent). REVIEWED 2026-09-03. Drafted by Lord Vader from the figures themselves
(manual p156-p163 = PDF p152-p159, re-read for this document); reviewed by Doof
(room AM-XVTDFFDA4FY59ZFQZP64YEYU63 #6): no figure element dropped; seven doc
corrections applied below; A-D answered in section 14. Build follows section 14 F. CLAUDE.md rule 0 applies: every element a figure names is a
requirement; deviations are listed, not silently made.

Sources: manual Figs 5.1-5.11 (PDF p152-p159); `GAMEPLAY.md` chapter 5 digest;
`docs/multiplayer-plan.md` section 2 (element inventory) and section 5
(TeeJ's decisions: one honest provider entry; Take Command deferred; no AI
stand-in; default names fine). Code facts cite the port's files.

---

## 0. How the screens hang together

```
Menu.tscn (Shuttle Cockpit)
  [Multiplayer panel]  ──►  Multiplayer Configuration (Fig 5.2)
                              ├─ Setup Game ──► Host Game (5.3) ──────────────┐
                              └─ Connect To Game ──► Locate Session (5.6)      │
                                                       └─► Join Game (5.8) ───┤
                                                                              ▼
                                                    Multiplayer Options (5.9) - both players, host edits
                                                                              │ checkmark (host)
                                                                              ▼
                                                    Main.tscn in lockstep (GameManager + LockstepSession)
                                                      ├ Display Message Index, Chat Messages tab (5.10)
                                                      ├ Compose Chat Message (5.11)
                                                      ├ Game Speed menu - effective = slowest of the two (p163)
                                                      └ Game Options screen ⇒ opponent sees Waiting for Opponent (p163)
```

**`MpSetup.reset()` on every exit path** (Doof's review): the static outlives the
screens, so stale state is the classic session bug. Reset is called by: Cancel on
each of the four screens (5.2, 5.3, 5.6, 5.8, 5.9), Previous from Multiplayer
Options (the seat is given up), Leave Game in section 11, Exit to Menu / Exit to
Desktop on the Game Options screen, and game end in `GameManager`. A relay
connection still open is closed by the same call.

`GameManager`'s clock: `if MpSetup.session != null: session.try_tick()` **else**
the single-player path (`AdvanceDay` + `CommandBus.day_done`) - the else branch
is explicit, so single player is untouched.

The four Cockpit-side screens are full-screen `Control` scenes like `Menu.tscn`,
not `DraggableWindow`s: the manual shows them as the Cockpit's own console
panel with a bottom button bar. One shared scene, `MpBottomBar.tscn`, carries
the bar every figure repeats: **Proceed** (right arrow), **Previous / Go back**
(left arrow) where the figure has it, **Cancel** (X, "return to the Shuttle
Cockpit").

State between screens lives in one static, `src/net/mp_setup.gd`
(`MpSetup`): relay URL, player name, game name, the `RelayClient`, my seat,
the room's settings. `GameManager` reads it on `Main.tscn` load: when a session
is active it installs the `LockstepSession` and its clock ticks through
`session.try_tick()` instead of `AdvanceDay` (today's timer at
`src/ui/game_manager.gd:92-95`).

**Relay URL.** In the browser: the page's own origin, `ws(s)://<host>/ws`
(hosting option A, same origin, `docs/multiplayer-plan.md` section 6). On the
desktop: `--relay=` or the default `wss://wars.schmitzplex.com/ws`. Never a
field on a screen - the manual has no such field, and the player should never
see it.

---

## 1. Multiplayer Panel (Fig 5.1, p156)

| Manual | Design |
|---|---|
| "the small panel at the lower left that depicts a Rebel soldier and an Imperial stormtrooper facing off" | A **Multiplayer** button at the **lower left** of `Menu.tscn`, outside the centred column (the column is the single-player configuration; the panel is a separate fixture of the Cockpit). Tooltip: "Multiplayer - two players head-to-head". |

**Deviation:** no artwork; a labelled button, as every other Cockpit control in
the port already is.

**Addition, requested by TeeJ (room AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #80):** a
**Provide feedback** checkbox under Game Options on the Cockpit, remembered in
`user://`. When ticked, any game this client starts shows a feedback box at the
bottom of the left column (note, Submit, result line); a note goes to the
relay's `POST /feedback` with the day, seed, settings, client facts and this
client's session log, or is kept under `user://feedback/` when the relay is
unreachable. BACKPORT-LOG #15. Not from the manual.

## 2. Multiplayer Configuration screen (Fig 5.2, p157)

Every element the figure shows, top to bottom:

| # | Figure element (its own wording) | Design |
|---|---|---|
| 1 | Caption: "Please select a service provider for the type of connection you want to use from the list below." | Label, verbatim. |
| 2 | Provider list; "the provider that is currently selected appears in red" | An `ItemList` with **one** entry, **"Internet Connection"**, pre-selected, drawn in red (decision 3: one honest entry; IPX, modem and serial are lies in a browser). |
| 3 | Caption: "How do you want to play?" | Label, verbatim. |
| 4 | Two buttons: **Connect To Game** (left, figure callout "Join game") and **Setup Game** (right, callout "Host game"); "the currently selected option will be depressed and the text will appear dark" | Two toggle buttons in a `ButtonGroup` (the menu's `SetupToggleButton` pattern, `src/ui/menu.gd:65`). Default: none pressed; Proceed disabled until one is. Pressed = depressed with dark text (theme override). |
| 5 | Bottom bar: **Proceed** (right arrow), **Cancel** (X) | `MpBottomBar` with Proceed and Cancel; **no Previous** on this screen (the figure has none - it is the first screen). |

Proceed → Host Game when Setup Game is pressed, Locate Session when Connect To
Game is pressed. Cancel → `Menu.tscn`.

## 3. Host Game screen (Fig 5.3, p158)

| # | Figure element | Design |
|---|---|---|
| 1 | Caption "What would you like your player name to be?" + box (callout "Enter your name here"; example "Han Solo") | Label verbatim + `LineEdit`. Default: the last name used (browser `localStorage` / `user://mp.cfg`), else **"Player"**. |
| 2 | Caption "What would you like to call your game?" + box (callout "Name your game"; example "The End of the Empire") | Label verbatim + `LineEdit`. Default: the last game name used, else **"<player>'s game"**. |
| 3 | Bottom bar: **Proceed**, **Go back**, **Cancel** | `MpBottomBar`, all three. |

**Deviation (recorded in the plan):** the manual defaults are the Windows 95
user name and the computer name; a browser exposes neither.

Proceed: `RelayClient.create(game_name, {}, open=true)` → on `room` → Multiplayer
Options as host. Go back → Configuration. Cancel → Cockpit.

## 4. Locate Session dialog (Fig 5.6, p159) - the join side

| # | Figure element | Design |
|---|---|---|
| 1 | Title bar "Locate Session" with X | A modal `Window`/dialog titled **Locate Session**, X closes = Cancel. |
| 2 | Text "Enter the computer name or IP address of the session host, or leave blank to search." | **Open question A** (below): keep the manual's sentence, or say what the box really takes on the web. Proposed: "Enter the game code of the session host, or leave blank to search." |
| 3 | One text box (callout "Enter IP address") | `LineEdit`, placeholder `XXXXXX`, 6 characters upper-cased as typed (the relay's code alphabet). |
| 4 | **OK** (callout "Proceed"), **Cancel** | OK: blank → `RelayClient.list()` and open Join Game with the list; a code → Join Game with that one game listed (from `join` on Proceed). Cancel → Configuration. |

**Deviation (recorded in the plan):** a typed value is a game code, not an IP.
The relay lists only `open` games (`relay/server.ts` `listing`); a private game
(created with `open=false`) is reachable only by its code - the manual's "give
[the IP] to you before you try to connect" (p160).

## 5. Join Game screen (Fig 5.8, p161)

| # | Figure element | Design |
|---|---|---|
| 1 | "What would you like your player name to be?" + box (callout "Enter a name") | As Host Game #1. |
| 2 | "Select a game to connect to from the following list." + list (callout "Choose game to join"; example "End of the Empire") | Label verbatim + `ItemList` of the relay's rooms by game name. "Unless you are playing on a LAN where others may be playing, there will only be one game name listed" - the list is what the relay holds, however many. Re-polled every 2 s while the screen is open. **Deviation (addition):** the host's player name is shown after the game name, "The End of the Empire (Han Solo)" - the figure lists game names only. |
| 3 | Bottom bar: **Proceed**, **Previous**, **Cancel** | `MpBottomBar`, all three. Proceed disabled until a game is selected. |

Proceed: `RelayClient.join(code)` → on `joined` → Multiplayer Options as guest;
on `error` ("game is full", "no such game") an alert with the relay's text and
the screen stays. Previous → Locate Session. Cancel → Cockpit.

## 6. Multiplayer Options screen (Fig 5.9, p161-p162) - both players; host edits

Layout in the figure, top to bottom, and the callouts:

| # | Figure element | Design |
|---|---|---|
| 1 | "Which side do you want to play?" + two symbol buttons (callout "Choose your side"; "the red symbol for the Rebel Alliance or the green symbol for the Galactic Empire") | Label verbatim + two toggle buttons in a group: **Rebel Alliance** (red) and **Galactic Empire** (green), no artwork. Host only; the guest sees them disabled showing the host's choice. |
| 2 | "What size galaxy would you like?" + three buttons (callout "Choose galaxy size (standard, large or huge)") | Label verbatim + **Standard / Large / Huge** toggles (100 / 150 / 200 systems, p161; `Enums.GalaxySize` Small/Medium/Large, relabelled here with the manual's words). Host only. |
| 3 | **Standard Game** / **HQ Only Victory** (callout "Choose game length") | Two toggles in a group, labelled exactly so. Tooltips carry the win conditions verbatim from p162. Host only. |
| 4 | **Load** button, right of #3 (callout "Load multiplayer saved game"; p162: "only be available if you have saved a game from a previous session with your current opponent") | **Load Game** button, host only, **enabled only when** the relay's `saves` for the host and for the guest intersect (both names in the same started game). Opens the Load list (section 7). |
| 5 | **Chat>** line (callout "Type chat messages"; p162: "click your mouse in the space to the right of Chat>, then type your message. Press Enter to send it") | A row: label **"Chat>"** and a `LineEdit` that sends on Enter (`RelayClient.chat`) and clears. Both players. |
| 6 | Scrolling view under it (callout "View chat messages and game settings"; the figure's lines read like "Luke Skywalker: ..." and "Darth Vader: Standard game victory selected. Small galaxy size selected. Host has chosen the Alliance side.") | A read-only `RichTextLabel` log. Chat lines as "<player>: <text>". **Every settings change the host makes is echoed into this log as a line from the host**, e.g. "Darth Vader: Large galaxy size selected." - that is what the figure shows, and it is how the guest learns the settings. Also "<player> has joined." / "<player> has left." from the relay's `guest` / `left` lines. |
| 7 | Bottom bar: **Start Game (Host)** checkmark, **Previous**, **Cancel** | `MpBottomBar` with a **checkmark** as Proceed: host only ("only the host starts", relay). Enabled once a guest is seated. Guest: checkmark disabled with tooltip "The host starts the game." Previous → Host Game / Join Game. Cancel → Cockpit (the relay closes the seat). |

**No difficulty control** (GAMEPLAY.md ★ note): head-to-head uses the
Multiplayer column; nothing to choose.

**Deviation (no artwork):** #1's red and green **symbols** are labelled buttons
tinted red and green; the port has no artwork anywhere.

**Wire.** Every host edit → `RelayClient.set_settings({side, size, hq_only})`;
the guest receives `settings` and repaints. Start: `RelayClient.start()`; both
receive `started` with the final settings; both build the same header (seed
chosen by the host at Start and carried in the settings; `size`; `hq_only`;
`host` = host's side id; `humans` = both) and load `Main.tscn`.

**Guest's view:** identical screen; #1-#4 disabled, #5-#6 live, checkmark
disabled. Nothing is hidden - "This screen also lets both players chat with
each other before the game is started" (p161).

## 7. Load Game list (from #4 above; p162 "Load a Saved Multiplayer Game")

The manual names the button and the rule, not a picker figure (Fig 5.9 shows
only the button). The single-player Load Game / Game Configuration screen it
refers to ("See the Save Game/Load Game section") is not in the port yet.
Design, kept to what p162 states:

| Element | Design |
|---|---|
| List of saves "from a previous session with your current opponent" | A modal list of the intersection of the two players' `saves` (relay `saves` per player, `docs/m3-plan.md`), newest first: game name, day reached, last played (date). |
| "it will use the game size and difficulty settings from your previous game. You will not need to choose them again" | Choosing one **greys #1-#3** on the Options screen and fills them from the save's settings; the log line "Darth Vader: Loaded <game name>, day N." goes to #6. Start then rejoins both clients into that room (`LockstepSession.rebuild_from_log`, gated in BACKPORT-LOG #11) instead of creating a new one. |
| Cancel | Back to the Options screen unchanged. |

**Open question B:** what a "day reached" means for the list - the last day
both sides hashed (what `rebuild_from_log` resumes at). Proposed: show that.

## 8. Display Message Index, Chat Messages tab (Fig 5.10, p162-p163)

The window exists (`src/ui/message_window.gd`, `MessageWindow.tscn`). Changes:

| # | Figure element | Today (code) | Design |
|---|---|---|---|
| 1 | Tab title **"Chat Messages"** (callout "Show chat messages") | Tab node `Chat`, title "Chat" (`message_window.gd:51`) | Set the tab title to **"Chat Messages"** (the node name stays `Chat`, the enum key). |
| 2 | Row "Message From The Empire" (callout "Incoming message") | Row text "[Day N] <Title>", title "Message from <side display name>" (`command_applier.gd:151`) | Title becomes **"Message From The <Empire/Alliance>"** - the figure's wording, faction's short name. |
| 3 | "Double-click a message to view it" | Single click opens (`ShowDetail`, `message_window.gd:332`) | **Double-click opens the message**; single click keeps selecting the row (pick-then-delete needs it). Godot: `Button.gui_input` with `double_click`. Both gestures work, as the plan states. |
| 4 | **Compose chat message** button, right-hand column, bottom (callout "Compose chat message"; p163 "the button on the bottom right-hand side of the window") | none | A **Compose Chat Message** button at the **bottom of the right-hand column**, present only in a head-to-head game (`GameSettings.HumanFactions.size() > 1`). Opens section 9. |
| 5 | **Delete selected messages**, **Select all messages** (callouts, top right of the list) | Both exist (`_selectAllBtn`, `_deleteSelectedBtn`, `message_window.gd:137-146`) | unchanged. |

## 9. Compose Chat Message window (Fig 5.11, p163)

A `DraggableWindow`, `ComposeChatMessageWindow.tscn`, sized like the Message
window it comes from:

| # | Figure element | Design |
|---|---|---|
| 1 | Title **"Compose Chat Message"** | `WindowTitle`. |
| 2 | Picture area (a figure at a console) | Empty panel. **Deviation (no artwork).** |
| 3 | Text line at the bottom (callout "Type your message here"; example "I have you now.") | A `LineEdit`, placeholder **"Type your message here."**, focused on open; Enter = Send. |
| 4 | **Send message** (checkmark, bottom right of the text area) | Button "Send message": `CommandBus.issue("chat", {text})`, then the window closes. The command's applier posts the message to the opponent's Chat Messages (`command_applier.gd:144-153`). **No copy for the sender** (question C, settled): the tab shows "incoming chat messages" (p163) and nothing else. |
| 5 | **Cancel** (X, under Send) | Closes without sending. |
| 6 | **Close button** (top right of the window) | The window's close, same as Cancel. |
| 7 | **Return to Display Message Index** (right column, first button) | Button: closes this window and opens (or restores) the Message Index on the Chat Messages tab (`UIManager.OnMessageIndexClicked("Chat")`). |

**Question C (settled, Doof agreed):** no sender-side copy - "incoming" is the
manual's word, and a copy would be an invented message type.

## 10. Game Speed - "the slowest speed set on either computer" (p163)

| Manual | Today (code) | Design |
|---|---|---|
| Either player adjusts; game runs at the slower; five settings Pause / Very Slow / Slow / Medium / Fast | The GID bar's speed menu, five radio items (`game_manager.gd:138-155`); `set_speed`/`pause`/`resume` commands exist but the clock ignores them (`command_applier.gd:155-158`) | Choosing a speed issues `set_speed` (the local menu item checks as chosen) and `LockstepSession.set_speed`; the timer runs at `effective_speed()` = min(mine, theirs). The readout shows my setting, and **"Slow (set by opponent)"** when the opponent's slower setting is what governs, so a player knows why the game is slower than they set. **Addition (not a figure element):** the "(set by opponent)" suffix; the manual only states the rule. Speed and pause travel as the M2 protocol's `speed` line rather than as commands, so a rebuilt game resumes at the speeds the log last recorded. **Deviation, requested by TeeJ (room AM-LFGGG3LVQSSJGXSP7P7JE9Q745 #75, plan #77 reviewed by Sonnet #78):** a host-chosen **Game speed rule** row on Multiplayer Options, *Slowest wins* (the manual, default) or *Average*: floor((a + b) / 2), so Slow + Fast = Medium, Fast + Very Slow = Slow, adjacent settings give the slower; Pause on either side pauses both under either rule. Under Average the face reads "(averaged with opponent)" when the effective speed differs from your own. `LockstepSession.combine_speeds`, `tests/speed_rule.gd`. |
| Pause on the Game Speed menu; "click on the checkbox to resume play" | Pause is modal with a **Resume** button (`_pauseBox`, `game_manager.gd:157-167`) | Pause issues `pause`; the pauser sees today's box; Resume issues `resume`. The **opponent sees Waiting for Opponent** (section 11) while the other side is paused - a paused opponent is one who is not playing, and the manual's "slowest speed" with Pause as a speed says the same. |

## 11. Waiting for Opponent (p163)

"Bring up the Game Options Screen. Your opponent will receive a Waiting for
Opponent message, until you return to the game."

| Element | Design |
|---|---|
| Trigger | The other side's Game Options screen is open (`UIManager.OnMenuButtonClicked`, `ui_manager.gd:196`, issues `pause` on open and `resume` on close) - the manual's case. **Additions (not in the manual):** the other side chose Pause on the Game Speed menu, and the other side's connection dropped (`LockstepSession.State.WaitingOpponent` for longer than 3 s); the same message serves all three, since in each the opponent is not playing. |
| The message | A modal, exclusive panel, title **"Waiting for Opponent"**, text "Waiting for opponent..." - and for a dropped connection, a second line "Connection to your opponent was lost; waiting for them to rejoin." |
| Controls | **Question D (settled, Doof agreed):** the manual gives none - the message clears "when you return to the game". No button for the first 60 s; then a **Leave Game** button appears. Leave asks first: "Leave this game? It will be available to reload from either player." - Yes returns to the Cockpit (`MpSetup.reset()`); the game stays on the relay as a save both can Load later. |

## 12. Saving (p163-p164) - the host's Game Options screen

"Follow the same procedure as you would to save a single player game ... only
the host player can save the game ... a saved game on both computers in the
same saved game slots."

| Fact | Where |
|---|---|
| The single-player Game Options screen in the port has **Resume, Exit to Menu, Exit to Desktop** only (`src/ui/in_game_menu_window.gd:10-18`); single-player **Save/Load is not implemented** in the port. | code |
| Every line of a head-to-head game is already on the relay and in each client's `user://` log; the game IS saved as it is played (BACKPORT-LOG #11). | code |

Design: a **Save Game** button on the Game Options screen, **host only** (the
guest's is disabled, tooltip "Only the host can save."). It does not write
anything new; it confirms: "Saved on both computers: <game name>, day N." after
the relay has acknowledged every line (the client's `received` counter against
the relay's `lines`). That keeps the manual's gesture and its promise without
inventing a slot system the port does not have.

**Open question E:** whether TeeJ wants single-player Save/Load built now (it
is a manual feature the port lacks, and the M1 log makes it cheap: the log is
the save). It is not part of the multiplayer plan; flagging it, not building it.

---

## 13. Checklist for the build (rule 0 re-check, figure by figure)

| Figure | Elements to tick off when built |
|---|---|
| 5.1 ✓ | Multiplayer control, lower left of the Cockpit |
| 5.2 ✓ | "How do you want to play?"; Connect To Game; Setup Game; Cancel. **Deviation (TeeJ, room #197 item 2):** the provider list, the depressed selection and Proceed are gone - one connection exists, so clicking a button goes straight on |
| 5.3 ✓ | player-name caption + box; game-name caption + box; Proceed; Go back; Cancel |
| 5.6 ✓ | title "Locate Session"; instruction text; one box; OK; Cancel. **Deviation (TeeJ, room #197 item 4 / #68):** the code is required (OK waits for six characters) and OK looks it up and joins straight into Multiplayer Options; Fig 5.8's player-name box moved here; "blank = search" went with the list |
| 5.8 ✗ | **Removed (TeeJ, room #197 item 4 / #68):** the code entered on Locate Session already names the game, so the list was a second pick of the same thing |
| 5.9 ✓ | side caption + two symbols (red/green); size caption + three; Standard Game / HQ Only Victory; Load; Chat> + entry, Enter sends; chat + settings view; checkmark Start (host); Previous; Cancel |
| Load ✓ | list of shared saves ("Day N"); settings restored and greyed; Cancel |
| exits ✓ | `MpSetup.reset()` on every Cancel, Previous-from-Options, Leave Game, Exit to Menu/Desktop, game end |
| 5.10 ✓ | tab "Chat Messages"; incoming row wording; double-click opens; Compose button bottom right; Delete selected; Select all |
| 5.11 ✓ | title; "Type your message here"; Send message; Cancel; Close button; Return to Display Message Index |
| p163 speed ✓ | five settings; slowest governs; readout shows the governing side |
| p163 pause ✓ | Game Options open ⇒ opponent's Waiting for Opponent; Pause on the menu ⇒ same; checkbox/Resume resumes |
| p163 save ✓ | host-only Save Game on the Game Options screen; confirmation names the game and day |

## 14. Open questions (for Doof, then TeeJ)

| | Question | Proposed |
|---|---|---|
| A | Locate Session wording: keep "computer name or IP address" verbatim, or say "game code"? | **Settled (Doof #6):** "game code", placeholder XXXXXX - the manual's words would be a lie on the web; recorded deviation. |
| B | What "day" the Load list shows | **Settled:** the last day both sides hashed - the day the game resumes at - shown as "Day 42", like the in-game date. |
| C | Sender's own copy of a chat message in their Chat Messages tab | **Settled:** no - "incoming" is the manual's word. |
| D | A way out of Waiting for Opponent when the opponent never returns | **Settled:** Leave Game after 60 s, behind a one-sentence confirmation; the game remains a loadable save. |
| E | Single-player Save/Load (not in the port; not in the MP plan) | flag to TeeJ; not built here. |
| F | Build order | 5.2 → 5.3 → 5.6/5.8 → 5.9 → hook GameManager to the session (this is the first playable head-to-head) → 5.10/5.11 → speed/pause/waiting → Save/Load. |
