namespace FactionWarsExporter;

/// <summary>
/// THE ORIGINAL'S VOICES AND SOUND EFFECTS IN THE ART SET (docs/advisor-plan.md;
/// TeeJ, 2026-09-27: the voices go with the art, and "we are also missing the
/// sounds from the cockpit ... can we please also include those this round?").
/// Every "WAVE" resource of the DLLs below, as Ogg Vorbis at the original's own
/// rate: sound/&lt;dll&gt;/&lt;id&gt;.ogg, the id the original's own - which plays when
/// is the pack's to say. About 55 minutes, about 12 MB.
///
/// The briefing DLLs are read under their own names or, as a compatibility
/// patch leaves them, renamed .DLL.OLD.
/// </summary>
internal static class Sound
{
    /// <summary>The DLL and the art set's folder for its sounds.</summary>
    public static readonly (string Dll, string Folder)[] Sources =
    {
        ("ALSPRITE.DLL", "alsprite"),   // the Alliance's droids and characters
        ("EMSPRITE.DLL", "emsprite"),   // the Empire's
        ("ALBRIEF.DLL", "albrief"),     // the Alliance's opening briefing
        ("EMBRIEF.DLL", "embrief"),     // the Empire's
        ("VOICEFXA.DLL", "voicefxa"),   // the battle view's voices, Alliance
        ("VOICEFXE.DLL", "voicefxe"),   // Empire
        ("COMMON.DLL", "common"),       // the Shuttle Cockpit's controls
        ("STRATEGY.DLL", "strategy"),   // the Command Center's
        ("TACTICAL.DLL", "tactical"),   // the battle view's effects
    };
    /// <summary>Vorbis quality, -0.1 to 1.0, as the music's.</summary>
    public const float Quality = 0.3f;

    /// <summary>A game DLL's path, or null: its own name, else as .DLL.OLD.</summary>
    public static string? Find(string gameDir, string dll)
    {
        foreach (var name in new[] { dll, dll + ".OLD" })
        {
            var path = Path.Combine(gameDir, name);
            if (File.Exists(path))
                return path;
        }
        return null;
    }

    /// <summary>Writes every sound there is; returns how many. A DLL that is
    /// not there, or a sound that cannot be read, goes to `missing`.</summary>
    public static int Export(string gameDir, ArtSink sink, List<string> missing, Action<string> say)
    {
        var problem = Xiph.Problem();
        if (problem != null)
        {
            missing.Add("sounds: " + problem);
            return 0;
        }
        int written = 0;
        long bytes = 0;
        var perDll = new List<string>();
        foreach (var (dll, folder) in Sources)
        {
            var path = Find(gameDir, dll);
            if (path == null)
            {
                missing.Add($"sound/{folder}: {dll} not found");
                continue;
            }
            var res = new PeResources(path);
            int here = 0;
            foreach (var id in res.Waves.Keys.OrderBy(k => k))
            {
                try
                {
                    var (samples, channels, rate) = Music.ReadWav(res.WaveBytes(id));
                    var ogg = OggTheora.EncodeAudio(samples, channels, rate, Quality);
                    sink.Write($"sound/{folder}/{id}.ogg", ogg);
                    bytes += ogg.Length;
                    written++;
                    here++;
                }
                catch (InvalidDataException ex)
                {
                    missing.Add($"sound/{folder}/{id}: {ex.Message}");
                }
            }
            perDll.Add($"{folder} {here}");
        }
        say($"Sounds: {written} ({string.Join(", ", perDll)}), {bytes / 1048576.0:0.0} MB.");
        return written;
    }
}
