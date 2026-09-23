using System.Security.Cryptography;
using System.Text.Json.Nodes;

namespace FactionWarsExporter;

/// <summary>
/// Builds a FACTION PACK file from a folder (docs/original-art-plan.md): the
/// pack's JSON and the author's own pictures, zipped with a manifest. A faction
/// pack is shareable, so it must carry none of the original's art. The leak
/// guard refuses the build when any file has the same SHA-256 as a file in the
/// art set, and when anything sits under an original/ folder (the old home of
/// the imported art). Godot's own sidecars (*.import, *.uid) are left out.
/// </summary>
public static class PackBuilder
{
    public sealed record Result(bool Ok, string Message, int Files);

    /// <param name="artSetHashes">the art set's hashes, or null when no art set
    /// could be found to check against (the build then warns, and the game
    /// checks again on import against the player's own art set).</param>
    public static Result Build(string folder, string outZip, HashSet<string>? artSetHashes, Action<string> report)
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

        var leaked = new List<string>();
        foreach (var (full, rel) in files)
        {
            if (rel.StartsWith("original/", StringComparison.OrdinalIgnoreCase))
                leaked.Add(rel + "  (the original's art lives in the art set, not in a pack)");
            else if (artSetHashes != null && artSetHashes.Contains(ArtSink.Hex(SHA256.HashData(File.ReadAllBytes(full)))))
                leaked.Add(rel + "  (the same picture as one in your art set)");
        }
        if (leaked.Count > 0)
            return new(false, "Not built: a faction pack is shared, so it must not carry the original's art. " +
                              "Refer to the art set instead (\"art\": \"swr-original:...\"). These files are the original's:\n  "
                              + string.Join("\n  ", leaked), 0);
        if (artSetHashes == null)
            report("Warning: no art set was found to check against, so this pack was not checked for the original's pictures. " +
                   "Faction Wars checks again when the pack is imported.");

        using var sink = new ZipSink(outZip);
        foreach (var (full, rel) in files)
            sink.Write(rel, File.ReadAllBytes(full));
        sink.Finish(Manifest.New(Manifest.KindFactionPack, id, title));
        return new(true, $"Built {outZip}: {files.Count} files.", files.Count);
    }
}
