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
///
/// Output, under the pack folder (gitignored - never committed):
///   original/characters/&lt;id&gt;.png   original/units/&lt;id&gt;.png
///   original/facilities/&lt;id&gt;.png   original/planets/&lt;id&gt;.png
///   original/missions/&lt;id&gt;.png (+ &lt;id&gt;.empire.png)
///   original/descriptions.json     { "characters": { id: text }, ... }
///   original/portraits/&lt;kind&gt;/&lt;id&gt;.png   original/miniatures/&lt;kind&gt;/&lt;id&gt;.png
///   original/icons/&lt;glyph&gt;.&lt;faction&gt;.png (+ .hover.png)   sector-window corners
///   original/icons/uprising.png (+ .hover.png)             the flame, two frames
///   original/gid/&lt;faction&gt;.&lt;tier&gt;.png, gid/unexplored.&lt;tier&gt;.png   the GID stars
///   original/planet_sprites/&lt;artwork_id&gt;.png              the map's planets
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

    // STRATEGY.DLL: (glyph, faction id, normal bitmap, highlighted bitmap).
    private static readonly (string Glyph, string Faction, int Normal, int Hover)[] CornerIcons =
    {
        ("manufacturing", "alliance", 10771, 10772), ("defenses", "alliance", 10773, 10774),
        ("fleet", "alliance", 10775, 10776), ("mission", "alliance", 10777, 10778),
        ("manufacturing", "empire", 10779, 10780), ("defenses", "empire", 10781, 10782),
        ("fleet", "empire", 10783, 10784), ("mission", "empire", 10785, 10786),
        ("manufacturing", "neutral", 10787, 10788), ("defenses", "neutral", 10789, 10790),
    };

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

                if (SavePicture(pictures, ency, Path.Combine(outRoot, kind, id + ".png")))
                {
                    pictureCount++;
                    got++;
                }
                else
                    missing.Add($"{kind}/{id}: no picture at Encyclopedia id {ency}");

                // Missions carry a second, Imperial picture at the string id itself.
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
        Say($"sprites: {icons} corner icons, {sprites} planet sprites, {stars} GID stars, the uprising flame.");

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
    private static bool SaveSprite(PeResources dll, int bitmapId, string outPath)
    {
        if (!dll.Bitmaps.ContainsKey(bitmapId))
            return false;
        Directory.CreateDirectory(Path.GetDirectoryName(outPath)!);
        using var stream = new MemoryStream(dll.BitmapFile(bitmapId));
        using var bmp = new Bitmap(stream);
        using var rgba = new Bitmap(bmp.Width, bmp.Height, PixelFormat.Format32bppArgb);
        for (int y = 0; y < bmp.Height; y++)
            for (int x = 0; x < bmp.Width; x++)
            {
                var c = bmp.GetPixel(x, y);
                bool key = c.R == 0 && c.G == 0 && c.B == 255;
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
