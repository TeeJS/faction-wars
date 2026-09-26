using System.Security.Cryptography;

namespace FactionWarsExporter;

/// <summary>
/// DEV ONLY. Checks Smacker.cs against FFmpeg, one movie at a time:
///
///   ffmpeg -v error -i "...\MDATA\MDATA.101" -fps_mode passthrough -pix_fmt rgb24 -c:a pcm_s16le -f framemd5 101.md5
///   dotnet run --project tools\SmackerCheck -c Release -- "...\MDATA\MDATA.101" 101.md5
///
/// Every video frame (as RGB, through its palette) and every frame's audio
/// (16-bit little-endian) is hashed and compared with FFmpeg's list, in order.
/// Exit code 0 = identical.
/// </summary>
internal static class Program
{
    private static int Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("usage: SmackerCheck <movie> <ffmpeg framemd5 file>");
            return 2;
        }
        var movie = SmackerFile.Open(args[0]);
        var (video, audio) = ReadFrameMd5(args[1]);
        Console.WriteLine($"{Path.GetFileName(args[0])}: {movie.Width}x{movie.Height}, {movie.FrameCount} frames, {movie.Fps:0.##} fps; " +
            $"audio {movie.Audio[0].Rate} Hz x{movie.Audio[0].Channels} {movie.Audio[0].Bits}-bit; FFmpeg: {video.Count} frames, {audio.Count} audio packets");
        int vSame = 0, vDiff = 0, aSame = 0, aDiff = 0, a = 0;
        int firstV = -1, firstA = -1;
        long samples = 0;
        var rgb = new byte[movie.Width * movie.Height * 3];
        foreach (var f in movie.Frames())
        {
            for (int i = 0; i < f.Pixels.Length; i++)
            {
                int c = f.Pixels[i] * 3;
                rgb[i * 3] = f.Palette[c];
                rgb[i * 3 + 1] = f.Palette[c + 1];
                rgb[i * 3 + 2] = f.Palette[c + 2];
            }
            string h = Convert.ToHexString(MD5.HashData(rgb)).ToLowerInvariant();
            if (f.Index < video.Count && video[f.Index] == h)
                vSame++;
            else
            {
                vDiff++;
                if (firstV < 0) firstV = f.Index;
            }
            if (f.Samples.Length > 0)
            {
                samples += f.Samples.Length;
                var bytes = new byte[f.Samples.Length * 2];
                Buffer.BlockCopy(f.Samples, 0, bytes, 0, bytes.Length);
                string ah = Convert.ToHexString(MD5.HashData(bytes)).ToLowerInvariant();
                if (a < audio.Count && audio[a] == ah)
                    aSame++;
                else
                {
                    aDiff++;
                    if (firstA < 0) firstA = a;
                }
                a++;
            }
        }
        Console.WriteLine($"  video: {vSame} identical, {vDiff} different{(firstV >= 0 ? $" (first: frame {firstV})" : "")}");
        Console.WriteLine($"  audio: {aSame} identical, {aDiff} different{(firstA >= 0 ? $" (first: packet {firstA})" : "")}; {samples} samples, {a} packets");
        bool ok = vDiff == 0 && aDiff == 0 && vSame == video.Count && aSame == audio.Count;
        Console.WriteLine(ok ? "  IDENTICAL" : "  MISMATCH");
        return ok ? 0 : 1;
    }

    /// <summary>FFmpeg's framemd5: "stream, dts, pts, duration, size, hash" per packet.</summary>
    private static (List<string> Video, List<string> Audio) ReadFrameMd5(string path)
    {
        var v = new List<string>();
        var a = new List<string>();
        foreach (var line in File.ReadLines(path))
        {
            if (line.StartsWith('#') || string.IsNullOrWhiteSpace(line))
                continue;
            var parts = line.Split(',');
            if (parts.Length < 6)
                continue;
            (parts[0].Trim() == "0" ? v : a).Add(parts[5].Trim());
        }
        return (v, a);
    }
}
