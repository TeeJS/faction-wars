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
}
