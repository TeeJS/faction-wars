namespace FactionWarsExporter;

/// <summary>
/// THE ORIGINAL'S SCORE IN THE ART SET (docs/music-plan.md; TeeJ, 2026-09-26:
/// "yes to including the music with the art"). MDATA\MDATA.300-315 are plain
/// WAV files - mono, 11,025 Hz, 16-bit, about 18 minutes - which the game could
/// not keep in the browser's memory as they are (24 MB), so they go into the
/// art set as Ogg Vorbis, music/&lt;nnn&gt;.ogg, encoded with the libvorbis the
/// movies already use (Movies.cs, fwxiph.dll). Which track plays when is the
/// pack's to say (pack.json `music`).
/// </summary>
internal static class Music
{
    public static readonly int[] Tracks = Enumerable.Range(300, 16).ToArray();
    /// <summary>Vorbis quality, -0.1 to 1.0 (the originals are 11 kHz mono).</summary>
    public const float Quality = 0.3f;

    /// <summary>Writes every track there is; the ones that cannot be read go to
    /// `missing`. Returns how many were written.</summary>
    public static int Export(string gameDir, ArtSink sink, List<string> missing, Action<string> say)
    {
        var dir = Path.Combine(gameDir, "MDATA");
        if (!Directory.Exists(dir))
        {
            missing.Add("MDATA folder not found - no music (a CD install may have left it on the CD)");
            return 0;
        }
        var problem = Xiph.Problem();
        if (problem != null)
        {
            missing.Add("music: " + problem);
            return 0;
        }
        int written = 0;
        long bytes = 0;
        foreach (var n in Tracks)
        {
            var path = Path.Combine(dir, "MDATA." + n);
            if (!File.Exists(path))
            {
                missing.Add($"music/{n}: MDATA.{n} not found");
                continue;
            }
            try
            {
                var (samples, channels, rate) = ReadWav(File.ReadAllBytes(path));
                var ogg = OggTheora.EncodeAudio(samples, channels, rate, Quality);
                sink.Write($"music/{n}.ogg", ogg);
                bytes += ogg.Length;
                written++;
            }
            catch (InvalidDataException ex)
            {
                missing.Add($"music/{n}: {ex.Message}");
            }
        }
        say($"Music: {written} tracks, {bytes / 1048576.0:0.0} MB.");
        return written;
    }

    /// <summary>A RIFF WAVE file's 16-bit PCM samples (interleaved), channels and rate.</summary>
    public static (short[] Samples, int Channels, int Rate) ReadWav(byte[] b)
    {
        if (b.Length < 12 || System.Text.Encoding.ASCII.GetString(b, 0, 4) != "RIFF" || System.Text.Encoding.ASCII.GetString(b, 8, 4) != "WAVE")
            throw new InvalidDataException("not a WAV file");
        int channels = 0, rate = 0, bits = 0, format = 0;
        int at = 12;
        while (at + 8 <= b.Length)
        {
            var id = System.Text.Encoding.ASCII.GetString(b, at, 4);
            int size = BitConverter.ToInt32(b, at + 4);
            int body = at + 8;
            if (size < 0 || body + size > b.Length)
                size = b.Length - body;   // a short last chunk: take what is there
            if (id == "fmt ")
            {
                format = BitConverter.ToUInt16(b, body);
                channels = BitConverter.ToUInt16(b, body + 2);
                rate = BitConverter.ToInt32(b, body + 4);
                bits = BitConverter.ToUInt16(b, body + 14);
            }
            else if (id == "data")
            {
                if (format != 1 || bits != 16 || channels < 1)
                    throw new InvalidDataException($"not 16-bit PCM (format {format}, {bits}-bit, {channels} channel(s))");
                var samples = new short[size / 2 / channels * channels];
                Buffer.BlockCopy(b, body, samples, 0, samples.Length * 2);
                return (samples, channels, rate);
            }
            at = body + size + (size & 1);
        }
        throw new InvalidDataException("no sound data in the WAV file");
    }
}
