using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace FactionWarsExporter;

/// <summary>
/// Where the exported files go. Every file is named by its path relative to
/// the art set's root ("portraits/characters/luke.png") and hashed as it is
/// written, so manifest.json can list every file with its SHA-256: the game
/// checks the hashes on import, and the pack builder refuses a faction pack
/// that carries any of them (docs/original-art-plan.md, the leak guard).
/// </summary>
public abstract class ArtSink : IDisposable
{
    /// <summary>relative path -> lower-case hex SHA-256, sorted by path.</summary>
    public SortedDictionary<string, string> Hashes { get; } = new(StringComparer.Ordinal);

    public void Write(string rel, byte[] data)
    {
        rel = rel.Replace('\\', '/');
        Hashes[rel] = Hex(SHA256.HashData(data));
        Store(rel, data);
    }

    public void WriteText(string rel, string text) => Write(rel, new UTF8Encoding(false).GetBytes(text));

    /// <summary>Writes manifest.json (not itself listed) and closes the output.</summary>
    public void Finish(JsonObject manifest)
    {
        var files = new JsonObject();
        foreach (var (rel, hash) in Hashes)
            files[rel] = hash;
        manifest["files"] = files;
        Store(Manifest.FileName, new UTF8Encoding(false).GetBytes(
            manifest.ToJsonString(new JsonSerializerOptions { WriteIndented = true }) + "\n"));
        Close();
    }

    protected abstract void Store(string rel, byte[] data);
    protected virtual void Close() { }
    public virtual void Dispose() => Close();

    public static string Hex(byte[] hash) => Convert.ToHexString(hash).ToLowerInvariant();
}

/// <summary>Files under a folder (an author's working copy, or TeeJ's checkout).</summary>
public sealed class FolderSink(string root) : ArtSink
{
    protected override void Store(string rel, byte[] data)
    {
        var path = Path.Combine(root, rel.Replace('/', Path.DirectorySeparatorChar));
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllBytes(path, data);
    }
}

/// <summary>One .zip - the file a player imports and keeps as a backup. Written
/// to "&lt;name&gt;.partial" and renamed at the end, so a failed export never
/// leaves a half file under the real name.</summary>
public sealed class ZipSink : ArtSink
{
    private readonly string _path;
    private readonly string _partial;
    private FileStream? _stream;
    private ZipArchive? _zip;
    private bool _finished;

    public ZipSink(string path)
    {
        _path = path;
        _partial = path + ".partial";
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        _stream = new FileStream(_partial, FileMode.Create, FileAccess.ReadWrite);
        _zip = new ZipArchive(_stream, ZipArchiveMode.Create);
    }

    protected override void Store(string rel, byte[] data)
    {
        // PNGs are already compressed; storing them keeps the export fast.
        var level = rel.EndsWith(".png", StringComparison.OrdinalIgnoreCase) ? CompressionLevel.NoCompression : CompressionLevel.Optimal;
        var entry = _zip!.CreateEntry(rel, level);
        using var s = entry.Open();
        s.Write(data);
        if (rel == Manifest.FileName)
            _finished = true;
    }

    protected override void Close()
    {
        if (_zip == null)
            return;
        _zip.Dispose();
        _stream!.Dispose();
        _zip = null;
        if (_finished)
            File.Move(_partial, _path, overwrite: true);
        else
            File.Delete(_partial);
    }
}

/// <summary>Hashes only - the art set in memory, for the pack builder's leak guard.</summary>
public sealed class HashSink : ArtSink
{
    protected override void Store(string rel, byte[] data) { }
}

/// <summary>manifest.json, at the root of every art-set and faction-pack file.</summary>
public static class Manifest
{
    public const string FileName = "manifest.json";
    public const int Format = 1;
    public const string KindArtSet = "art_set";
    public const string KindFactionPack = "faction_pack";

    public static JsonObject New(string kind, string id, string title) => new()
    {
        ["format"] = Format,
        ["kind"] = kind,
        ["id"] = id,
        ["title"] = title,
        ["exporter"] = typeof(Manifest).Assembly.GetName().Version?.ToString(3) ?? "",
        ["created_utc"] = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"),
    };

    /// <summary>The hashes an art-set file or folder lists, or null when the
    /// path is not an art set.</summary>
    public static HashSet<string>? ArtSetHashes(string path)
    {
        string? json = null;
        if (File.Exists(path) && path.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
        {
            using var zip = ZipFile.OpenRead(path);
            var entry = zip.GetEntry(FileName);
            if (entry != null)
            {
                using var r = new StreamReader(entry.Open());
                json = r.ReadToEnd();
            }
        }
        else if (Directory.Exists(path) && File.Exists(Path.Combine(path, FileName)))
            json = File.ReadAllText(Path.Combine(path, FileName));
        if (json == null)
            return null;
        var doc = JsonNode.Parse(json)?.AsObject();
        if (doc?["kind"]?.GetValue<string>() != KindArtSet || doc["files"] is not JsonObject files)
            return null;
        return files.Select(f => f.Value!.GetValue<string>()).ToHashSet();
    }
}
