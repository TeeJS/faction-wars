using System.Drawing;
using System.Drawing.Imaging;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace RebellionArtImporter;

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
/// Output, under the pack folder (gitignored - never committed):
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
        ("mission_agents.alliance", 11121), ("mission_decoys.alliance", 11122),
        ("mission_agents.empire", 11123), ("mission_decoys.empire", 11124),
        // A Status window (manual p064: modal, no title bar, closed by its
        // diamond): the 379x272 plate per side - the field panel with the
        // side's emblem, the picture and name grids, the button sockets - and
        // the grey spotlight behind a trooper regiment's picture (122x50).
        ("status_plate.alliance", 11554), ("status_plate.empire", 11558),
        ("status_backdrop.troops", 11514),
        // The Message Index (p078 Fig 3.18): the Alliance's socket column over
        // the frame's right strip, and the plate under a read message (p080
        // Fig 3.19, the band across its top - not yet on a screenshot).
        ("msgindex_side.alliance", 10820), ("msgsummary_plate", 10823),
        // Build Selection (p045, p112 Fig 3.58): the 210x261 plate - the frame,
        // the picture box, the two cost boxes with their icons, the times box
        // and the number box (TeeJ's screenshot of the original, Empire).
        ("build_plate", 10800),
        // The confirmation dialog (TeeJ's screenshot of the original's Scrap,
        // Empire, rebuilt pixel for pixel): the 424x331 frame per side (no title
        // bar; the Alliance's 11125 inferred), and Scrap's 400x200 console picture
        // per side, drawn whole (the Alliance's 1032 inferred).
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
    // tab): the selected row's bar per side (356x21) and the rows' 15x15
    // category icons - Advice per side seen; the others are the same set's
    // pictures, matched to their category by what they show (not yet seen).
    private static readonly (string Name, int Id)[] BlackKeyed =
    {
        ("msgindex_selection.empire", 10915), ("msgindex_selection.alliance", 10914),
        ("msgicon.advice.empire", 10969), ("msgicon.advice.alliance", 10968),
        ("msgicon.loyalty", 10916), ("msgicon.fleets.empire", 10965), ("msgicon.fleets.alliance", 10964),
        ("msgicon.resources", 10966),
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
    };

    // STRATEGY.DLL: buttons as (name, normal, pressed/current, disabled).
    private static readonly (string Name, int Normal, int Pressed, int Disabled)[] Buttons =
    {
        // A window's title bar: the system box, minimise, close (14x14).
        ("title_system", 10209, 0, 0), ("title_minimize", 10253, 0, 0), ("title_close", 10108, 0, 0),
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
    };

    // GOKRES.DLL: the 130x65 picture of each mission in the Create Mission
    // window, per side, at the row's string_id less these (Recruitment's
    // 11286 - 4096 = 7190 matched TeeJ's Imperial screenshot pixel for pixel;
    // all 21 were checked by eye, the Alliance set 4096 below the Empire's).
    private const int MissionCardEmpire = 4096;
    private const int MissionCardAlliance = 8192;

    // Bitmaps the original draws WHOLE, pure blue included: the Create Mission
    // plates' blue line under the tabs and the tabs' blue edges are on TeeJ's
    // screenshot of the original, pixel for pixel (2026-09-23).
    private static readonly HashSet<int> DrawnWhole = new() { 11100, 11101, 11103, 11104, 11105, 11106, 11107, 11108, 11109, 11110,
        // The Status plates are opaque; the pressed Encyclopedia button keeps its blue face.
        11554, 11558, 11553,
        // Build Selection's plate is opaque; so are the Scrap pictures.
        10800, 1032, 1033 };

    public sealed record Result(int Pictures, int Descriptions, List<string> Missing, List<string> Log);

    private readonly string _gameDir;
    private readonly string _packDir;
    private readonly Action<string> _report;

    public Importer(string gameDir, string packDir, Action<string> report)
    {
        _gameDir = gameDir;
        _packDir = packDir;
        _report = report;
    }

    public static string? Problem(string gameDir, string packDir)
    {
        foreach (var f in new[] { "ENCYTEXT.DLL", "ENCYBMAP.DLL", "TEXTSTRA.DLL", "STRATEGY.DLL", "GOKRES.DLL" })
            if (!File.Exists(Path.Combine(gameDir, f)))
                return $"{f} is not in {gameDir} - is that the installed game's folder?";
        if (!Directory.Exists(Path.Combine(gameDir, "EData")))
            return $"There is no EData folder in {gameDir}.";
        if (!File.Exists(Path.Combine(packDir, "pack.json")))
            return $"{packDir} has no pack.json - pick the packs\\star-wars-rebellion folder.";
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

        var outRoot = Path.Combine(_packDir, "original");
        Directory.CreateDirectory(outRoot);
        var descriptions = new JsonObject();
        int pictureCount = 0, textCount = 0;

        foreach (var (file, kind) in new[] { ("characters.json", "characters"), ("units.json", "units"), ("facilities.json", "facilities"), ("missions.json", "missions") })
        {
            var rows = ReadRows(Path.Combine(_packDir, file), kind);
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
                if (SavePicture(pictures, ency, Path.Combine(outRoot, kind, outName)))
                {
                    pictureCount++;
                    got++;
                }
                else
                    missing.Add($"{kind}/{id}: no picture at Encyclopedia id {ency}");
                if (kind == "missions" && SavePicture(pictures, stringId.Value, Path.Combine(outRoot, kind, id + ".empire.png")))
                    pictureCount++;
            }
            descriptions[kind] = texts;
            Say($"{kind}: {got} of {rows.Count} pictures, {texts.Count} descriptions.");
        }

        // Planets: 26 portraits shared by artwork_id; no Encyclopedia text.
        var map = JsonNode.Parse(File.ReadAllText(Path.Combine(_packDir, "map.json")))!.AsObject();
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
            if (SavePicture(pictures, PlanetPictureBase + art.Value - 1, Path.Combine(outRoot, "planets", id + ".png")))
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
            if (SaveSprite(strategy, normal, Path.Combine(outRoot, "icons", $"{glyph}.{faction}.png"))) { icons++; pictureCount++; }
            else missing.Add($"icons/{glyph}.{faction}: no bitmap {normal} in STRATEGY.DLL");
            if (SaveSprite(strategy, hover, Path.Combine(outRoot, "icons", $"{glyph}.{faction}.hover.png"))) { icons++; pictureCount++; }
        }
        int sprites = 0;
        for (int art = 1; art <= PlanetSpriteCount; art++)
        {
            if (SaveSprite(strategy, PlanetSpriteBase + art - 1, Path.Combine(outRoot, "planet_sprites", $"{art}.png"))) { sprites++; pictureCount++; }
            else missing.Add($"planet_sprites/{art}: no bitmap {PlanetSpriteBase + art - 1} in STRATEGY.DLL");
        }
        int stars = 0;
        foreach (var (faction, big, mid, low, none) in GidStars)
        {
            foreach (var (tier, id) in new[] { ("big", big), ("mid", mid), ("low", low), ("none", none) })
            {
                if (SaveSprite(strategy, id, Path.Combine(outRoot, "gid", $"{faction}.{tier}.png"))) { stars++; pictureCount++; }
                else missing.Add($"gid/{faction}.{tier}: no bitmap {id} in STRATEGY.DLL");
            }
        }
        if (SaveSprite(strategy, UprisingFrame1, Path.Combine(outRoot, "icons", "uprising.png"))) pictureCount++;
        else missing.Add($"icons/uprising: no bitmap {UprisingFrame1} in STRATEGY.DLL");
        if (SaveSprite(strategy, UprisingFrame2, Path.Combine(outRoot, "icons", "uprising.hover.png"))) pictureCount++;
        int alerts = 0;
        foreach (var (faction, dim, lit) in AlertSets)
            for (int k = 0; k < AlertCategories.Length; k++)
            {
                if (SaveSprite(strategy, dim + k, Path.Combine(outRoot, "alerts", $"{faction}.{AlertCategories[k]}.png"))) { alerts++; pictureCount++; }
                else missing.Add($"alerts/{faction}.{AlertCategories[k]}: no bitmap {dim + k} in STRATEGY.DLL");
                if (SaveSprite(strategy, lit + k, Path.Combine(outRoot, "alerts", $"{faction}.{AlertCategories[k]}.lit.png"))) { alerts++; pictureCount++; }
            }
        int windows = 0;
        foreach (var (name, id) in WindowPictures)
        {
            if (SaveSprite(strategy, id, Path.Combine(outRoot, "windows", $"{name}.png"))) { windows++; pictureCount++; }
            else missing.Add($"windows/{name}: no bitmap {id} in STRATEGY.DLL");
        }
        int tabs = 0;
        foreach (var (name, faction, normal, current, grey) in TabIcons)
        {
            var stem = faction.Length == 0 ? name : $"{name}.{faction}";
            if (SaveSprite(strategy, normal, Path.Combine(outRoot, "tabs", $"{stem}.png"), true)) { tabs++; pictureCount++; }
            else missing.Add($"tabs/{stem}: no bitmap {normal} in STRATEGY.DLL");
            if (SaveSprite(strategy, current, Path.Combine(outRoot, "tabs", $"{stem}.pressed.png"), true)) pictureCount++;
            if (grey > 0 && SaveSprite(strategy, grey, Path.Combine(outRoot, "tabs", $"{stem}.grey.png"), true)) pictureCount++;
        }
        int buttons = 0;
        foreach (var (name, normal, pressed, disabled) in Buttons)
        {
            if (SaveSprite(strategy, normal, Path.Combine(outRoot, "buttons", $"{name}.png"), true)) { buttons++; pictureCount++; }
            else missing.Add($"buttons/{name}: no bitmap {normal} in STRATEGY.DLL");
            if (pressed > 0 && SaveSprite(strategy, pressed, Path.Combine(outRoot, "buttons", $"{name}.pressed.png"), true)) pictureCount++;
            if (disabled > 0 && SaveSprite(strategy, disabled, Path.Combine(outRoot, "buttons", $"{name}.disabled.png"), true)) pictureCount++;
        }
        foreach (var (name, normal, pressed, disabled) in ShadedButtons)
        {
            if (SaveSprite(strategy, normal, Path.Combine(outRoot, "buttons", $"{name}.png"), true, keyShade: true)) { buttons++; pictureCount++; }
            else missing.Add($"buttons/{name}: no bitmap {normal} in STRATEGY.DLL");
            if (pressed > 0 && SaveSprite(strategy, pressed, Path.Combine(outRoot, "buttons", $"{name}.pressed.png"), true, keyShade: true)) pictureCount++;
            if (disabled > 0 && SaveSprite(strategy, disabled, Path.Combine(outRoot, "buttons", $"{name}.disabled.png"), true, keyShade: true)) pictureCount++;
        }
        foreach (var (name, id) in BlackKeyed)
        {
            if (SaveSprite(strategy, id, Path.Combine(outRoot, "windows", $"{name}.png"), keyBlack: true)) { windows++; pictureCount++; }
            else missing.Add($"windows/{name}: no bitmap {id} in STRATEGY.DLL");
        }
        foreach (var (name, normal, pressed, x, y, w, h) in ClippedButtons)
        {
            var clip = new Rectangle(x, y, w, h);
            if (SaveSprite(strategy, normal, Path.Combine(outRoot, "buttons", $"{name}.png"), true, clip)) { buttons++; pictureCount++; }
            else missing.Add($"buttons/{name}: no bitmap {normal} in STRATEGY.DLL");
            if (SaveSprite(strategy, pressed, Path.Combine(outRoot, "buttons", $"{name}.pressed.png"), true, clip)) pictureCount++;
        }
        Say($"sprites: {icons} corner icons, {sprites} planet sprites, {stars} GID stars, the uprising flame, {alerts} alert icons, {windows} window pictures, {tabs} tab icons, {buttons} buttons.");

        // The Create Mission window's mission pictures: GOKRES.DLL, per side.
        var cards = new PeResources(Path.Combine(_gameDir, "GOKRES.DLL"));
        int missionCards = 0;
        foreach (var row in ReadRows(Path.Combine(_packDir, "missions.json"), "missions"))
        {
            string id = row["id"]!.GetValue<string>();
            if (row["string_id"]?.GetValue<int>() is not int sid)
                continue;
            foreach (var (faction, less) in new[] { ("empire", MissionCardEmpire), ("alliance", MissionCardAlliance) })
            {
                if (SaveSprite(cards, sid - less, Path.Combine(outRoot, "missions", $"{id}.{faction}.small.png"))) { missionCards++; pictureCount++; }
                else if (!id.StartsWith("unnamed"))
                    missing.Add($"missions/{id}.{faction}.small: no bitmap {sid - less} in GOKRES.DLL");
            }
        }
        Say($"mission pictures for Create Mission: {missionCards} (GOKRES.DLL).");
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
                Directory.CreateDirectory(Path.Combine(outRoot, "cursors"));
                using var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
                for (int y = 0; y < h; y++)
                    for (int x = 0; x < w; x++)
                        bmp.SetPixel(x, y, Color.FromArgb(argb[y * w + x]));
                bmp.Save(Path.Combine(outRoot, "cursors", $"{name}.png"), ImageFormat.Png);
                hotspots[name] = new JsonArray(hx, hy);
                pictureCount++;
            }
            File.WriteAllText(Path.Combine(outRoot, "cursors", "hotspots.json"), hotspots.ToJsonString() + "\n");
        }
        else
            missing.Add("REBEXE.EXE not found - no mouse pointers");

        foreach (var (name, id) in QueuePictures)
        {
            if (SaveSprite(cards, id, Path.Combine(outRoot, "windows", $"{name}.png"), keyCorner: true)) pictureCount++;
            else missing.Add($"windows/{name}: no bitmap {id} in GOKRES.DLL");
        }

        // Portraits and list miniatures: GOKRES.DLL, by the shipped id map.
        var mapPath = Path.Combine(AppContext.BaseDirectory, "gokres_map.json");
        if (File.Exists(mapPath))
        {
            var gokres = new PeResources(Path.Combine(_gameDir, "GOKRES.DLL"));
            var idMap = JsonNode.Parse(File.ReadAllText(mapPath))!.AsObject();
            int portraits = 0, minis = 0;
            foreach (var (kind, rowsNode) in idMap)
            {
                foreach (var (id, entry) in rowsNode!.AsObject())
                {
                    int? portrait = entry!["portrait"]?.GetValue<int>();
                    int? mini = entry["miniature"]?.GetValue<int>();
                    if (portrait is int p && SaveSprite(gokres, p, Path.Combine(outRoot, "portraits", kind, id + ".png"))) { portraits++; pictureCount++; }
                    else missing.Add($"portraits/{kind}/{id}: no bitmap {portrait} in GOKRES.DLL");
                    if (mini is int m && SaveSprite(gokres, m, Path.Combine(outRoot, "miniatures", kind, id + ".png"))) { minis++; pictureCount++; }
                }
            }
            Say($"portraits: {portraits}, list miniatures: {minis} (GOKRES.DLL).");
        }
        else
            missing.Add("gokres_map.json is not beside the importer - no portraits or miniatures");

        File.WriteAllText(Path.Combine(outRoot, "descriptions.json"),
            descriptions.ToJsonString(new JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping }) + "\n");
        File.WriteAllText(Path.Combine(outRoot, "README.txt"),
            "Artwork and text copied from YOUR installed copy of Star Wars: Rebellion by the\n" +
            "Rebellion Art Importer. It belongs to LucasArts / Disney and is for your own use\n" +
            "with the game you bought. Do not commit or redistribute this folder.\n");
        Say($"Done: {pictureCount} pictures and {textCount} descriptions written to {outRoot}.");
        if (missing.Count > 0)
            Say($"{missing.Count} row(s) had nothing to import (listed below).");
        return new Result(pictureCount, textCount, missing, log);
    }

    private static List<JsonObject> ReadRows(string path, string key)
    {
        var doc = JsonNode.Parse(File.ReadAllText(path))!.AsObject();
        return doc[key]!.AsArray().Select(n => n!.AsObject()).ToList();
    }

    /// <summary>A STRATEGY.DLL bitmap as a PNG with the blue colour key made transparent.</summary>
    /// <summary>A bitmap as a PNG with the key colour transparent: pure blue
    /// everywhere, and pure magenta too for the window tabs and buttons, whose
    /// corners the original keys out the same way.
    /// A clip rectangle crops the bitmap to the part the original draws; a
    /// clipped button's second magenta shade (204,28,205) is keyed as well
    /// (never elsewhere: the Manufacturing tab pictures draw it).</summary>
    private static bool SaveSprite(PeResources dll, int bitmapId, string outPath, bool keyMagenta = false, Rectangle? clip = null,
        bool keyCorner = false, bool keyBlack = false, bool keyShade = false)
    {
        if (!dll.Bitmaps.ContainsKey(bitmapId))
            return false;
        Directory.CreateDirectory(Path.GetDirectoryName(outPath)!);
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
                    (c.R == 0 && c.G == 0 && c.B == 255 && !DrawnWhole.Contains(bitmapId))
                    || (keyMagenta && c.R == 255 && c.G == 0 && c.B == 255)
                    || (keyBlack && c.R == 0 && c.G == 0 && c.B == 0)
                    || ((clip != null || keyShade) && c.R == 204 && c.G == 28 && c.B == 205);
                rgba.SetPixel(x, y, key ? Color.Transparent : Color.FromArgb(255, c.R, c.G, c.B));
            }
        rgba.Save(outPath, ImageFormat.Png);
        return true;
    }

    private bool SavePicture(PeResources pictures, int encyId, string outPath)
    {
        if (!pictures.Strings.TryGetValue(encyId, out var file))
            return false;
        var src = Path.Combine(_gameDir, "EData", file);
        if (!File.Exists(src))
            return false;
        Directory.CreateDirectory(Path.GetDirectoryName(outPath)!);
        using var bmp = new Bitmap(src);
        using var rgb = new Bitmap(bmp.Width, bmp.Height, PixelFormat.Format24bppRgb);
        using (var g = Graphics.FromImage(rgb))
            g.DrawImage(bmp, 0, 0, bmp.Width, bmp.Height);
        rgb.Save(outPath, ImageFormat.Png);
        return true;
    }
}
