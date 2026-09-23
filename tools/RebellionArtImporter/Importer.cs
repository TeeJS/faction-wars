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
///
/// Output, under the pack folder (gitignored - never committed):
///   original/characters/&lt;id&gt;.png   original/units/&lt;id&gt;.png
///   original/facilities/&lt;id&gt;.png   original/planets/&lt;id&gt;.png
///   original/missions/&lt;id&gt;.png (+ &lt;id&gt;.empire.png)
///   original/descriptions.json     { "characters": { id: text }, ... }
/// </summary>
public sealed class Importer
{
    public const int TextOffset = 4096;
    public const int PlanetPictureBase = 11100;

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
        foreach (var f in new[] { "ENCYTEXT.DLL", "ENCYBMAP.DLL", "TEXTSTRA.DLL" })
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
