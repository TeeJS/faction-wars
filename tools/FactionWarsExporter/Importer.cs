using System.Drawing;
using System.Drawing.Imaging;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace FactionWarsExporter;

/// <summary>
/// The mapping from the pack's rows to the original's Encyclopedia, verified
/// against the installed game on 2026-09-22 (TeeJ's GOG copy):
///
///   Encyclopedia id     = the row's string_id - 4096   (characters, units,
///                         facilities, missions)
///   ENCYTEXT.DLL        RCDATA[encyclopedia id]  = the description
///   ENCYBMAP.DLL        STRING[encyclopedia id]  = "EDATA.nnn", the picture
///   EData\EDATA.nnn     a 400x200 8-bit Windows BMP
///   Planets             STRING[11100 + artwork_id - 1] - 26 pictures, no text
///   Missions            STRING[string_id - 4096] is the Alliance picture,
///                       STRING[string_id] the Empire one
///   GOKRES.DLL          RT_BITMAP portraits (80x80) and list miniatures
///                       (61x25) of every character, unit and facility, by
///                       the ids in gokres_map.json (from open-rebellion's
///                       Ghidra-derived entity catalog; the 60 character
///                       portraits were checked by face). Blue = transparent.
///   STRATEGY.DLL        RT_BITMAP sprites, blue (0,0,255) = transparent:
///     10146-10157 the GID stars, 15x15: four sizes (drawn 15/9/7/3 px) in
///     red (Alliance), green (Empire) and blue (neutral); 10181/10180/10170/
///     10169 the same in grey (unexplored); 11608/11609 the uprising flame.
///     10771-10778 the Alliance sector-window icons (factory, tower, ship,
///     crest; each normal then highlighted), 10779-10786 the Imperial set,
///     10787-10790 the neutral factory and tower; 10212-10237 the 26 planet
///     sprites by artwork_id (10240 is the asteroid field).
///     The window plates and parts (Manufacturing 10290-10298, Defenses
///     10577, the Encyclopedia / Message Index frame 10335/10336 and plates
///     10337/10338/10822), the tab icons of the Manufacturing, Defenses and
///     Message Index windows, and the title-bar, Encyclopedia and scrollbar
///     buttons - see the tables below for every id.
///
/// Output: an ART SET (docs/original-art-plan.md) - these paths, relative to
/// its root, written through an ArtSink (a .zip, a folder, or hashes only).
/// (Each path below is shown under original/, the art set's old home.)
///   original/characters/&lt;id&gt;.png   original/units/&lt;id&gt;.png
///   original/facilities/&lt;id&gt;.png   original/planets/&lt;id&gt;.png
///   original/missions/&lt;id&gt;.&lt;faction&gt;.png (alliance / empire), and
///     .small.png: the 130x65 Create Mission picture (GOKRES.DLL)
///   original/descriptions.json     { "characters": { id: text }, ... }
///   original/portraits/&lt;kind&gt;/&lt;id&gt;.png   original/miniatures/&lt;kind&gt;/&lt;id&gt;.png
///   original/icons/&lt;glyph&gt;.&lt;faction&gt;.png (+ .hover.png)   sector-window corners
///   original/icons/uprising.png (+ .hover.png)             the flame, two frames
///   original/gid/&lt;faction&gt;.&lt;tier&gt;.png, gid/unexplored.&lt;tier&gt;.png   the GID stars
///   original/alerts/&lt;faction&gt;.&lt;category&gt;.png (+ .lit.png)   the Message Alert bar
///   original/planet_sprites/&lt;artwork_id&gt;.png              the map's planets
///   original/windows/&lt;name&gt;.png                            window pictures
///   original/tabs/&lt;name&gt;[.&lt;faction&gt;].png (+ .pressed / .grey)   window tab icons
///   original/buttons/&lt;name&gt;.png (+ .pressed / .disabled)       window buttons
///   original/cursors/pointer.png, crosshair.png, hotspots.json   the mouse pointers (REBEXE.EXE)
///   original/screens/cockpit.png   the Shuttle Cockpit (COMMON.DLL 20001), the menu picture
///   original/screens/galaxy.png    the galaxy map (STRATEGY.DLL 903), the map's backdrop
///   original/manifest.json         every file's SHA-256 (ArtSink)
/// </summary>
public sealed class Importer
{
    public const int TextOffset = 4096;
    public const int PlanetPictureBase = 11100;
    public const int PlanetSpriteBase = 10212;
    public const int PlanetSpriteCount = 26;

    // STRATEGY.DLL: the GID stars, big / mid / low / none per side (measured
    // extents 15, 9, 7 and 3 px), and the grey set for unexplored worlds.
    private static readonly (string Faction, int Big, int Mid, int Low, int None)[] GidStars =
    {
        ("alliance", 10146, 10147, 10148, 10149),
        ("empire", 10153, 10152, 10151, 10150),
        ("neutral", 10157, 10156, 10155, 10154),
        ("unexplored", 10181, 10180, 10170, 10169),
    };
    private const int UprisingFrame1 = 11608, UprisingFrame2 = 11609;

    // Full-screen pictures (docs/original-art-plan.md, phase 0): the Shuttle
    // Cockpit, the Star Wars pack's menu picture (manual p021 Fig 2.2), in
    // COMMON.DLL; the galaxy map, the map's backdrop, in STRATEGY.DLL. The
    // pack's old galaxyShaded.bmp was an edited copy of 903.
    public const int CockpitBitmap = 20001, GalaxyBitmap = 903;
    // The galaxy map is 607x437; the Star Wars pack's map frame is 640x480, the
    // size of its old galaxyShaded.bmp (an edited copy of 903 at its top-left).
    // The strips right of and below the picture are its own edge, mirrored, so the
    // pack's map_image_rect places the map exactly as before.
    public const int GalaxyWidth = 640, GalaxyHeight = 480;

    // STRATEGY.DLL: the Message Alert bar's nine icons (27x22), in the order
    // the manual's Message Alerts menu lists them (p081 Fig 3.21) except that
    // the bitmaps put Advice before Chat; dim and lit sets per side. Matched
    // pixel-for-pixel against TeeJ's screenshots of the original (2026-09-22).
    private static readonly string[] AlertCategories = { "loyalty", "fleets", "missions", "resources", "manufacturing", "defense", "conflict", "advice", "chat" };
    private static readonly (string Faction, int Dim, int Lit)[] AlertSets = { ("alliance", 10050, 10060), ("empire", 10030, 10040) };

    // STRATEGY.DLL: (glyph, faction id, normal bitmap, highlighted bitmap).
    private static readonly (string Glyph, string Faction, int Normal, int Hover)[] CornerIcons =
    {
        ("manufacturing", "alliance", 10771, 10772), ("defenses", "alliance", 10773, 10774),
        ("fleet", "alliance", 10775, 10776), ("mission", "alliance", 10777, 10778),
        ("manufacturing", "empire", 10779, 10780), ("defenses", "empire", 10781, 10782),
        ("fleet", "empire", 10783, 10784), ("mission", "empire", 10785, 10786),
        ("manufacturing", "neutral", 10787, 10788), ("defenses", "neutral", 10789, 10790),
    };

    // STRATEGY.DLL: the plates and parts the original composes its windows
    // from. Every id was placed by masked template matching on TeeJ's own
    // screenshots of the original (2026-09-23): the Manufacturing window
    // (Chandrila, Duros, Mon Calamari), the System Defenses window (Chandrila,
    // Coruscant, Yaga Minor, Drall, Ajan Kloss), the Galactic Encyclopedia
    // (both sides) and the Message Index (both sides).
    private static readonly (string Name, int Id)[] WindowPictures =
    {
        // Manufacturing and Production (p083 Fig 3.24): the 226x304 plate, the
        // 46x226 left column (three 46x46 pictures, three 46x16 ratio boxes),
        // the 166x79 row frame (header, body, progress-bar track).
        ("mfg_background", 10297), ("mfg_column", 10298), ("mfg_row", 10290),
        // The row headers (162x13): normal, and lit (a list's selected row).
        ("header.alliance", 10292), ("header.empire", 10294), ("header.neutral", 10296),
        ("header.alliance.lit", 10291), ("header.empire.lit", 10293), ("header.neutral.lit", 10295),
        // System Defenses (p126 Fig 3.73): the 235x304 plate.
        ("defense_background", 10577),
        // The Encyclopedia / Message Index frame (470x331) per side, and the
        // 400x306 plates laid inside it at (12, 13): Topic view, Index view,
        // Message Index.
        ("frame.alliance", 10335), ("frame.empire", 10336),
        ("ency_topic_plate", 10337), ("ency_index_plate", 10338), ("msgindex_plate", 10822),
        // A card's 61x25 plates (manual p084: "the image for these units shows
        // whether the unit is completed, being built, or en route"): the grey
        // plate behind a completed one, hyperspace streaks behind one en route,
        // and the side's grid over one being built.
        ("card_plate", 11500), ("card_enroute", 11505),
        ("card_building.alliance", 11570), ("card_building.empire", 11572),
        // Create Mission (p042 Fig 2.34, p103 Fig 3.47, p104 Fig 3.48): the
        // 259x355 plate of the Select Mission tab (the mission box, the Target
        // brackets) and of the Decoy tab (the agent and decoy columns), the
        // 200x113 starfield the mission list drops down on, and the columns'
        // 108x27 heads per side (agents, decoys).
        ("mission_plate", 11100), ("mission_decoy_plate", 11101), ("mission_list", 11102),
        // The starfield a drop-down picture list is drawn on (195x61, tiled
        // down; the Build Selection window's item list).
        ("list_starfield", 10598),
        ("mission_agents.alliance", 11121), ("mission_decoys.alliance", 11122),
        ("mission_agents.empire", 11123), ("mission_decoys.empire", 11124),
        // The Mission window (p109 Fig 3.51): the 235x304 plate that is the
        // window (the starfield, the Target box, the team panel), and the
        // side's frame round the mission picked in its column (73x48, keyed
        // inside). Placed by template matching on TeeJ's four screenshots of
        // the original's (Mon Calamari, Umgul twice, Coruscant; 2026-09-23).
        ("mission_window", 11165), ("mission_frame.alliance", 11127), ("mission_frame.empire", 11128),
        // A Status window (manual p064: modal, no title bar, closed by its
        // diamond): the 379x272 plate per side - the field panel with the
        // side's emblem, the picture and name grids, the button sockets - and
        // the grey spotlight behind a trooper regiment's picture (122x50).
        ("status_plate.alliance", 11554), ("status_plate.empire", 11558),
        ("status_backdrop.troops", 11514),
        // A fleet's Status picture per side (122x50; the Empire's inferred),
        // and the flames drawn UNDER it when a ship of it is damaged
        // (measured on TeeJ's Alliance Fleet Status).
        ("status_fleet.alliance", 10425), ("status_fleet.empire", 10426), ("status_fleet_damage", 10427),
        // The Message Index (p078 Fig 3.18): the Alliance's socket column over
        // the frame's right strip, and the plate under a read message (p080
        // Fig 3.19, the band across its top - not yet on a screenshot).
        ("msgindex_side.alliance", 10820), ("msgsummary_plate", 10823),
        // The Alliance's three-socket column down the Encyclopedia's right
        // edge (58x330), drawn whole (its one blue pixel shows).
        ("ency_side.alliance", 10585),
        // Build Selection (p045, p112 Fig 3.58): the 210x261 plate - the frame,
        // the picture box, the two cost boxes with their icons, the times box
        // and the number box (TeeJ's screenshot of the original, Empire).
        ("build_plate", 10800),
        // The confirmation dialog (TeeJ's screenshots of the original's Scrap,
        // both sides, rebuilt pixel for pixel): the 424x331 frame per side (no
        // title bar), drawn whole - its last row is pure blue and shows - and
        // Scrap's 400x200 console picture per side, drawn whole.
        ("confirm_frame.empire", 11126), ("confirm_frame.alliance", 11125),
        ("scrap_picture.empire", 1033), ("scrap_picture.alliance", 1032),
    };

    // STRATEGY.DLL: buttons drawn WHOLE with both magenta shades keyed, as
    // Build Selection draws them (its screenshot shows each 66x33 button's
    // drop shadow, which Create Mission clips off): (name, normal, pressed,
    // disabled). The spinner's arrows key blue.
    private static readonly (string Name, int Normal, int Pressed, int Disabled)[] ShadedButtons =
    {
        ("build_encyclopedia", 10592, 10593, 0), ("build_ok", 10594, 10595, 11620), ("build_cancel", 10596, 10597, 0),
        ("build_list_open", 10606, 10607, 0), ("build_up", 10610, 10611, 0), ("build_down", 10612, 10613, 0),
    };

    // STRATEGY.DLL: Message Index parts keyed by BLACK as well as blue, as the
    // original draws them (matched on TeeJ's screenshots of both sides' Advice
    // tab): the selected row's bar per side (356x21) and the rows' 15x15 /
    // 15x16 category icons, chosen by the message's category. Seen on TeeJ's
    // screenshots: Advice per side, the Alliance's Mission (10910) and
    // Manufacturing (10908), Defense (10963). The rest are the same set's
    // pictures matched by what they show - the side's crest as the Loyalty
    // tab has it, the two emblems for Chat, the Empire's twins.
    private static readonly (string Name, int Id)[] BlackKeyed =
    {
        ("msgindex_selection.empire", 10915), ("msgindex_selection.alliance", 10914),
        ("msgicon.advice.empire", 10969), ("msgicon.advice.alliance", 10968),
        ("msgicon.loyalty.alliance", 10906), ("msgicon.loyalty.empire", 10907),
        ("msgicon.fleets.empire", 10965), ("msgicon.fleets.alliance", 10964),
        ("msgicon.missions.alliance", 10910), ("msgicon.missions.empire", 10913),
        ("msgicon.manufacturing.alliance", 10908), ("msgicon.manufacturing.empire", 10909),
        ("msgicon.resources", 10966), ("msgicon.chat", 10916),
        ("msgicon.conflict", 10967), ("msgicon.defense", 10963),
    };

    // GOKRES.DLL: the picture of a manufacturing queue in its Status window
    // (Fig 3.29), keyed by its own bottom-left colour as the original draws it:
    // 263 Facilities Under Construction (matched on TeeJ's screenshot), 262
    // and 264 the ship and troop queues (their neighbours, not yet seen).
    private static readonly (string Name, int Id)[] QueuePictures =
    {
        ("queue.facilities", 263), ("queue.ships", 262), ("queue.troops", 264),
    };

    // STRATEGY.DLL: window tab icons as (name, faction or "", normal, current,
    // greyed). Which of each triplet is which was read off the screenshots:
    // the Manufacturing set draws its CURRENT tab from the first bitmap, the
    // Defenses set from the second.
    private static readonly (string Name, string Faction, int Normal, int Current, int Grey)[] TabIcons =
    {
        // The Encyclopedia's seven database tabs (p073 Fig 3.10), 49x41 drawn
        // (the Personnel pictures are 57 tall; the original draws the top 41),
        // normal and current. Measured on TeeJ's Alliance screenshots (All
        // Databases, Personnel); the Empire's are its twins, not yet seen.
        ("ency_tab_all", "", 10340, 10339, 0), ("ency_tab_system", "", 10350, 10349, 0),
        ("ency_tab_ship", "alliance", 10348, 10347, 0), ("ency_tab_ship", "empire", 10360, 10359, 0),
        ("ency_tab_facilities", "alliance", 10344, 10343, 0), ("ency_tab_facilities", "empire", 10356, 10355, 0),
        ("ency_tab_missions", "alliance", 11616, 11615, 0), ("ency_tab_missions", "empire", 11618, 11617, 0),
        ("ency_tab_troop", "alliance", 10352, 10351, 0), ("ency_tab_troop", "empire", 10362, 10361, 0),
        ("ency_tab_personnel", "alliance", 10346, 10345, 0), ("ency_tab_personnel", "empire", 10358, 10357, 0),
        // Manufacturing (p084 Fig 3.27), 36x33, in the window's order.
        ("manufacturing", "alliance", 10312, 10311, 10313), ("manufacturing", "empire", 10315, 10314, 10316),
        ("manufacturing", "neutral", 10318, 10317, 10319),
        ("shipyards", "", 10327, 10326, 10328), ("training_facilities", "", 10330, 10329, 10331),
        ("construction_yards", "", 10333, 10332, 10334), ("refineries", "", 10324, 10323, 10325),
        ("mines", "", 10321, 10320, 10322),
        // System Defenses (p126 Fig 3.73), 36x33.
        ("personnel", "alliance", 10570, 10571, 10572), ("personnel", "empire", 10573, 10574, 10575),
        ("troops", "alliance", 10563, 10564, 10565), ("troops", "empire", 10566, 10567, 10568),
        ("fighters", "alliance", 10556, 10557, 10558), ("fighters", "empire", 10559, 10560, 10561),
        ("planetary_shield", "", 10553, 10554, 10555), ("planetary_battery", "", 10550, 10551, 10552),
        // The Message Index's strip (p079 Fig 3.19), 36x41 sockets; no greyed state.
        ("msg_all", "", 10830, 10831, 0),
        ("msg_loyalty", "alliance", 10832, 10833, 0), ("msg_loyalty", "empire", 10834, 10835, 0),
        ("msg_fleets", "empire", 10838, 10839, 0), ("msg_fleets", "alliance", 10840, 10841, 0),
        ("msg_missions", "alliance", 10842, 10843, 0), ("msg_missions", "empire", 10844, 10845, 0),
        ("msg_resources", "", 10836, 10837, 0), ("msg_manufacturing", "", 10852, 10853, 0),
        ("msg_defense", "", 10856, 10857, 0), ("msg_conflict", "", 10854, 10855, 0),
        ("msg_chat", "", 10850, 10851, 0),
        ("msg_advice", "alliance", 10846, 10847, 0), ("msg_advice", "empire", 10848, 10849, 0),
        // Create Mission's two tabs, 116x33: Select Mission and Decoy.
        ("mission_select", "alliance", 11103, 11104, 0), ("mission_select", "empire", 11105, 11106, 0),
        ("mission_decoy", "alliance", 11107, 11108, 0), ("mission_decoy", "empire", 11109, 11110, 0),
        // The Mission window's two tabs (p109 Fig 3.51), 61x16: the agents
        // and the decoys. Normal and current measured on TeeJ's Empire
        // screenshots; the Alliance's are their twins (a figure and the red
        // emblem), not yet seen.
        ("mission_agents_tab", "alliance", 11560, 11561, 0), ("mission_decoys_tab", "alliance", 11562, 11563, 11564),
        ("mission_agents_tab", "empire", 11565, 11566, 0), ("mission_decoys_tab", "empire", 11567, 11568, 11569),
    };

    // STRATEGY.DLL: buttons as (name, normal, pressed/current, disabled).
    private static readonly (string Name, int Normal, int Pressed, int Disabled)[] Buttons =
    {
        // The Encyclopedia's browse arrows (21x17).
        ("ency_prev", 10385, 10386, 10387), ("ency_next", 10382, 10383, 10384),
        // The frame's side column: the Empire's 44x41, the Alliance's 32x31.
        ("ency_close.empire", 10376, 10377, 0), ("ency_view_topic.empire", 10380, 10381, 10391),
        ("ency_view_index.empire", 10378, 10379, 10390),
        ("ency_close.alliance", 10370, 10371, 0), ("ency_view_topic.alliance", 10374, 10375, 10389),
        ("ency_view_index.alliance", 10372, 10373, 10388),
        // The original's scrollbar (13 wide): arrows and the thumb's three parts.
        ("scroll_up", 10658, 0, 0), ("scroll_down", 10662, 0, 0),
        ("scroll_thumb_top", 10666, 0, 0), ("scroll_thumb_mid", 10668, 0, 0), ("scroll_thumb_bottom", 10669, 0, 0),
        // Create Mission's Decoy tab: move the selected to the decoys / agents (16x16).
        ("mission_to_decoys", 11117, 11118, 0), ("mission_to_agents", 11119, 11120, 0),
        // A Status window's Encyclopedia button (32x31); its close is ency_close.alliance.
        ("status_encyclopedia", 11552, 11553, 11612),
        // The Message Index (Fig 3.18): the band's Select All and Delete
        // (56x20, opaque), and the side column under Close, per side - Message
        // Summary, Post Messages with Alert (normal) / Silently (pressed), Open
        // Window, Compose Chat (Empire 44x41, Alliance 32x31).
        ("msgindex_select_all", 10900, 10901, 0), ("msgindex_delete", 10902, 10903, 0),
        ("msgindex_summary.empire", 10738, 10739, 10962), ("msgindex_summary.alliance", 10870, 10871, 10961),
        ("msgindex_post.empire", 10874, 10875, 0), ("msgindex_post.alliance", 10872, 10873, 0),
        ("msgindex_open.empire", 10520, 10521, 10960), ("msgindex_open.alliance", 10518, 10519, 10959),
        ("msgindex_compose.empire", 10879, 10880, 10881), ("msgindex_compose.alliance", 10876, 10877, 10878),
        // A read message's band: scroll up / down through the tab (19x15), and
        // the tick and cross of a report that asks (51x35, Fig 2.38).
        ("msgsummary_up", 10948, 10949, 10950), ("msgsummary_down", 10919, 10920, 10921),
        ("decision_ok", 10926, 10927, 10928), ("decision_cancel", 10929, 10930, 10931),
    };

    // STRATEGY.DLL: the 14x14 boxes, keyed by their own bottom-left pixel (a
    // green one): the original shows what is under the box there - the title
    // bar's colour, the Sector window's see-through grey (measured).
    private static readonly (string Name, int Normal, int Pressed, int Disabled)[] CornerKeyedButtons =
    {
        // A window's title bar: the system box, minimise, close.
        ("title_system", 10209, 0, 0), ("title_minimize", 10253, 0, 0), ("title_close", 10108, 0, 0),
        // The Sector window's "switch window to other side of screen" box (p025 Fig 2.8).
        ("sector_switch", 10210, 10211, 0),
    };

    // STRATEGY.DLL: buttons drawn CLIPPED to their control, as (name, normal,
    // pressed, clip x, y, w, h). Read off TeeJ's screenshot of the original's
    // Create Mission window (2026-09-23): both pictures are drawn at the same
    // spot, and the normal one's last columns and row - the room the face moves
    // into when pressed - never show; nor does the pressed one's first. Both
    // magenta shades, (255,0,255) and (204,28,205), are keyed.
    private static readonly (string Name, int Normal, int Pressed, int X, int Y, int W, int H)[] ClippedButtons =
    {
        // The Encyclopedia, assign and cancel buttons (66x33 drawn as 64x32).
        ("mission_encyclopedia", 10592, 10593, 0, 0, 64, 32), ("mission_ok", 10594, 10595, 0, 0, 64, 32),
        ("mission_cancel", 10596, 10597, 0, 0, 64, 32),
        // The arrow that drops the mission list down (65x18 drawn as 65x17).
        ("mission_list_open", 10606, 10607, 0, 1, 65, 17),
        // ...and drawn whole, its top row too, while the list is down (measured).
        ("mission_list_opened", 10606, 10607, 0, 0, 65, 18),
    };

    // COMMON.DLL: the Shuttle Cockpit's monitors (manual p021 Fig. 2.2 - "the
    // rotating red Alliance icon"), each a run of frames saved as ONE strip,
    // the frames side by side: (name, first bitmap, frames). Where each goes
    // (pack.json menu.monitors) was found by fitting every frame's outline to
    // the cockpit's dark screens: each lands, to the pixel, on the monitor
    // Fig. 2.2 labels - the three difficulties (an X-wing, a Star Destroyer,
    // the Death Star), the two sides' emblems, load (a disc), credits,
    // head-to-head, exit (the lever), and the victory-condition screen (a
    // picture per condition, no animation).
    private static readonly (string Name, int First, int Frames)[] CockpitMonitors =
    {
        ("easy", 11061, 30), ("medium", 11091, 30), ("hard", 11121, 30),
        ("empire", 11001, 15), ("alliance", 11031, 15),
        ("load", 11241, 30), ("credits", 11271, 2), ("multiplayer", 11151, 30), ("exit", 11181, 30),
        ("standard_game", 10158, 1), ("hq_only", 10159, 1),
    };

    // GOKRES.DLL: the 130x65 picture of each mission in the Create Mission
    // window, per side, at the row's string_id less these (Recruitment's
    // 11286 - 4096 = 7190 matched TeeJ's Imperial screenshot pixel for pixel;
    // all 21 were checked by eye, the Alliance set 4096 below the Empire's).
    private const int MissionCardEmpire = 4096;
    private const int MissionCardAlliance = 8192;
    // ...and its 73x48 picture in the Mission window's column (p109 Fig
    // 3.51), at the string_id plus these: the Empire's matched TeeJ's four
    // screenshots of the original (Diplomacy, Sabotage, Recruitment; the
    // label and the frame aside, every pixel); the Alliance set is 4096 below,
    // as it is for the Create Mission pictures - not yet seen.
    private const int MissionTileEmpire = 12288;
    private const int MissionTileAlliance = 8192;

    // Bitmaps the original draws WHOLE, pure blue included: the Create Mission
    // plates' blue line under the tabs and the tabs' blue edges are on TeeJ's
    // screenshot of the original, pixel for pixel (2026-09-23).
    private static readonly HashSet<int> DrawnWhole = new() { 10585, 10598, 11125, 11126, 11100, 11101, 11103, 11104, 11105, 11106, 11107, 11108, 11109, 11110,
        // The Status plates are opaque; the pressed Encyclopedia button keeps its blue face.
        11554, 11558, 11553,
        // Build Selection's plate is opaque; so are the Scrap pictures.
        10800, 1032, 1033,
        // The cockpit, the galaxy map and the Game Options screen are whole screens.
        CockpitBitmap, GalaxyBitmap, OptionsBitmap };

    // COMMON.DLL: the Game Options screen (manual p075-p076, Fig. 3.16), placed
    // by template matching on TeeJ's screenshot of the original's (2026-09-23).
    // The 640x480 screen itself, and its parts as (name, normal, pressed,
    // disabled): each slot's Save Game and Load Game buttons, Restart, Return
    // to the Command Center, and Exit.
    public const int OptionsBitmap = 20002;
    private static readonly (string Name, int Normal, int Pressed, int Disabled)[] OptionsButtons =
    {
        ("options_save", 10046, 10047, 10048), ("options_load", 10049, 10050, 10051),
        ("options_restart", 10035, 10036, 10037), ("options_return", 10023, 10024, 10025),
        ("options_exit", 10038, 10039, 0),
    };
    // ...and its pictures: the side a slot was saved as (the Empire, the
    // Alliance, head-to-head), the Play Music switch (off, lit, greyed), a
    // tactical toggle's light (lit, on, off) and a volume slider's knob.
    private static readonly (string Name, int Id)[] OptionsParts =
    {
        ("options_side.empire", 10055), ("options_side.alliance", 10056), ("options_side.h2h", 10057),
        ("options_music.off", 10040), ("options_music.lit", 10041), ("options_music.grey", 10042),
        ("options_light.lit", 10043), ("options_light.on", 10044), ("options_light.off", 10045),
        ("options_knob", 10054),
    };

    // The Command Center's Speed Control (manual p071 Fig. 3.8), cut from each
    // side's frame - STRATEGY 900 the Alliance's, 901 the Empire's (TeeJ's
    // screenshot of the Empire's matched 901 at (474, 6), every pixel but the
    // day and the bars): (name, frame, x, y, w, h), the see-through blue kept
    // out. Its bars per side, one picture per speed: Pause, Very Slow, Slow,
    // Medium, Fast (none lit, none, one, two, three; TeeJ's at Slow, one lit).
    private static readonly (string Name, int Frame, int X, int Y, int W, int H)[] FrameCuts =
    {
        ("hud_speed.alliance", 900, 90, 11, 106, 23), ("hud_speed.empire", 901, 488, 13, 102, 24),
    };
    private static readonly (string Side, int[] Ids)[] SpeedBars =
    {
        ("alliance", new[] { 11580, 11581, 11582, 11583, 11588 }), ("empire", new[] { 11584, 11585, 11586, 11587, 11589 }),
    };
    // REBDLOG.DLL: the original's alert box (TeeJ's screenshot of "Resume Game
    // Play?"): the 412x176 plate with no, one and two button sockets, and its
    // check and cross buttons (normal, pressed).
    private static readonly (string Name, int Id)[] DialogPlates =
    {
        ("dialog_plate0", 10621), ("dialog_plate1", 10622), ("dialog_plate2", 10623),
    };
    private static readonly (string Name, int Normal, int Pressed)[] DialogButtons =
    {
        ("dialog_ok", 10625, 10624), ("dialog_cancel", 10627, 10626),
    };

    public sealed record Result(int Pictures, int Descriptions, List<string> Missing, List<string> Log);

    private readonly string _gameDir;
    private readonly string _rowsDir;
    private readonly ArtSink _sink;
    private readonly Action<string> _report;

    /// <summary>The five pack files the rows are read from.</summary>
    public static readonly string[] RowFiles = { "characters.json", "units.json", "facilities.json", "missions.json", "map.json" };

    /// <param name="rowsDir">where the Star Wars pack's RowFiles are: BundledRows
    /// (built into the exe), or a pack folder.</param>
    public Importer(string gameDir, string rowsDir, ArtSink sink, Action<string> report)
    {
        _gameDir = gameDir;
        _rowsDir = rowsDir;
        _sink = sink;
        _report = report;
    }

    /// <summary>The Star Wars pack's rows built into the exe (see the csproj):
    /// the exporter is one file, with nothing beside it to lose.</summary>
    public const string BundledRows = "(built in)";

    /// <summary>A file built into the exe (an EmbeddedResource's LogicalName), or null.</summary>
    public static string? BuiltIn(string name)
    {
        using var stream = typeof(Importer).Assembly.GetManifestResourceStream(name);
        if (stream == null)
            return null;
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    }

    /// <summary>One of the RowFiles, from the exe or from a pack folder.</summary>
    private static string? RowText(string rowsDir, string file) =>
        rowsDir == BundledRows ? BuiltIn("pack/" + file)
        : File.Exists(Path.Combine(rowsDir, file)) ? File.ReadAllText(Path.Combine(rowsDir, file)) : null;

    public static string? Problem(string gameDir, string rowsDir)
    {
        foreach (var f in new[] { "ENCYTEXT.DLL", "ENCYBMAP.DLL", "TEXTSTRA.DLL", "STRATEGY.DLL", "GOKRES.DLL" })
            if (!File.Exists(Path.Combine(gameDir, f)))
                return $"{f} is not in {gameDir} - pick the folder the game is installed in, or the REBELLION folder on the CD.";
        if (!Directory.Exists(Path.Combine(gameDir, "EData")))
            return $"There is no EData folder in {gameDir}. An install from the CD leaves the pictures on the disc - " +
                   @"pick the REBELLION folder on the CD instead (for example D:\REBELLION).";
        foreach (var f in RowFiles)
            if (RowText(rowsDir, f) == null)
                return $"{f} is missing from {rowsDir} - the exporter is incomplete; download it again.";
        return null;
    }

    public Result Run()
    {
        var log = new List<string>();
        var missing = new List<string>();
        void Say(string s) { log.Add(s); _report(s); }

        var text = new PeResources(Path.Combine(_gameDir, "ENCYTEXT.DLL"));
        var pictures = new PeResources(Path.Combine(_gameDir, "ENCYBMAP.DLL"));
        Say($"ENCYTEXT.DLL: {text.RcData.Count} descriptions. ENCYBMAP.DLL: {pictures.Strings.Count} picture entries.");

        var descriptions = new JsonObject();
        int pictureCount = 0, textCount = 0;

        foreach (var (file, kind) in new[] { ("characters.json", "characters"), ("units.json", "units"), ("facilities.json", "facilities"), ("missions.json", "missions") })
        {
            var rows = ReadRows(file, kind);
            var texts = new JsonObject();
            int got = 0;
            foreach (var row in rows)
            {
                string id = row["id"]!.GetValue<string>();
                int? stringId = row["string_id"]?.GetValue<int>();
                if (stringId is null)
                {
                    missing.Add($"{kind}/{id}: no string_id in the pack (nothing to look up)");
                    continue;
                }
                int ency = stringId.Value - TextOffset;
                if (text.RcData.ContainsKey(ency))
                {
                    texts[id] = text.RcDataText(ency);
                    textCount++;
                }
                else
                    missing.Add($"{kind}/{id}: no description at Encyclopedia id {ency}");

                // A mission's picture comes per side: the Alliance one at the
                // Encyclopedia id, the Imperial one at the string id itself.
                var outName = kind == "missions" ? id + ".alliance.png" : id + ".png";
                if (SavePicture(pictures, ency, P(kind, outName)))
                {
                    pictureCount++;
                    got++;
                }
                else
                    missing.Add($"{kind}/{id}: no picture at Encyclopedia id {ency}");
                if (kind == "missions" && SavePicture(pictures, stringId.Value, P(kind, id + ".empire.png")))
                    pictureCount++;
            }
            descriptions[kind] = texts;
            Say($"{kind}: {got} of {rows.Count} pictures, {texts.Count} descriptions.");
        }

        // Planets: 26 portraits shared by artwork_id; no Encyclopedia text.
        var map = JsonNode.Parse(RowText(_rowsDir, "map.json")!)!.AsObject();
        int planets = 0, planetRows = 0;
        foreach (var p in map["planets"]!.AsArray())
        {
            planetRows++;
            string id = p!["id"]!.GetValue<string>();
            int? art = p["artwork_id"]?.GetValue<int>();
            if (art is null || art < 1)
            {
                missing.Add($"planets/{id}: no artwork_id");
                continue;
            }
            if (SavePicture(pictures, PlanetPictureBase + art.Value - 1, P("planets", id + ".png")))
            {
                pictureCount++;
                planets++;
            }
            else
                missing.Add($"planets/{id}: no picture for artwork_id {art}");
        }
        Say($"planets: {planets} of {planetRows} pictures.");

        // The strategic layer's sprites: the sector window's corner icons in each
        // side's own shaded colours, and the planets themselves.
        var strategy = new PeResources(Path.Combine(_gameDir, "STRATEGY.DLL"));
        int icons = 0;
        foreach (var (glyph, faction, normal, hover) in CornerIcons)
        {
            if (SaveSprite(strategy, normal, P("icons", $"{glyph}.{faction}.png"))) { icons++; pictureCount++; }
            else missing.Add($"icons/{glyph}.{faction}: no bitmap {normal} in STRATEGY.DLL");
            if (SaveSprite(strategy, hover, P("icons", $"{glyph}.{faction}.hover.png"))) { icons++; pictureCount++; }
        }
        int sprites = 0;
        for (int art = 1; art <= PlanetSpriteCount; art++)
        {
            if (SaveSprite(strategy, PlanetSpriteBase + art - 1, P("planet_sprites", $"{art}.png"))) { sprites++; pictureCount++; }
            else missing.Add($"planet_sprites/{art}: no bitmap {PlanetSpriteBase + art - 1} in STRATEGY.DLL");
        }
        int stars = 0;
        foreach (var (faction, big, mid, low, none) in GidStars)
        {
            foreach (var (tier, id) in new[] { ("big", big), ("mid", mid), ("low", low), ("none", none) })
            {
                if (SaveSprite(strategy, id, P("gid", $"{faction}.{tier}.png"))) { stars++; pictureCount++; }
                else missing.Add($"gid/{faction}.{tier}: no bitmap {id} in STRATEGY.DLL");
            }
        }
        if (SaveSprite(strategy, UprisingFrame1, P("icons", "uprising.png"))) pictureCount++;
        else missing.Add($"icons/uprising: no bitmap {UprisingFrame1} in STRATEGY.DLL");
        if (SaveSprite(strategy, UprisingFrame2, P("icons", "uprising.hover.png"))) pictureCount++;
        int alerts = 0;
        foreach (var (faction, dim, lit) in AlertSets)
            for (int k = 0; k < AlertCategories.Length; k++)
            {
                if (SaveSprite(strategy, dim + k, P("alerts", $"{faction}.{AlertCategories[k]}.png"))) { alerts++; pictureCount++; }
                else missing.Add($"alerts/{faction}.{AlertCategories[k]}: no bitmap {dim + k} in STRATEGY.DLL");
                if (SaveSprite(strategy, lit + k, P("alerts", $"{faction}.{AlertCategories[k]}.lit.png"))) { alerts++; pictureCount++; }
            }
        int windows = 0;
        foreach (var (name, id) in WindowPictures)
        {
            if (SaveSprite(strategy, id, P("windows", $"{name}.png"))) { windows++; pictureCount++; }
            else missing.Add($"windows/{name}: no bitmap {id} in STRATEGY.DLL");
        }
        int tabs = 0;
        foreach (var (name, faction, normal, current, grey) in TabIcons)
        {
            var stem = faction.Length == 0 ? name : $"{name}.{faction}";
            if (SaveSprite(strategy, normal, P("tabs", $"{stem}.png"), true)) { tabs++; pictureCount++; }
            else missing.Add($"tabs/{stem}: no bitmap {normal} in STRATEGY.DLL");
            if (SaveSprite(strategy, current, P("tabs", $"{stem}.pressed.png"), true)) pictureCount++;
            if (grey > 0 && SaveSprite(strategy, grey, P("tabs", $"{stem}.grey.png"), true)) pictureCount++;
        }
        int buttons = 0;
        foreach (var (name, normal, pressed, disabled) in Buttons)
        {
            if (SaveSprite(strategy, normal, P("buttons", $"{name}.png"), true)) { buttons++; pictureCount++; }
            else missing.Add($"buttons/{name}: no bitmap {normal} in STRATEGY.DLL");
            if (pressed > 0 && SaveSprite(strategy, pressed, P("buttons", $"{name}.pressed.png"), true)) pictureCount++;
            if (disabled > 0 && SaveSprite(strategy, disabled, P("buttons", $"{name}.disabled.png"), true)) pictureCount++;
        }
        foreach (var (name, normal, pressed, disabled) in CornerKeyedButtons)
        {
            if (SaveSprite(strategy, normal, P("buttons", $"{name}.png"), keyCorner: true)) { buttons++; pictureCount++; }
            else missing.Add($"buttons/{name}: no bitmap {normal} in STRATEGY.DLL");
            if (pressed > 0 && SaveSprite(strategy, pressed, P("buttons", $"{name}.pressed.png"), keyCorner: true)) pictureCount++;
            if (disabled > 0 && SaveSprite(strategy, disabled, P("buttons", $"{name}.disabled.png"), keyCorner: true)) pictureCount++;
        }
        foreach (var (name, normal, pressed, disabled) in ShadedButtons)
        {
            if (SaveSprite(strategy, normal, P("buttons", $"{name}.png"), true, keyShade: true)) { buttons++; pictureCount++; }
            else missing.Add($"buttons/{name}: no bitmap {normal} in STRATEGY.DLL");
            if (pressed > 0 && SaveSprite(strategy, pressed, P("buttons", $"{name}.pressed.png"), true, keyShade: true)) pictureCount++;
            if (disabled > 0 && SaveSprite(strategy, disabled, P("buttons", $"{name}.disabled.png"), true, keyShade: true)) pictureCount++;
        }
        foreach (var (name, id) in BlackKeyed)
        {
            if (SaveSprite(strategy, id, P("windows", $"{name}.png"), keyBlack: true)) { windows++; pictureCount++; }
            else missing.Add($"windows/{name}: no bitmap {id} in STRATEGY.DLL");
            // On a picked row the original keys only the black: a 15x16 icon's
            // blue last row shows, across the bar's edge (measured).
            if (name.StartsWith("msgicon.") && SaveSprite(strategy, id, P("windows", $"{name}.picked.png"), keyBlack: true, keepBlue: true)) pictureCount++;
        }
        foreach (var (name, normal, pressed, x, y, w, h) in ClippedButtons)
        {
            var clip = new Rectangle(x, y, w, h);
            if (SaveSprite(strategy, normal, P("buttons", $"{name}.png"), true, clip)) { buttons++; pictureCount++; }
            else missing.Add($"buttons/{name}: no bitmap {normal} in STRATEGY.DLL");
            if (SaveSprite(strategy, pressed, P("buttons", $"{name}.pressed.png"), true, clip)) pictureCount++;
        }
        Say($"sprites: {icons} corner icons, {sprites} planet sprites, {stars} GID stars, the uprising flame, {alerts} alert icons, {windows} window pictures, {tabs} tab icons, {buttons} buttons.");

        // The Create Mission window's mission pictures: GOKRES.DLL, per side.
        var cards = new PeResources(Path.Combine(_gameDir, "GOKRES.DLL"));
        int missionCards = 0;
        foreach (var row in ReadRows("missions.json", "missions"))
        {
            string id = row["id"]!.GetValue<string>();
            if (row["string_id"]?.GetValue<int>() is not int sid)
                continue;
            foreach (var (faction, less) in new[] { ("empire", MissionCardEmpire), ("alliance", MissionCardAlliance) })
            {
                if (SaveSprite(cards, sid - less, P("missions", $"{id}.{faction}.small.png"))) { missionCards++; pictureCount++; }
                else if (!id.StartsWith("unnamed"))
                    missing.Add($"missions/{id}.{faction}.small: no bitmap {sid - less} in GOKRES.DLL");
            }
            foreach (var (faction, more) in new[] { ("empire", MissionTileEmpire), ("alliance", MissionTileAlliance) })
            {
                if (SaveSprite(cards, sid + more, P("missions", $"{id}.{faction}.tile.png"))) { missionCards++; pictureCount++; }
                else if (!id.StartsWith("unnamed"))
                    missing.Add($"missions/{id}.{faction}.tile: no bitmap {sid + more} in GOKRES.DLL");
            }
        }
        Say($"mission pictures for Create Mission and the Mission window: {missionCards} (GOKRES.DLL).");
        // The mouse pointers: REBEXE.EXE's RT_CURSOR 3 (group 1001, the arrow -
        // all 179 of its pixels matched TeeJ's screenshot of the original) and 4
        // (group 1002, the targeting crosshair). Their hotspots go beside them.
        var exe = Path.Combine(_gameDir, "REBEXE.EXE");
        if (File.Exists(exe))
        {
            var rebexe = new PeResources(exe);
            var hotspots = new JsonObject();
            foreach (var (name, id) in new[] { ("pointer", 3), ("crosshair", 4) })
            {
                if (!rebexe.Cursors.ContainsKey(id)) { missing.Add($"cursors/{name}: no cursor {id} in REBEXE.EXE"); continue; }
                var (hx, hy, w, h, argb) = rebexe.Cursor(id);
                using var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
                for (int y = 0; y < h; y++)
                    for (int x = 0; x < w; x++)
                        bmp.SetPixel(x, y, Color.FromArgb(argb[y * w + x]));
                _sink.Write(P("cursors", $"{name}.png"), Png(bmp));
                hotspots[name] = new JsonArray(hx, hy);
                pictureCount++;
            }
            _sink.WriteText(P("cursors", "hotspots.json"), hotspots.ToJsonString() + "\n");
        }
        else
            missing.Add("REBEXE.EXE not found - no mouse pointers");

        foreach (var (name, id) in QueuePictures)
        {
            if (SaveSprite(cards, id, P("windows", $"{name}.png"), keyCorner: true)) pictureCount++;
            else missing.Add($"windows/{name}: no bitmap {id} in GOKRES.DLL");
        }

        var commonDll = Path.Combine(_gameDir, "COMMON.DLL");
        if (File.Exists(commonDll) && SaveSprite(new PeResources(commonDll), CockpitBitmap, P("screens", "cockpit.png"))) pictureCount++;
        else missing.Add($"screens/cockpit: no bitmap {CockpitBitmap} in COMMON.DLL");
        if (File.Exists(commonDll))
        {
            var common = new PeResources(commonDll);
            int monitors = 0;
            foreach (var (name, first, frames) in CockpitMonitors)
            {
                if (SaveStrip(common, first, frames, P("menu", $"{name}.png"))) { monitors++; pictureCount++; }
                else missing.Add($"menu/{name}: no bitmaps {first}-{first + frames - 1} in COMMON.DLL");
            }
            Say($"cockpit monitors: {monitors} (COMMON.DLL).");
        }
        if (SaveGalaxy(strategy, P("screens", "galaxy.png"))) pictureCount++;
        else missing.Add($"screens/galaxy: no bitmap {GalaxyBitmap} in STRATEGY.DLL");

        // Portraits and list miniatures: GOKRES.DLL, by the id map built into the exe.
        var idMapText = BuiltIn("gokres_map.json");
        if (idMapText != null)
        {
            var gokres = new PeResources(Path.Combine(_gameDir, "GOKRES.DLL"));
            var idMap = JsonNode.Parse(idMapText)!.AsObject();
            int portraits = 0, minis = 0;
            foreach (var (kind, rowsNode) in idMap)
            {
                foreach (var (id, entry) in rowsNode!.AsObject())
                {
                    int? portrait = entry!["portrait"]?.GetValue<int>();
                    int? mini = entry["miniature"]?.GetValue<int>();
                    if (portrait is int p && SaveSprite(gokres, p, P("portraits", kind, id + ".png"))) { portraits++; pictureCount++; }
                    else missing.Add($"portraits/{kind}/{id}: no bitmap {portrait} in GOKRES.DLL");
                    // A capital ship's flames, drawn UNDER its picture on the
                    // Status window when it is damaged: GOKRES picture + 8192
                    // (measured: 10053 under the Corellian Corvette's 1861;
                    // every ship's flames follow its own hull).
                    if (portrait is int pd && entry["family"]?.GetValue<string>() == "capital_ship"
                        && SaveSprite(gokres, pd + 8192, P("portraits", kind, id + ".damage.png"))) pictureCount++;
                    if (mini is int m && SaveSprite(gokres, m, P("miniatures", kind, id + ".png"))) { minis++; pictureCount++; }
                }
            }
            Say($"portraits: {portraits}, list miniatures: {minis} (GOKRES.DLL).");
        }
        else
            missing.Add("gokres_map.json is not built into the exporter - no portraits or miniatures");

        // The Game Options screen and its parts (COMMON.DLL).
        var optionsDll = Path.Combine(_gameDir, "COMMON.DLL");
        if (File.Exists(optionsDll))
        {
            var common = new PeResources(optionsDll);
            if (SaveSprite(common, OptionsBitmap, P("screens", "options.png"))) pictureCount++;
            else missing.Add($"screens/options: no bitmap {OptionsBitmap} in COMMON.DLL");
            int optionParts = 0;
            foreach (var (name, normal, pressed, disabled) in OptionsButtons)
            {
                if (SaveSprite(common, normal, P("buttons", $"{name}.png"))) { optionParts++; pictureCount++; }
                else missing.Add($"buttons/{name}: no bitmap {normal} in COMMON.DLL");
                if (pressed > 0 && SaveSprite(common, pressed, P("buttons", $"{name}.pressed.png"))) pictureCount++;
                if (disabled > 0 && SaveSprite(common, disabled, P("buttons", $"{name}.disabled.png"))) pictureCount++;
            }
            foreach (var (name, id) in OptionsParts)
            {
                if (SaveSprite(common, id, P("windows", $"{name}.png"))) { optionParts++; pictureCount++; }
                else missing.Add($"windows/{name}: no bitmap {id} in COMMON.DLL");
            }
            Say($"Game Options: the screen and {optionParts} parts (COMMON.DLL).");
        }

        // The Speed Control and the alert box.
        int hud = 0;
        foreach (var (name, frame, x, y, w, h) in FrameCuts)
        {
            if (SaveSprite(strategy, frame, P("windows", $"{name}.png"), false, new Rectangle(x, y, w, h))) { hud++; pictureCount++; }
            else missing.Add($"windows/{name}: no bitmap {frame} in STRATEGY.DLL");
        }
        foreach (var (side, ids) in SpeedBars)
            for (int n = 0; n < ids.Length; n++)
            {
                if (SaveSprite(strategy, ids[n], P("windows", $"speed_bars.{side}.{n}.png"))) { hud++; pictureCount++; }
                else missing.Add($"windows/speed_bars.{side}.{n}: no bitmap {ids[n]} in STRATEGY.DLL");
            }
        var dlogDll = Path.Combine(_gameDir, "REBDLOG.DLL");
        if (File.Exists(dlogDll))
        {
            var dlog = new PeResources(dlogDll);
            foreach (var (name, id) in DialogPlates)
            {
                if (SaveSprite(dlog, id, P("windows", $"{name}.png"))) { hud++; pictureCount++; }
                else missing.Add($"windows/{name}: no bitmap {id} in REBDLOG.DLL");
            }
            foreach (var (name, normal, pressed) in DialogButtons)
            {
                if (SaveSprite(dlog, normal, P("buttons", $"{name}.png"))) { hud++; pictureCount++; }
                else missing.Add($"buttons/{name}: no bitmap {normal} in REBDLOG.DLL");
                if (SaveSprite(dlog, pressed, P("buttons", $"{name}.pressed.png"))) pictureCount++;
            }
        }
        else
            missing.Add("REBDLOG.DLL not found - no alert box");
        Say($"Speed Control and alert box: {hud} pictures.");

        _sink.WriteText(P("descriptions.json"),
            descriptions.ToJsonString(new JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping }) + "\n");
        _sink.WriteText(P("README.txt"),
            "Artwork and text exported from YOUR installed copy of Star Wars: Rebellion by the\n" +
            "Faction Wars Exporter. It belongs to LucasArts / Disney and is for your own use\n" +
            "with the game you bought. Keep it as your backup; do not share or upload it.\n");
        Say($"Done: {pictureCount} pictures and {textCount} descriptions.");
        if (missing.Count > 0)
            Say($"{missing.Count} row(s) had nothing to import (listed below).");
        return new Result(pictureCount, textCount, missing, log);
    }

    private List<JsonObject> ReadRows(string file, string key)
    {
        var doc = JsonNode.Parse(RowText(_rowsDir, file)!)!.AsObject();
        return doc[key]!.AsArray().Select(n => n!.AsObject()).ToList();
    }

    /// <summary>A bitmap as a PNG with the key colour transparent: pure blue
    /// everywhere, and pure magenta too for the window tabs and buttons, whose
    /// corners the original keys out the same way.
    /// A clip rectangle crops the bitmap to the part the original draws; a
    /// clipped button's second magenta shade (204,28,205) is keyed as well
    /// (never elsewhere: the Manufacturing tab pictures draw it).</summary>
    private bool SaveSprite(PeResources dll, int bitmapId, string outPath, bool keyMagenta = false, Rectangle? clip = null,
        bool keyCorner = false, bool keyBlack = false, bool keyShade = false, bool keepBlue = false)
    {
        if (!dll.Bitmaps.ContainsKey(bitmapId))
            return false;
        using var stream = new MemoryStream(dll.BitmapFile(bitmapId));
        using var bmp = new Bitmap(stream);
        var r = clip ?? new Rectangle(0, 0, bmp.Width, bmp.Height);
        // keyCorner: the bitmap's own bottom-left colour is its transparent
        // colour, in place of blue (a queue picture keys its asphalt).
        var corner = bmp.GetPixel(0, bmp.Height - 1);
        using var rgba = new Bitmap(r.Width, r.Height, PixelFormat.Format32bppArgb);
        for (int y = 0; y < r.Height; y++)
            for (int x = 0; x < r.Width; x++)
            {
                var c = bmp.GetPixel(r.X + x, r.Y + y);
                bool key = keyCorner ? c.ToArgb() == corner.ToArgb() :
                    (c.R == 0 && c.G == 0 && c.B == 255 && !DrawnWhole.Contains(bitmapId) && !keepBlue)
                    || (keyMagenta && c.R == 255 && c.G == 0 && c.B == 255)
                    || (keyBlack && c.R == 0 && c.G == 0 && c.B == 0)
                    || ((clip != null || keyShade) && c.R == 204 && c.G == 28 && c.B == 205);
                rgba.SetPixel(x, y, key ? Color.Transparent : Color.FromArgb(255, c.R, c.G, c.B));
            }
        _sink.Write(outPath, Png(rgba));
        return true;
    }

    /// <summary>Frames first..first+frames-1, all one size, side by side in one
    /// PNG (pure blue keyed out), for the engine to play as an animation.</summary>
    private bool SaveStrip(PeResources dll, int first, int frames, string outPath)
    {
        var bitmaps = new List<Bitmap>();
        try
        {
            for (int i = 0; i < frames; i++)
            {
                if (!dll.Bitmaps.ContainsKey(first + i))
                    return false;
                bitmaps.Add(new Bitmap(new MemoryStream(dll.BitmapFile(first + i))));
            }
            int w = bitmaps[0].Width, h = bitmaps[0].Height;
            if (bitmaps.Any(b => b.Width != w || b.Height != h))
                return false;
            using var strip = new Bitmap(w * frames, h, PixelFormat.Format32bppArgb);
            for (int f = 0; f < frames; f++)
                for (int y = 0; y < h; y++)
                    for (int x = 0; x < w; x++)
                    {
                        var c = bitmaps[f].GetPixel(x, y);
                        bool key = c.R == 0 && c.G == 0 && c.B == 255;
                        strip.SetPixel(f * w + x, y, key ? Color.Transparent : Color.FromArgb(255, c.R, c.G, c.B));
                    }
            _sink.Write(outPath, Png(strip));
            return true;
        }
        finally
        {
            foreach (var b in bitmaps)
                b.Dispose();
        }
    }

    private bool SavePicture(PeResources pictures, int encyId, string outPath)
    {
        if (!pictures.Strings.TryGetValue(encyId, out var file))
            return false;
        var src = Path.Combine(_gameDir, "EData", file);
        if (!File.Exists(src))
            return false;
        using var bmp = new Bitmap(src);
        using var rgb = new Bitmap(bmp.Width, bmp.Height, PixelFormat.Format24bppRgb);
        using (var g = Graphics.FromImage(rgb))
            g.DrawImage(bmp, 0, 0, bmp.Width, bmp.Height);
        _sink.Write(outPath, Png(rgb));
        return true;
    }

    /// <summary>The galaxy map, 903, mirrored out to GalaxyWidth x GalaxyHeight.</summary>
    private bool SaveGalaxy(PeResources dll, string outPath)
    {
        if (!dll.Bitmaps.ContainsKey(GalaxyBitmap))
            return false;
        using var stream = new MemoryStream(dll.BitmapFile(GalaxyBitmap));
        using var src = new Bitmap(stream);
        using var dst = new Bitmap(GalaxyWidth, GalaxyHeight, PixelFormat.Format24bppRgb);
        int w = src.Width, h = src.Height;
        for (int y = 0; y < GalaxyHeight; y++)
            for (int x = 0; x < GalaxyWidth; x++)
            {
                int sx = x < w ? x : Math.Max(0, 2 * w - 1 - x);
                int sy = y < h ? y : Math.Max(0, 2 * h - 1 - y);
                dst.SetPixel(x, y, src.GetPixel(sx, sy));
            }
        _sink.Write(outPath, Png(dst));
        return true;
    }

    /// <summary>A path inside the art set: always forward slashes.</summary>
    private static string P(params string[] parts) => string.Join('/', parts);

    private static byte[] Png(Bitmap bmp)
    {
        using var ms = new MemoryStream();
        bmp.Save(ms, ImageFormat.Png);
        return ms.ToArray();
    }
}
