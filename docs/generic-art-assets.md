# Generic art: the assets needed

TeeJ, 2026-09-28: "we will be adding 'generic' artwork in the future, we just
need game parity for now" - and "as you go, please make a detailed list of
needed assets". This is that list, filled in as each phase of the plain build
parity plan lands. Every row is a picture the original-look build draws from
the player's art set; generic art replaces it for players without one. Until
then the plain build draws our stand-in (last column).

## Conventions (all rows)

| | |
|---|---|
| Format | PNG, 32-bit RGBA (8 bits a channel, straight alpha), sRGB. Transparent wherever the game shows through. |
| Size | In **frame pixels**: the original's 640 x 480 space. The game scales them up nearest-neighbour - the Command Center by the screen's height / 481 (x1.767 on an 850-high window), windows by 2 - so they are pixel art at the size listed. Larger art (2x, 4x) needs a code change: say so before commissioning. |
| Names | The art set's own paths below (`<side>` = `alliance` or `empire`, the pack's two art skins; `<category>` lower case). A generic set ships as an art set (a zip with its manifest), the same layout. |
| Sides | Two looks per side-specific asset. The layouts are mirrored between the sides (see the Command Center frame). |

## Phase 1: the Command Center

| Asset | File | Size (frame px) | Count | What it is | States / notes | Plain stand-in now |
|---|---|---|---|---|---|---|
| Command Center frame | `windows/command.<side>.png` | 640 x 481 | 2 | The whole screen around the galaxy map: the metal round the map's window, the Message Alert column, the Game Options monitor, the Window Reference Bar shelf, the Control Panel desk and its six monitors, the droids' stands, the two readout boxes at the top. | Opaque metal (it takes the mouse where alpha > 0.5); the map window fully transparent. Places, Alliance / Empire: window (54,35) 488x358 / (118,41) 489x358; Speed Control box at (90,11) / (488,13); resource box at (232,10) / (132,12); Message Alert column from (3,109) / (611,110), nine 27x22 slots 25 apart; Game Options monitor (3,358) 27x34 / (78,196) 32x48; shelf (546,58) 60x262 / (20,46) 55x291, twelve slats; droids below. The monitors' normal look is part of the frame. | Drawn plate #3b3b3b, bevels, wells |
| Message Alert icons | `alerts/<side>.<category>[.lit].png` | 27 x 22 | 36 | One per message category - Loyalty, Fleets, Missions, Resources, Manufacturing, Defense, Conflict, Advice, Chat - in the column beside the map; each opens the Message Index on its category. | Dim (no unread mail) and `.lit` (unread). The unread count is drawn by the game on the corner. | Our 11x11 glyphs, dim / side colour |
| Game Options monitor, pressed | `windows/console_options.<side>.pressed.png` | 27 x 41 / 35 x 57 | 2 | The Game Options monitor held down ("Game Controls"). | Pressed only; drawn at its own place: (3,355) / (79,193). | Our sliders glyph in a well |
| Control Panel monitors, pressed | `windows/console_<monitor>.<side>.pressed.png` | Alliance: system 29x18, fleet 29x17, troop 29x17, personnel 29x17, encyclopedia 28x18, gid 28x17. Empire: 37x24, 34x22, 34x22, 34x22, 36x22, 36x22 | 12 | The desk's six monitors held down: System Finder, Fleet Finder, Troop Finder, Personnel Finder, Encyclopedia, Galactic Information Display. | Pressed only, at the monitors' places (`CommandFrame.Layout` consoles). | Our glyphs in wells on a desk band |
| Agent droid | `windows/droid_agent.<side>.png` | One frame 67 x 116 / 106 x 133; a strip of frames side by side (24 / 16 frames today) | 2 | The advisor (C-3PO / IMP-22 in the original) standing at (541,337) / (0,347). Right-click opens the Agent menu. | Frame 1 = at rest; the rest are its talking animation (with the `.fwa` runs, see the advisor phase). Transparent round the figure: it takes the mouse only on its own pixels. | Name panel ("C-3PO") |
| Message droid | `windows/droid_messenger.<side>.png` | One frame 47 x 69 / 101 x 79; strip (16 frames) | 2 | The message droid (R2-D2 / SD-7) at (316,411) / (302,401). Click opens the Messages. | As the agent. | Name panel ("R2-D2") |
| Speed Control box | `windows/hud_speed.<side>.png` | 106 x 23 / 102 x 24 | 2 | The box the game's day and speed sit in. | The day is drawn by the game in the black window at (12,8) 62x12 / (11,6) 62x11; the bars at (74,9) / (73,7). | Drawn plate, black windows |
| Speed bars | `windows/speed_bars.<side>.<0-4>.png` | 16 x 10 | 10 | The speed indicator: three bars. | Five states: 0 and 1 none lit, then one, two, three lit. | Three drawn bars, side colour |
| Resource displays | `windows/hud_resources.<side>.png` | 300 x 28 / 320 x 30 | 2 | Three panels - raw material, refined material, maintenance - each with its icon on the left. | The figures are drawn by the game, right-aligned 4 px inside each panel's right edge (Alliance 94 / 188 / 286, Empire 104 / 202 / 300). | Drawn panels with the words Raw / Refined / Maint. |
| Sector window corner icons | `icons/<glyph>.<side>[.hover].png` | mission 28x19, fleet 28x18, manufacturing 27x18, defenses 27x19 | 20 (4 glyphs x 2 sides x 2 states, and neutral manufacturing and defenses) | The small glyphs on a system in the sector window. Also the left-hand menu's heading icons (Loyalty uses mission, Fleets fleet, Manufacturing, Defense) and a minimised window's kind on the shelf. | Normal and `.hover`; the glyph sits in one corner of its cell. | Our glyphs (flag, ship, factory, shield) |
| GID menu icons | `windows/gid_menu_<id>.<side>.png` | 20 x 20 (death_star_shields 19 x 20) | 58 | The Galactic Information Display control's menu: an icon for each of its 6 categories and 23 modes (Popular Support, Uprisings, Idle Fleets, ... Death Star Shields). | One state. | Our glyphs for the 6 categories; modes have none |
| Galaxy picture | `screens/galaxy.png`, `screens/galaxy_off.png` | 640 x 480 (RGB) | 2 | The galaxy seen through the map window; `_off` with the display switched off. | Drawn 1:1 at the frame's scale from (21,25) / (84,27). | None (black) |
| GID stars | `gid/<side>.<tier>.png` | 15 x 15 | 16 | A system's marker on the galaxy map in the current display mode, for alliance / empire / neutral / unexplored at the tiers big / mid / low / none. | One state. | Drawn crosses (the map's own) |
| Cursors | `cursors/pointer.png`, `cursors/crosshair.png` | 32 x 32 | 2 | The mouse pointer, and the targeting crosshair. | The hotspot is set per cursor (`Art.CursorHotspot`). | The system's cursors |

## Phase 2: the Message Index

The window (manual p078, Fig 3.18; p077, Figs 2.38 / 3.19) is built from these;
without the art the plain build draws each as a stand-in at the same size
(`src/ui/art_standins.gd`, the same table).

| Asset | File | Size (frame px) | Count | What it is | States / notes | Plain stand-in now |
|---|---|---|---|---|---|---|
| Window frame | `windows/frame.<side>.png` | 470 x 331 | 2 | The frame round the Message Index (and the Encyclopedia and finders later): a border, and on the right the column the side buttons sit in. | Opaque border; see-through opening at (12,14) 400 x 306; its last row clear. The Alliance's side column is a separate picture (below). | Our plate with the opening cut out |
| Message Index plate | `windows/msgindex_plate.png` | 400 x 306 | 1 | The index's face under the frame: the tabs' row, the caption band, the list. | Caption band at (11,74) 373 x 20; the list at (11,95) 373 x 194 (a starfield in the original). The game draws the title, caption and rows. | Grey plate, dark band, black well |
| Alliance side column | `windows/msgindex_side.alliance.png` | 58 x 330 | 1 | The Alliance's column of side buttons, at (412,0). | One state. | Grey plate |
| Selection bar | `windows/msgindex_selection.<side>.png` | 356 x 21 | 2 | The bar behind the picked row. | The game draws the title on it. | Solid side colour |
| Category tabs | `tabs/msg_<category>[.<side>][.pressed].png` | all, conflict, fleets, loyalty, manufacturing, resources 36 x 41; advice 37 x 41; chat, missions 35 x 41; defense 34 x 41 | 28 | The ten tabs across the top: All, Loyalty, Fleets, Missions, Resources, Manufacturing, Defense, Conflict, Chat, Advice. | Plain and `.pressed` (the open tab). Advice, Fleets, Loyalty and Missions per side; the rest one for both. The game draws the unread count. | Our glyphs; the open tab sunk, glyph in side colour |
| Row icons | `windows/msgicon.<category>[.<side>][.picked].png` | 15 x 15; loyalty, manufacturing, missions 15 x 16 | 28 | The category icon at the start of each message row. | Plain and `.picked` (on the selection bar). Advice, Fleets, Loyalty, Manufacturing, Missions per side; Chat, Conflict, Defense, Resources one for both. | Our glyphs in side colour, white when picked |
| Select All / Delete | `buttons/msgindex_select_all[.pressed].png`, `buttons/msgindex_delete[.pressed].png` | 56 x 20 | 4 | The band's two buttons: pick every message on the tab; delete the picked ones. | Plain and pressed. | Our list and bin glyphs |
| Side buttons | `buttons/<button>.<side>[.pressed / .disabled].png` for `ency_close`, `msgindex_summary`, `msgindex_post`, `msgindex_open`, `msgindex_compose` | Alliance 32 x 31, Empire 44 x 41 | 26 | Close; Message Summary (read the picked message / back to the index); Post Messages with Alert / Silently; Open Window (go to the message's subject); Compose Chat Message. | Close and Post: plain, pressed. The other three also disabled. Places: Alliance x 423 at y 25 / 93 / 147 / 201 / 255; Empire x 426 at y 21 / 89 / 148 / 207 / 266. | Our close, page, bell, window, pencil glyphs |
| Decision buttons | `buttons/decision_ok[...]`, `buttons/decision_cancel[...]` | 51 x 35 | 6 | The tick and cross: continue / abort a mission report that asks, send / cancel a chat message (also Create Mission and other dialogs later). | Plain, pressed, disabled. | Tick and cross glyphs |
| Reading arrows | `buttons/msgsummary_up[...]`, `buttons/msgsummary_down[...]` | 19 x 15 | 6 | Step to the previous / next message while reading. | Plain, pressed, disabled. | Up and down glyphs |
| Scroll bar | `buttons/scroll_up.png`, `scroll_down.png` 13 x 9; `scroll_thumb_top.png` 13 x 6, `scroll_thumb_mid.png` 13 x 12, `scroll_thumb_bottom.png` 13 x 6 | as listed | 5 | The list's scroll bar (and every long list's). | The thumb is its top, as many middles as it takes, and its bottom, stacked. | Arrow wells; a grey thumb |
| Message pictures | `windows/message.<id>.png` (STRATEGY 1000-1075) | 400 x 200 (the reading view's slot; not re-measured on a current art set) | up to 76 | The picture shown above a message's text: a scene for each kind of news. | One state. | None (black) |
| Report scenes | `windows/report.<kind>.png`, with `characters/<id>.report.png` figures | 400 x 200 slot (as above) | per mission kind / character | A mission report's scene, the character's figure laid over it. | As the message pictures. | None |
