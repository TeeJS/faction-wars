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

## Phase 3: the sector window

The window (manual p025, Fig 2.8) draws its own starfield panel, frame, bars
and names; these are its pictures. The GID stars also draw the galaxy map.

| Asset | File | Size (frame px) | Count | What it is | States / notes | Plain stand-in now |
|---|---|---|---|---|---|---|
| Planet pictures | `planet_sprites/<n>.png` | 37 x 37 | 26 | A system's picture in the sector window, by the pack's `artwork` number (1-26). | One state; transparent round the planet. | A shaded disc, each number its own muted colour |
| Corner icons | `icons/<glyph>.<side>[.hover].png` | manufacturing 27 x 18, fleet 28 x 18, defenses 27 x 19, mission 28 x 19 | 20 (already listed in phase 1) | The glyphs round a system's picture: Manufacturing (top-left of its cell, glyph 11 x 8), Fleet (top-right, 17 x 9), Defenses (bottom-left, 10 x 9), Mission (bottom-right, 11 x 11). Each opens that window. | Normal and `.hover` (the glyph a pixel larger). Manufacturing and Defenses also `.neutral`. | Our glyphs in the side's colour, white when hovered |
| En-route fleet icon | `icons/enroute.<side>.png` | 20 x 20 | 2 | A fleet on its way to a system. | One state. | Our ship-with-trail glyph |
| Uprising icon | `icons/uprising.png`, `icons/uprising.hover.png` | 20 x 20 | 2 | A system in uprising. | Normal and hover. | Our flame glyph, orange |
| Title boxes | `buttons/title_close.png`, `title_minimize.png`, `title_system.png`, `sector_switch[.pressed].png` | 14 x 14 | 5 | Close, minimise, the system box, and the sector window's switch-to-the-other-side box. | Switch has a pressed state. | Our close, bar, planet and arrows glyphs |
| GID stars | `gid/<side>.<tier>.png` | 15 x 15 | 16 (already listed in phase 1) | A system's star on the galaxy map and under its picture in the sector window: alliance, empire, neutral, unexplored at big / mid / low / none. | One state. | A plus in the side's colour, reach 7 / 5 / 3 / 1 |

## Phase 4: the Status windows

One window for a character, a unit, a facility, a fleet, a mission or a
build queue (manual p064; Figs 3.28, 3.29, 3.61): modal, the game's fields in
a list, a picture, the name, Encyclopedia and the close diamond.

| Asset | File | Size (frame px) | Count | What it is | States / notes | Plain stand-in now |
|---|---|---|---|---|---|---|
| Status plate | `windows/status_plate.<side>.png` | 379 x 272 | 2 | The whole Status window. | Field list panel at (3,12) 228 x 247 (the title centred over it at y 18, lines from y 47, a scroll bar at x 214), picture panel (242,15) 130 x 98, name panel (242,131) 130 x 55; the buttons below at (258,218) and (324,218). | Grey plate with three black wells |
| Encyclopedia button | `buttons/status_encyclopedia[.pressed / .disabled].png` | 32 x 31 | 3 | Opens the Encyclopedia on the subject. | Plain, pressed, disabled. (The close diamond is `ency_close.alliance`, phase 2.) | Our book glyph |
| Fleet picture | `windows/status_fleet.<side>.png` | 122 x 50 | 2 | A fleet's picture in the picture panel. | One state. | Our fleet glyph in the side's colour |
| Damaged fleet picture | `windows/status_fleet_damage[.<side>].png` | 122 x 50 | 3 | A fleet with a damaged ship. | One state. | Our fleet glyph in orange |
| Regiment spotlight | `windows/status_backdrop.troops.png` | 122 x 50 | 1 | The grey pool of light a trooper regiment's picture stands in. | One state. | A soft grey ellipse |
| Subjects' pictures | `characters/<id>.png`, `units/<id>.png`, `facilities/<id>.png` (the Encyclopedia's) | up to 130 x 98 in this panel | one per character / unit / facility | The subject shown in the picture panel. | Listed fully with the Encyclopedia (phase 6). | None |

## Phase 5: the system windows (Manufacturing, System Defenses, Fleet) and the Mission window

Manuals p045-p046 (Manufacturing), p105 (Defenses), p112-p113 (Fleet), p109
Fig 3.51 (Mission). Each window's title bar, in the system's side colour, is
drawn by the game with the title boxes (phase 3).

| Asset | File | Size (frame px) | Count | What it is | States / notes | Plain stand-in now |
|---|---|---|---|---|---|---|
| System Defenses plate | `windows/defense_background.png` | 235 x 304 | 1 | The window's face: the tabs' band at the top, a scene below that the cards sit on. | Tabs' band (2,2) 231 x 48; the rest (2,52) 231 x 250. | Grey plate, black band, dark well |
| Manufacturing plate | `windows/mfg_background.png` | 226 x 304 | 1 | The window's face: the tabs' band, a dark band, a scene below. | Tabs' band (0,2) 226 x 48; dark band (2,53) 222 x 71; the rest (2,126) 222 x 176. | Grey plate, black and dark bands, well |
| Producers' column | `windows/mfg_column.png` | 46 x 226 | 1 | The Manufacturing page's left column: a shipyard's, a training facility's and a construction yard's picture, each over a black count bar. | Pictures at y 0 / 81 / 162 (46 x 46), bars at y 48 / 129 / 209 (46 x 16), clear between. | Three wells with our ship, helmet and crane glyphs |
| Production row frame | `windows/mfg_row.png` | 166 x 79 | 1 | The frame of each of the Manufacturing page's three rows. | Grey band on top; see-through (1,14) 161 x 55; black bar (1,70) 161 x 7. | Grey frame with the opening cut out |
| Row header | `windows/header.<side>[.lit].png` | 162 x 13 | 6 | The bar across the top of a production row, in the side's colour (alliance, empire, neutral). | Plain and `.lit`. The game draws the row's title on it. | The side's colour, dimmer unless lit |
| Mine pictures | `windows/mine_tile.png`, `windows/mine_pile.png` | 67 x 35 | 2 | The Mines page: a mine's tile, and its pile of raw material. | One state each. | Our mine glyph in a well; in orange |
| Card plate | `windows/card_plate.png` | 61 x 25 | 1 | The plate behind every miniature card (a unit, facility or character in a list). | One state. | A soft grey spotlight |
| Card overlays | `windows/card_enroute.png`, `card_transit.png`, `card_injured.png`, `card_building.<side>.png` | 61 x 25 | 5 | A card's state: en route, in transit, injured, being built (the side's grid). | One state each. | Tinted spotlights; our cross; a grid in the side's colour |
| Fleet window plate | `windows/fleet_background.png` | 235 x 304 | 1 | The Fleet window's face: a band on top, space below where the fleet tiles sit. | Band 0-17; the rest (2,18) 231 x 284. | Grey plate, black well |
| Fleet panel | `windows/fleet_panel.<side>.png` | 132 x 266 | 2 | The right-hand panel: the opened fleet's picture above, its list below. | The list outlined at (3,95) 126 x 168 in the side's colour. | Black panel, side-colour outline |
| Fleet tile frame | `windows/fleet_tile.<side>.png` | 73 x 47 | 2 | The frame round a fleet's tile in the left column. | Clear inside. | A side-colour outline |
| Fleet miniatures | `windows/fleet_small.<side>.png` 66 x 25; `fleet_small_damage.<side>.png`, `fleet_small_glow.<side>.png` 61 x 25; `fleet_large_glow.<side>.png` 122 x 50 | as listed | 8 | A fleet's small picture on its tile; the damage flames and the engine glow laid over it (small, and over the large picture when it moves). | One state each. | Our fleet glyph; flame and trail glyphs |
| Fleet badges | `windows/fleet_badge_<fighter / troop / personnel>.<side>.png` | 15 x 11 | 6 | The little marks on a fleet's tile for carried fighters, troops and personnel. | One state. | Our fighter, helmet and person glyphs |
| Fleet tabs | `tabs/fleet_tab_<ship / fighter / troop / personnel>.<side>[.pressed / .grey].png` | ship and personnel 30 x 29; fighter and troop 31 x 29 | 22 | The Fleet window's four tabs. | Plain, pressed; grey (empty) except ship. | Our glyphs; open tab sunk in side colour |
| System Defenses tabs | `tabs/personnel.<side>`, `troops.<side>`, `fighters.<side>`, `planetary_shield`, `planetary_battery` `[.pressed / .grey].png` | 36 x 33 | 24 | Personnel, Troops, Fighters, Shields, Batteries. | Plain, pressed, grey. | Our glyphs |
| Manufacturing tabs | `tabs/manufacturing.<side / neutral>`, `shipyards`, `training_facilities`, `construction_yards`, `refineries`, `mines` `[.pressed / .grey].png` | 36 x 33 | 24 | Manufacturing, Shipyards, Training Facilities, Construction Yards, Refineries, Mines. | Plain, pressed, grey. | Our glyphs |
| Mission window plate | `windows/mission_window.png` | 235 x 304 | 1 | The Mission window's face: the missions' tile column on the left, the target and team panels on the right. | Panels outlined at (103,22) 126 x 121 and (103,142) 126 x 153; the target's well (108,37) 114 x 53. | Grey plate, outlines and a well |
| Mission tile frame | `windows/mission_frame.<side>.png` | 73 x 48 | 2 | The frame round a mission's tile. | Clear inside. | A side-colour outline |
| Mission tabs | `tabs/mission_agents_tab.<side>[.pressed].png`, `mission_decoys_tab.<side>[.pressed / .grey].png` | 61 x 16 | 10 | The Agents and Decoys tabs. | Plain, pressed; decoys grey when there are none. | Our person and outlined-person glyphs |
| Mission tiles | via `Art.MissionTile` (`missions/<id>.<side>.png`) | 73 x 48 (the frame's size) | per mission kind and side | Each mission kind's picture on its tile. | One state. | None |
| Miniatures | `units/<id>.png`, `facilities/<id>.png`, `characters/<id>.png` miniatures (`Art.Miniature`) | 61 x 25 | one per unit / facility / character | The picture on each card. | Listed with the Encyclopedia (phase 6). | None (the card plate alone) |

## Phase 6: the finders and the Encyclopedia

The four finders (manual p075 Fig 3.12, p124-p126) and the Galactic
Encyclopedia sit in the Message Index's frame (`windows/frame.<side>.png`,
phase 2) with its close button and scroll bar.

| Asset | File | Size (frame px) | Count | What it is | States / notes | Plain stand-in now |
|---|---|---|---|---|---|---|
| Finder plates | `windows/finder_fleets.<side>`, `finder_ships.<side>`, `finder_personnel.<side>`, `finder_specforces.<side>`, `finder_troops.<side>`, `finder_systems` `.png` | 400 x 306 | 11 | Each finder's face: the band above (the name field, the tabs, the caption), the list below. | Band from (25,33) 350 wide; the list (25,125) 349 x 166 - from y 120 on Personnel, 131 on Special Forces and Troops. | Grey plate, dark band, black list |
| Encyclopedia plates | `windows/ency_index_plate.png`, `windows/ency_topic_plate.png` | 400 x 306 | 2 | The Index page (topic field, database tabs, caption, list) and the Topic page (one black reading area: picture and text). | Index as the finders; Topic black from (1,19) 398 x 286. | As the finders; a black page |
| Side columns | `windows/finder_side2.alliance.png`, `finder_side4.alliance.png`, `ency_side.alliance.png` | 58 x 330 | 3 | The Alliance's column of side buttons (two or four buttons). | One state. | Grey plate |
| Finder tabs | `tabs/finder_tab_<all / rebel / imperial / neutral / unexplored>[.pressed / .grey].png` | 49 x 41 | 14 | Which side's systems, fleets, troops or personnel to list. | Plain, pressed; grey (empty) except All. | Our grid glyph; a disc in each side's colour |
| Encyclopedia tabs | `tabs/ency_tab_<all / system / defense>[.pressed].png`, `ency_tab_<facilities / missions / ship / troop / personnel>.<side>[.pressed].png` | 49 x 41; personnel 49-50 x 57 | 26 | The databases: All, System, Defense, Facilities, Mission, Ship, Troop, Personnel. | Plain and pressed. | Our glyphs |
| Finder buttons | `buttons/finder_<display / btn_characters / btn_specforces / btn_fleets / btn_ships>.<side>[.pressed].png` | Alliance 32 x 31, Empire 44 x 41 | 20 | Display (open the selection's window), Characters / Special Forces, Fleets / Ships. | Plain and pressed. | Our window, person, helmet, ship and list glyphs |
| Encyclopedia buttons | `buttons/ency_view_topic.<side>`, `ency_view_index.<side>` `[.pressed / .disabled].png` | Alliance 32 x 31, Empire 44 x 41 | 12 | View Topic, View Index. | Plain, pressed, disabled. | Our page and list glyphs |
| Encyclopedia arrows | `buttons/ency_prev[...]`, `buttons/ency_next[...]` | 21 x 17 | 6 | Step to the previous / next topic. | Plain, pressed, disabled. | Our left and right glyphs |
| Encyclopedia pictures | `characters/<id>.png`, `units/<id>.png`, `facilities/<id>.png`, `planets/<id>.png`, `missions/...` (`Art.Picture`) with portraits (`Art.Portrait`) and miniatures (`Art.Miniature`, 61 x 25) | the Topic picture area; miniatures 61 x 25 | one per entry | Every topic's picture: each character, ship, fighter, troop, facility, system and mission. | One state (characters also `.report`, units `.damage` / `.moving`). | None |

## Phase 7: the Game Options screen and the alert boxes

The Game Options screen (manual p075-p076 Fig 3.16): Saved Games (six rows:
Save, the side's mark, the name, Load; the Import Game and Manage Games row),
the tray under it (Restart, Return, Exit), Sound Options and Tactical Display
Options. The alert boxes (REBDLOG) ask and tell with one button or two.

| Asset | File | Size (frame px) | Count | What it is | States / notes | Plain stand-in now |
|---|---|---|---|---|---|---|
| Options screen | `screens/options.png` | 640 x 480 | 1 | The whole screen's face: the Saved Games panel with its six rows of sockets, the tray, Sound Options (the music switch's field, the two volume tracks with their music and effects marks), Tactical Display Options (five lamps and fields). | One state. Sockets measured: Save (33,80) 44 x 22, side mark (84,80) 28 x 21, name (116,81) 165 x 20, Load (286,80) 43 x 22, rows 42 apart; tray sockets (76,381), (162,382), (248,381) 42 x 42. | Grey plate, black sockets, note and speaker glyphs |
| Multiplayer strip | `screens/mp_connection.png` | 640 x 480 | 1 | The multiplayer screens' picture; the Saved Games row's wires and clamps are cut from its foot. | Wires at rows 447-449 yellow, 451-453 red, 455-457 blue, 459-460 green; a clamp at (98,439) 8 x 33. | Grey plate; four coloured wires and a clamp at those rows |
| Options buttons | `buttons/options_<save / load / restart / return / exit>[.pressed / .disabled].png` | save 42 x 20, load 41 x 20; restart, return, exit 42 x 42 | 15 | Save a game, load one, restart, return to the Command Center, exit. | Plain, pressed, disabled (Load on an empty row). | Our disk, download, restart, return and power glyphs |
| Side marks | `windows/options_side.<alliance / empire / h2h>.png` | 26 x 19 | 3 | Which side a saved game was played as; head-to-head. | One state. | Our flag in the side's colour; two figures for head-to-head |
| Music switch | `windows/options_music[.lit / .off].png` | 19 x 35 | 2 | Play Music on or off. | `.lit` on, `.off` off. | A lever up (green light) or down |
| Tactical lamps | `windows/options_light.off.png` | 35 x 22 | 1 | Each Tactical Display option's lamp. | Off (the tactical display is not in this game). | A dark green lamp |
| Volume knob | `windows/options_knob.png` | 11 x 47 | 1 | The slider on each volume track. | One state. | Grey slab |
| Choice box | `windows/mp_choice[.chosen].png` | 152 x 33 | 2 | The box the Import Game and Manage Games buttons are cut from. | Plain; `.chosen` (red ends). | Grey box, black middle |
| Alert boxes | `windows/dialog_plate1.png`, `windows/dialog_plate2.png` | 412 x 176 | 2 | An alert's face: the words' well, and the socket for one button (OK) or two (OK, Cancel). | Words (26,36) 360 x 68; sockets (172,130) or (122,130) and (225,131), 65 x 36. | Grey plate, black well, dark sockets |
| Alert buttons | `buttons/dialog_ok[.pressed].png`, `buttons/dialog_cancel[.pressed].png` | 57 x 28 | 4 | OK / Yes and Cancel / No. | Plain and pressed. | Our tick and cross glyphs |
