namespace FactionWarsExporter;

internal static class Program
{
    /// <summary>
    /// Double-click: the window. From a script, without a window:
    ///   FactionWarsExporter.exe --gamedir "C:\...\Star Wars - Rebellion" --out "D:\...\swr-original.art.zip"
    ///       the art-set file (log: &lt;out&gt;.log)
    ///   FactionWarsExporter.exe --gamedir "..." --folder "D:\...\swr-original"
    ///       the art set as a folder (log: &lt;folder&gt;\export.log)
    ///   A checkout's own copy: --folder "&lt;repo&gt;\art\swr-original" (gitignored).
    ///   FactionWarsExporter.exe --build "D:\...\my-pack" --out "D:\...\my-pack.zip"
    ///       a faction-pack file, whatever pictures it carries (log: &lt;out&gt;.log)
    /// Exit code 0 = done, 1 = a problem (the log says which), 2 = failed.
    /// </summary>
    [STAThread]
    private static int Main(string[] args)
    {
        var opt = new Dictionary<string, string>();
        for (int i = 0; i + 1 < args.Length; i++)
            if (args[i].StartsWith("--"))
                opt[args[i]] = args[++i];
        string Get(string k) => opt.TryGetValue(k, out var v) ? v : "";

        if (opt.ContainsKey("--build") && opt.ContainsKey("--out"))
            return Build(Get("--build"), Get("--out"));
        if (opt.ContainsKey("--pack"))
            return Log(Path.Combine(Get("--pack"), "original", "import.log"),
                "--pack is gone: the game reads art sets now. For a checkout, use --folder <repo>\\art\\swr-original.", 1);
        if (opt.ContainsKey("--gamedir") && opt.ContainsKey("--folder"))
            return Export(Get("--gamedir"), Importer.BundledRows, () => new FolderSink(Get("--folder")),
                Path.Combine(Get("--folder"), "export.log"));
        if (opt.ContainsKey("--gamedir") && opt.ContainsKey("--out"))
            return Export(Get("--gamedir"), Importer.BundledRows, () => new ZipSink(Get("--out")), Get("--out") + ".log");

        ApplicationConfiguration.Initialize();
        Application.Run(new MainForm());
        return 0;
    }

    private static int Export(string gameDir, string rowsDir, Func<ArtSink> sinkFor, string logPath)
    {
        var problem = Importer.Problem(gameDir, rowsDir);
        if (problem != null)
            return Log(logPath, problem, 1);
        try
        {
            using var sink = sinkFor();
            var result = Exporter.ExportArtSet(gameDir, rowsDir, sink, _ => { });
            File.WriteAllLines(logPath, result.Log.Concat(result.Missing.Select(m => "  - " + m)).Concat(new[] { $"{sink.Hashes.Count} files in the art set.", "", "Done." }));
            return 0;
        }
        catch (Exception ex)
        {
            return Log(logPath, "FAILED: " + ex, 2);
        }
    }

    private static int Build(string folder, string outZip)
    {
        var logPath = outZip + ".log";
        var lines = new List<string>();
        try
        {
            var result = PackBuilder.Build(folder, outZip, lines.Add);
            lines.Add(result.Message);
            if (result.Ok)
                lines.AddRange(new[] { "", "Done." });
            return Log(logPath, string.Join("\n", lines), result.Ok ? 0 : 1);
        }
        catch (Exception ex)
        {
            lines.Add("FAILED: " + ex);
            return Log(logPath, string.Join("\n", lines), 2);
        }
    }

    private static int Log(string path, string text, int code)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        File.WriteAllText(path, text + "\n");
        return code;
    }
}
