namespace FactionWarsExporter;

/// <summary>
/// The exporter's three jobs, shared by the window and the command line
/// (docs/original-art-plan.md, phase 1):
///   an ART SET file (the default) or folder, from the player's own install;
///   a FACTION PACK file, built from a folder, checked against the art set.
/// </summary>
public static class Exporter
{
    public const string ArtSetId = "swr-original";
    public const string ArtSetTitle = "Star Wars: Rebellion - original artwork";

    /// <summary>Where the art-set file goes unless the player picks elsewhere:
    /// Documents\Faction Wars\swr-original.art.zip. It is their backup.</summary>
    public static string DefaultArtFile =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "Faction Wars", ArtSetId + ".art.zip");

    /// <summary>Exports the art set through a sink and writes its manifest.</summary>
    public static Importer.Result ExportArtSet(string gameDir, string rowsDir, ArtSink sink, Action<string> report)
    {
        var result = new Importer(gameDir, rowsDir, sink, report).Run();
        sink.Finish(Manifest.New(Manifest.KindArtSet, ArtSetId, ArtSetTitle));
        report($"{sink.Hashes.Count} files in the art set.");
        return result;
    }

    /// <summary>
    /// The art set's hashes for the pack builder's leak guard: the art set
    /// named, else the default art-set file, else the art set read in memory
    /// from the game (when one is found). Null when there is none of these.
    /// </summary>
    public static HashSet<string>? ArtSetHashes(string? artPath, string gameDir, Action<string> report)
    {
        foreach (var path in new[] { artPath, DefaultArtFile })
        {
            if (string.IsNullOrEmpty(path))
                continue;
            var hashes = Manifest.ArtSetHashes(path);
            if (hashes != null)
            {
                report($"Checking against the art set {path} ({hashes.Count} distinct files).");
                return hashes;
            }
            if (path == artPath)
                report($"{path} is not an art set - looking elsewhere.");
        }
        if (!string.IsNullOrEmpty(gameDir) && Importer.Problem(gameDir, Importer.BundledRows) == null)
        {
            report($"Checking against the original's art read from {gameDir}.");
            using var sink = new HashSink();
            new Importer(gameDir, Importer.BundledRows, sink, _ => { }).Run();
            return sink.Hashes.Values.ToHashSet();
        }
        return null;
    }
}
