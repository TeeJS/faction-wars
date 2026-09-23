namespace RebellionArtImporter;

internal static class Program
{
    /// <summary>
    /// Double-click: the window. From a script:
    ///   RebellionArtImporter.exe --gamedir "C:\...\Star Wars - Rebellion" --pack "D:\...\packs\star-wars-rebellion"
    /// runs without a window and writes original\import.log; exit code 0 = done, 1 = a problem, 2 = failed.
    /// </summary>
    [STAThread]
    private static int Main(string[] args)
    {
        string? gameDir = null, packDir = null;
        for (int i = 0; i + 1 < args.Length; i++)
        {
            if (args[i] == "--gamedir") gameDir = args[++i];
            else if (args[i] == "--pack") packDir = args[++i];
        }
        if (gameDir != null && packDir != null)
            return Headless(gameDir, packDir);

        ApplicationConfiguration.Initialize();
        Application.Run(new MainForm());
        return 0;
    }

    private static int Headless(string gameDir, string packDir)
    {
        var problem = Importer.Problem(gameDir, packDir);
        var logPath = Path.Combine(packDir, "original", "import.log");
        if (problem != null)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(logPath)!);
            File.WriteAllText(logPath, problem + "\n");
            return 1;
        }
        try
        {
            var result = new Importer(gameDir, packDir, _ => { }).Run();
            File.WriteAllLines(logPath, result.Log.Concat(result.Missing.Select(m => "  - " + m)).Concat(new[] { "", "Done." }));
            return 0;
        }
        catch (Exception ex)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(logPath)!);
            File.WriteAllText(logPath, "FAILED: " + ex + "\n");
            return 2;
        }
    }
}
