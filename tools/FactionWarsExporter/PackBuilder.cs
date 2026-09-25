using System.Text.Json.Nodes;

namespace FactionWarsExporter;

/// <summary>
/// Builds a FACTION PACK file from a folder (docs/original-art-plan.md): the
/// pack's JSON and its pictures, zipped with a manifest. Whatever pictures the
/// author chose go in, the original's included: Star Wars: Rebellion has a
/// modding culture - the original came with its own editor - and a mod is the
/// modder's to make (TeeJ, 2026-09-25). Godot's own sidecars (*.import,
/// *.uid) are left out.
/// </summary>
public static class PackBuilder
{
    public sealed record Result(bool Ok, string Message, int Files);

    public static Result Build(string folder, string outZip, Action<string> report)
    {
        var packJson = Path.Combine(folder, "pack.json");
        if (!File.Exists(packJson))
            return new(false, $"{folder} has no pack.json - pick a faction pack's folder.", 0);
        var pack = JsonNode.Parse(File.ReadAllText(packJson))?.AsObject();
        var id = pack?["id"]?.GetValue<string>() ?? "";
        if (id.Length == 0)
            return new(false, "pack.json has no \"id\".", 0);
        var title = pack?["display_name"]?.GetValue<string>() ?? id;

        var files = Directory.EnumerateFiles(folder, "*", SearchOption.AllDirectories)
            .Select(f => (Full: f, Rel: Path.GetRelativePath(folder, f).Replace('\\', '/')))
            .Where(f => !f.Rel.EndsWith(".import", StringComparison.OrdinalIgnoreCase)
                        && !f.Rel.EndsWith(".uid", StringComparison.OrdinalIgnoreCase)
                        && f.Rel != Manifest.FileName)
            .OrderBy(f => f.Rel, StringComparer.Ordinal)
            .ToList();

        using var sink = new ZipSink(outZip);
        foreach (var (full, rel) in files)
            sink.Write(rel, File.ReadAllBytes(full));
        sink.Finish(Manifest.New(Manifest.KindFactionPack, id, title));
        return new(true, $"Built {outZip}: {files.Count} files.", files.Count);
    }
}
