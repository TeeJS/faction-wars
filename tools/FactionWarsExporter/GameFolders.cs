using System.Text;
using Microsoft.Win32;

namespace FactionWarsExporter;

/// <summary>
/// Where a player's copy of Star Wars: Rebellion is likely to be. Every version
/// keeps the same layout - the DLLs in one folder with EData beside them - so
/// any of these can be the game folder (checked 2026-09-23):
///
///   GOG             ...\GOG Galaxy\Games\Star Wars - Rebellion
///   Steam           &lt;library&gt;\steamapps\common\Star Wars - Rebellion (app 441550),
///                   in any library Steam lists in steamapps\libraryfolders.vdf
///   The CD          the disc's REBELLION folder - the same files at the same sizes
///                   as the GOG copy. The 1998 setup is 16-bit and will not run on
///                   64-bit Windows, so the disc itself (or a mounted .iso, which
///                   Windows shows as a DVD drive) is where most CD owners import from
///   Old CD installs C:\Program Files\LucasArts\Star Wars Rebellion (manual p16).
///                   Those usually left EData on the disc, so a folder only counts
///                   when EData is in it
/// </summary>
public static class GameFolders
{
    private const string SteamAppId = "441550";
    private const string SteamFolderName = "Star Wars - Rebellion";

    /// <summary>The first place that holds the game, or "".</summary>
    public static string Find() => Candidates().FirstOrDefault(IsGameFolder) ?? "";

    /// <summary>ENCYTEXT.DLL with EData beside it: everything the importer needs is there.</summary>
    public static bool IsGameFolder(string dir) =>
        File.Exists(Path.Combine(dir, "ENCYTEXT.DLL")) && Directory.Exists(Path.Combine(dir, "EData"));

    /// <summary>Installed copies first, then any CD in a drive.</summary>
    public static IEnumerable<string> Candidates()
    {
        yield return @"C:\Program Files (x86)\GOG Galaxy\Games\Star Wars - Rebellion";
        yield return @"C:\GOG Games\Star Wars - Rebellion";
        foreach (var dir in SteamFolders())
            yield return dir;
        yield return @"C:\Program Files (x86)\LucasArts\Star Wars Rebellion";
        yield return @"C:\Program Files\LucasArts\Star Wars Rebellion";
        foreach (var dir in CdFolders())
            yield return dir;
    }

    /// <summary>The game's folder in each Steam library: the app manifest's installdir, else the usual name.</summary>
    private static List<string> SteamFolders()
    {
        var found = new List<string>();
        foreach (var library in SteamLibraries())
        {
            var apps = Path.Combine(library, "steamapps");
            string? installDir = null;
            try
            {
                var manifest = Path.Combine(apps, $"appmanifest_{SteamAppId}.acf");
                if (File.Exists(manifest))
                    installDir = InstallDir(File.ReadAllText(manifest));
            }
            catch (Exception) { }  // an unreadable manifest falls back to the usual name
            found.Add(Path.Combine(apps, "common", installDir ?? SteamFolderName));
        }
        return found;
    }

    /// <summary>Steam's own folder (from the registry, else the default) and every library it lists.</summary>
    private static List<string> SteamLibraries()
    {
        var steam = @"C:\Program Files (x86)\Steam";
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(@"Software\Valve\Steam");
            if (key?.GetValue("SteamPath") is string path && path.Length > 0)
                steam = path.Replace('/', '\\');
        }
        catch (Exception) { }
        var libraries = new List<string> { steam };
        try
        {
            var list = Path.Combine(steam, "steamapps", "libraryfolders.vdf");
            if (File.Exists(list))
                foreach (var library in LibraryPaths(File.ReadAllText(list)))
                    if (!libraries.Contains(library, StringComparer.OrdinalIgnoreCase))
                        libraries.Add(library);
        }
        catch (Exception) { }
        return libraries;
    }

    /// <summary>
    /// The library paths in libraryfolders.vdf. Numbered entries are either the path
    /// itself ("1" "D:\\SteamLibrary", older Steam) or a block holding one ("1" { "path" ... }).
    /// </summary>
    internal static List<string> LibraryPaths(string vdf)
    {
        var paths = new List<string>();
        if (Vdf.Parse(vdf).GetValueOrDefault("libraryfolders") is not Dictionary<string, object> folders)
            return paths;
        foreach (var (name, value) in folders)
            if (int.TryParse(name, out _)
                && (value as string ?? (value as Dictionary<string, object>)?.GetValueOrDefault("path") as string) is { Length: > 0 } path)
                paths.Add(path);
        return paths;
    }

    /// <summary>The installdir of an appmanifest_*.acf, or null.</summary>
    internal static string? InstallDir(string acf) =>
        Vdf.Parse(acf).GetValueOrDefault("AppState") is Dictionary<string, object> app
        && app.GetValueOrDefault("installdir") is string { Length: > 0 } dir ? dir : null;

    /// <summary>
    /// The REBELLION folder on each CD/DVD drive with a disc in it. Only those drives:
    /// a disconnected network drive can hang the window for a long time.
    /// </summary>
    private static List<string> CdFolders()
    {
        var found = new List<string>();
        try
        {
            foreach (var drive in DriveInfo.GetDrives())
                if (drive.DriveType == DriveType.CDRom && drive.IsReady)
                    found.Add(Path.Combine(drive.RootDirectory.FullName, "REBELLION"));
        }
        catch (Exception) { }
        return found;
    }

    /// <summary>Valve's KeyValues text: "key" "value" and "key" { ... }, keys case-insensitive.</summary>
    internal static class Vdf
    {
        public static Dictionary<string, object> Parse(string text)
        {
            int i = 0;
            return Block(text, ref i);
        }

        private static Dictionary<string, object> Block(string s, ref int i)
        {
            var block = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            while (Token(s, ref i, out var key, out var keyIsBrace) && !keyIsBrace)
            {
                if (!Token(s, ref i, out var value, out var valueIsBrace))
                    break;
                if (!valueIsBrace)
                    block[key] = value;
                else if (value == "{")
                    block[key] = Block(s, ref i);
                else
                    break;  // "key }" - malformed; keep what was read
            }
            return block;
        }

        /// <summary>The next quoted string, bare word or brace. A backslash takes the next character as-is (\\ and \").</summary>
        private static bool Token(string s, ref int i, out string token, out bool brace)
        {
            token = "";
            brace = false;
            while (i < s.Length)
            {
                char c = s[i];
                if (char.IsWhiteSpace(c))
                    i++;
                else if (c == '/' && i + 1 < s.Length && s[i + 1] == '/')
                    while (i < s.Length && s[i] != '\n') i++;
                else if (c == '{' || c == '}')
                {
                    i++;
                    token = c.ToString();
                    brace = true;
                    return true;
                }
                else if (c == '"')
                {
                    var text = new StringBuilder();
                    for (i++; i < s.Length && s[i] != '"'; i++)
                        text.Append(s[i] == '\\' && i + 1 < s.Length ? s[++i] : s[i]);
                    i++;
                    token = text.ToString();
                    return true;
                }
                else
                {
                    int start = i;
                    while (i < s.Length && !char.IsWhiteSpace(s[i]) && s[i] is not ('{' or '}' or '"')) i++;
                    token = s[start..i];
                    return true;
                }
            }
            return false;
        }
    }
}
