using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;

namespace FactionWarsExporter;

/// <summary>
/// THE MOVIES FILE (docs/cutscenes-plan.md, phase 2): the original's 15
/// movies (MDATA\MDATA.000-202, Smacker) converted for Godot, which plays only
/// Ogg Theora, into swr-original.movies.zip - a second, optional file beside
/// the art set (manifest kind "movies"), so 50 MB of movies never ride along
/// with the pictures. Decisions (TeeJ, 2026-09-26, "Yes to all"): converted in
/// process (Smacker.cs decodes; libtheora and libvorbis encode, through
/// fwxiph.dll - no program is run), Theora quality 5 of 10 (31 of 63).
///
/// fwxiph.dll is built from Xiph's own sources (native\build-xiph.ps1), signed
/// with the exe and carried inside it. It is written once to the player's
/// %LOCALAPPDATA%\FactionWarsExporter\&lt;its SHA-256&gt;\ (never Temp) and
/// loaded from there only after its hash is checked again.
/// </summary>
public static class Movies
{
    public const string Kind = "movies";
    public const string Title = "Star Wars: Rebellion - original movies";
    /// <summary>MDATA.300-315 are the music, not movies.</summary>
    public static readonly string[] Names = { "000", "001", "003", "004", "005", "101", "102", "103", "104", "105", "106", "107", "108", "201", "202" };
    /// <summary>Theora 0-63: "q5" on FFmpeg's 0-10 scale (x 6.3), the plan's measured 52 MB.</summary>
    public const int TheoraQuality = 31;
    /// <summary>Vorbis -0.1-1.0 (the originals are 11 kHz).</summary>
    public const float VorbisQuality = 0.3f;

    public static string DefaultFile =>
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "Faction Wars", Exporter.ArtSetId + ".movies.zip");

    /// <summary>Where the movies are, or null: the install's MDATA folder.</summary>
    public static string? Folder(string gameDir)
    {
        var dir = Path.Combine(gameDir, "MDATA");
        return Directory.Exists(dir) && File.Exists(Path.Combine(dir, "MDATA.000")) ? dir : null;
    }

    public static string? Problem(string gameDir)
    {
        if (string.IsNullOrWhiteSpace(gameDir) || !Directory.Exists(gameDir))
            return "Pick the folder Star Wars: Rebellion is installed in.";
        if (Folder(gameDir) == null)
            return $"No movies in {gameDir}: its MDATA folder (MDATA.000 and on) is missing. A CD install may have left them on the CD.";
        return Xiph.Problem();
    }

    /// <summary>Converts every movie into the sink and writes its manifest.</summary>
    public static void Export(string gameDir, ArtSink sink, Action<string> report)
    {
        var dir = Folder(gameDir)!;
        var started = DateTime.UtcNow;
        report($"Converting the movies with libtheora and libvorbis ({Xiph.Versions()}).");
        foreach (var name in Names)
        {
            var path = Path.Combine(dir, "MDATA." + name);
            if (!File.Exists(path))
            {
                report($"  MDATA.{name}: not found, skipped.");
                continue;
            }
            var t0 = DateTime.UtcNow;
            var movie = SmackerFile.Open(path);
            var ogv = OggTheora.Encode(movie, TheoraQuality, VorbisQuality, n =>
            {
                if (n % 300 == 0 && n > 0)
                    report($"  MDATA.{name}: frame {n} of {movie.FrameCount}...");
            });
            sink.Write($"movies/{name}.ogv", ogv);
            report($"  MDATA.{name}: {movie.FrameCount} frames, {movie.FrameCount / movie.Fps:0.0} s -> {ogv.Length / 1048576.0:0.00} MB ({(DateTime.UtcNow - t0).TotalSeconds:0} s)");
        }
        sink.Finish(Manifest.New(Kind, Exporter.ArtSetId, Title));
        report($"{sink.Hashes.Count} movies in {(DateTime.UtcNow - started).TotalMinutes:0.0} minutes.");
    }
}

/// <summary>One movie to Ogg: Theora video (BT.601, 4:2:0) and Vorbis audio,
/// pages interleaved by time, as libtheora's own encoder example writes them.</summary>
internal static class OggTheora
{
    private sealed record Page(byte[] Bytes, double Time, bool Audio);

    public static byte[] Encode(SmackerFile movie, int quality, float vorbisQuality, Action<int> progress)
    {
        using var n = new NativeBlocks();
        int w = movie.Width, h = movie.Height;
        int fw = (w + 15) & ~15, fh = (h + 15) & ~15;
        var audio = movie.Audio[0];
        bool hasAudio = audio.Present && audio.Bits == 16;

        // ---- Theora ----
        IntPtr ti = n.Alloc(256);
        Xiph.th_info_init(ti);
        Marshal.WriteInt32(ti, 4, fw);
        Marshal.WriteInt32(ti, 8, fh);
        Marshal.WriteInt32(ti, 12, w);
        Marshal.WriteInt32(ti, 16, h);
        Marshal.WriteInt32(ti, 20, 0);
        Marshal.WriteInt32(ti, 24, 0);
        var (num, den) = Rate(movie.Fps);
        Marshal.WriteInt32(ti, 28, num);
        Marshal.WriteInt32(ti, 32, den);
        Marshal.WriteInt32(ti, 36, 1);
        Marshal.WriteInt32(ti, 40, 1);
        Marshal.WriteInt32(ti, 44, 0);     // TH_CS_UNSPECIFIED
        Marshal.WriteInt32(ti, 48, 0);     // TH_PF_420
        Marshal.WriteInt32(ti, 52, 0);     // no bitrate: quality
        Marshal.WriteInt32(ti, 56, quality);
        IntPtr enc = Xiph.th_encode_alloc(ti);
        if (enc == IntPtr.Zero)
            throw new InvalidOperationException("libtheora refused the movie's settings.");
        try
        {
            IntPtr tc = n.Alloc(256);
            Xiph.th_comment_init(tc);
            IntPtr vs = n.Alloc(4096), vpage = n.Alloc(64), op = n.Alloc(256);
            Xiph.ogg_stream_init(vs, 1);

            // ---- Vorbis ----
            IntPtr vi = n.Alloc(256), vc = n.Alloc(256), vd = n.Alloc(8192), vb = n.Alloc(8192);
            IntPtr astream = n.Alloc(4096), apage = n.Alloc(64);
            IntPtr op2 = n.Alloc(256), op3 = n.Alloc(256);
            if (hasAudio)
            {
                Xiph.vorbis_info_init(vi);
                if (Xiph.vorbis_encode_init_vbr(vi, audio.Channels, audio.Rate, vorbisQuality) != 0)
                    throw new InvalidOperationException($"libvorbis refused {audio.Rate} Hz x{audio.Channels}.");
                Xiph.vorbis_comment_init(vc);
                Xiph.vorbis_analysis_init(vd, vi);
                Xiph.vorbis_block_init(vd, vb);
                Xiph.ogg_stream_init(astream, 2);
            }
            try
            {
                var head = new MemoryStream();
                // The first page of each stream alone, Theora's first (Ogg's rule
                // for Theora), then the rest of the headers.
                if (Xiph.th_encode_flushheader(enc, tc, op) <= 0)
                    throw new InvalidOperationException("libtheora wrote no header.");
                Xiph.ogg_stream_packetin(vs, op);
                while (Xiph.ogg_stream_flush(vs, vpage) != 0)
                    head.Write(PageBytes(vpage));
                if (hasAudio)
                {
                    Xiph.vorbis_analysis_headerout(vd, vc, op, op2, op3);
                    Xiph.ogg_stream_packetin(astream, op);
                    while (Xiph.ogg_stream_flush(astream, apage) != 0)
                        head.Write(PageBytes(apage));
                    Xiph.ogg_stream_packetin(astream, op2);
                    Xiph.ogg_stream_packetin(astream, op3);
                }
                while (Xiph.th_encode_flushheader(enc, tc, op) > 0)
                    Xiph.ogg_stream_packetin(vs, op);
                while (Xiph.ogg_stream_flush(vs, vpage) != 0)
                    head.Write(PageBytes(vpage));
                if (hasAudio)
                    while (Xiph.ogg_stream_flush(astream, apage) != 0)
                        head.Write(PageBytes(apage));

                var pages = new List<Page>();
                // The planes: the picture at the top left, black below it.
                int cw = fw / 2, ch = fh / 2;
                IntPtr yp = n.Alloc(fw * fh), up = n.Alloc(cw * ch), vp = n.Alloc(cw * ch);
                var y = new byte[fw * fh];
                var u = new byte[cw * ch];
                var v = new byte[cw * ch];
                Array.Fill(y, (byte)16);
                Array.Fill(u, (byte)128);
                Array.Fill(v, (byte)128);
                IntPtr buf = n.Alloc(256);
                WritePlane(buf, 0, fw, fh, fw, yp);
                WritePlane(buf, 24, cw, ch, cw, up);
                WritePlane(buf, 48, cw, ch, cw, vp);
                var yl = new byte[256];
                var cbl = new int[256];
                var crl = new int[256];
                int last = movie.FrameCount - 1;
                foreach (var f in movie.Frames())
                {
                    ToYCbCr(f, w, h, fw, cw, y, u, v, yl, cbl, crl);
                    Marshal.Copy(y, 0, yp, y.Length);
                    Marshal.Copy(u, 0, up, u.Length);
                    Marshal.Copy(v, 0, vp, v.Length);
                    if (Xiph.th_encode_ycbcr_in(enc, buf) != 0)
                        throw new InvalidOperationException($"libtheora refused frame {f.Index}.");
                    while (Xiph.th_encode_packetout(enc, f.Index == last ? 1 : 0, op) > 0)
                    {
                        Xiph.ogg_stream_packetin(vs, op);
                        while (Xiph.ogg_stream_pageout(vs, vpage) != 0)
                            pages.Add(new Page(PageBytes(vpage), Xiph.th_granule_time(enc, Xiph.ogg_page_granulepos(vpage)), false));
                    }
                    if (hasAudio && f.Samples.Length > 0)
                        Feed(vd, vb, astream, apage, op, f.Samples, audio.Channels, pages);
                    progress(f.Index + 1);
                }
                while (Xiph.ogg_stream_flush(vs, vpage) != 0)
                    pages.Add(new Page(PageBytes(vpage), Xiph.th_granule_time(enc, Xiph.ogg_page_granulepos(vpage)), false));
                if (hasAudio)
                {
                    Xiph.vorbis_analysis_wrote(vd, 0);   // the end
                    Drain(vd, vb, astream, apage, op, pages);
                    while (Xiph.ogg_stream_flush(astream, apage) != 0)
                        pages.Add(new Page(PageBytes(apage), Xiph.vorbis_granule_time(vd, Xiph.ogg_page_granulepos(apage)), true));
                }

                // Interleaved by time, each stream's own order kept. A page that
                // ends no packet has no time of its own (-1): it takes its
                // stream's last.
                var video = Timed(pages.Where(p => !p.Audio));
                var sound = Timed(pages.Where(p => p.Audio));
                int a = 0, b = 0;
                while (a < video.Count || b < sound.Count)
                {
                    bool takeAudio = b < sound.Count && (a >= video.Count || sound[b].Time <= video[a].Time);
                    head.Write(takeAudio ? sound[b++].Bytes : video[a++].Bytes);
                }
                return head.ToArray();
            }
            finally
            {
                Xiph.ogg_stream_clear(vs);
                Xiph.th_comment_clear(tc);
                if (hasAudio)
                {
                    Xiph.ogg_stream_clear(astream);
                    Xiph.vorbis_block_clear(vb);
                    Xiph.vorbis_dsp_clear(vd);
                    Xiph.vorbis_comment_clear(vc);
                    Xiph.vorbis_info_clear(vi);
                }
            }
        }
        finally
        {
            Xiph.th_encode_free(enc);
            Xiph.th_info_clear(ti);
        }
    }

    private static List<Page> Timed(IEnumerable<Page> stream)
    {
        var list = new List<Page>();
        double last = 0;
        foreach (var p in stream)
        {
            last = p.Time >= 0 ? p.Time : last;
            list.Add(p with { Time = last });
        }
        return list;
    }

    /// <summary>The frame rate as a fraction: Smacker's -6666 is 100000/6666.</summary>
    private static (int, int) Rate(double fps)
    {
        for (int den = 1; den <= 10000; den++)
        {
            double numd = fps * den;
            if (Math.Abs(numd - Math.Round(numd)) < 1e-6)
                return ((int)Math.Round(numd), den);
        }
        return ((int)Math.Round(fps * 1000), 1000);
    }

    private static void WritePlane(IntPtr buf, int at, int width, int height, int stride, IntPtr data)
    {
        Marshal.WriteInt32(buf, at, width);
        Marshal.WriteInt32(buf, at + 4, height);
        Marshal.WriteInt32(buf, at + 8, stride);
        Marshal.WriteIntPtr(buf, at + 16, data);
    }

    /// <summary>Indexed pixels to BT.601 studio-range Y'CbCr, chroma averaged over 2x2.</summary>
    private static void ToYCbCr(SmackerFile.Frame f, int w, int h, int fw, int cw, byte[] y, byte[] u, byte[] v, byte[] yl, int[] cbl, int[] crl)
    {
        var pal = f.Palette;
        for (int i = 0; i < 256; i++)
        {
            double r = pal[i * 3], g = pal[i * 3 + 1], b = pal[i * 3 + 2];
            yl[i] = (byte)Math.Clamp((int)Math.Round(16 + (65.481 * r + 128.553 * g + 24.966 * b) / 255.0), 0, 255);
            // Scaled by 4, so a 2x2 block's sum is the average's x16.
            cbl[i] = (int)Math.Round(4 * (-37.797 * r - 74.203 * g + 112.0 * b) / 255.0 * 4);
            crl[i] = (int)Math.Round(4 * (112.0 * r - 93.786 * g - 18.214 * b) / 255.0 * 4);
        }
        var px = f.Pixels;
        for (int row = 0; row < h; row++)
        {
            int src = row * w, dst = row * fw;
            for (int x = 0; x < w; x++)
                y[dst + x] = yl[px[src + x]];
        }
        int ch2 = (h + 1) / 2, cw2 = (w + 1) / 2;
        for (int cy = 0; cy < ch2; cy++)
        {
            int r0 = cy * 2 * w, r1 = Math.Min(cy * 2 + 1, h - 1) * w;
            for (int cx = 0; cx < cw2; cx++)
            {
                int x0 = cx * 2, x1 = Math.Min(cx * 2 + 1, w - 1);
                int p0 = px[r0 + x0], p1 = px[r0 + x1], p2 = px[r1 + x0], p3 = px[r1 + x1];
                int cb = cbl[p0] + cbl[p1] + cbl[p2] + cbl[p3];
                int cr = crl[p0] + crl[p1] + crl[p2] + crl[p3];
                u[cy * cw + cx] = (byte)Math.Clamp(128 + (int)Math.Round(cb / 64.0), 0, 255);
                v[cy * cw + cx] = (byte)Math.Clamp(128 + (int)Math.Round(cr / 64.0), 0, 255);
            }
        }
    }

    private static void Feed(IntPtr vd, IntPtr vb, IntPtr os, IntPtr og, IntPtr op, short[] samples, int channels, List<Page> pages)
    {
        int n = samples.Length / channels;
        IntPtr buffers = Xiph.vorbis_analysis_buffer(vd, n);
        var chan = new float[n];
        for (int c = 0; c < channels; c++)
        {
            for (int i = 0; i < n; i++)
                chan[i] = samples[i * channels + c] / 32768f;
            Marshal.Copy(chan, 0, Marshal.ReadIntPtr(buffers, c * IntPtr.Size), n);
        }
        Xiph.vorbis_analysis_wrote(vd, n);
        Drain(vd, vb, os, og, op, pages);
    }

    private static void Drain(IntPtr vd, IntPtr vb, IntPtr os, IntPtr og, IntPtr op, List<Page> pages)
    {
        while (Xiph.vorbis_analysis_blockout(vd, vb) == 1)
        {
            Xiph.vorbis_analysis(vb, IntPtr.Zero);
            Xiph.vorbis_bitrate_addblock(vb);
            while (Xiph.vorbis_bitrate_flushpacket(vd, op) != 0)
            {
                Xiph.ogg_stream_packetin(os, op);
                while (Xiph.ogg_stream_pageout(os, og) != 0)
                    pages.Add(new Page(PageBytes(og), Xiph.vorbis_granule_time(vd, Xiph.ogg_page_granulepos(og)), true));
            }
        }
    }

    /// <summary>An ogg_page's header and body: pointers at 0 and 16, their
    /// lengths (C long, 32 bits on Windows) at 8 and 24.</summary>
    private static byte[] PageBytes(IntPtr page)
    {
        IntPtr hp = Marshal.ReadIntPtr(page, 0);
        int hl = Marshal.ReadInt32(page, 8);
        IntPtr bp = Marshal.ReadIntPtr(page, 16);
        int bl = Marshal.ReadInt32(page, 24);
        var bytes = new byte[hl + bl];
        Marshal.Copy(hp, bytes, 0, hl);
        Marshal.Copy(bp, bytes, hl, bl);
        return bytes;
    }

    /// <summary>Zeroed native blocks for libogg's, libtheora's and libvorbis's
    /// state (sized generously; only the libraries read them), freed together.</summary>
    private sealed class NativeBlocks : IDisposable
    {
        private readonly List<IntPtr> _blocks = new();

        public IntPtr Alloc(int size)
        {
            IntPtr p = Marshal.AllocHGlobal(size);
            Marshal.Copy(new byte[size], 0, p, size);
            _blocks.Add(p);
            return p;
        }

        public void Dispose()
        {
            foreach (var p in _blocks)
                Marshal.FreeHGlobal(p);
            _blocks.Clear();
        }
    }
}

/// <summary>fwxiph.dll: libogg, libtheora and libvorbis (native\build-xiph.ps1).</summary>
internal static class Xiph
{
    private const string Lib = "fwxiph";
    private const string Resource = "native/fwxiph.dll";
    private static string? _path;
    private static string? _problem;

    static Xiph()
    {
        NativeLibrary.SetDllImportResolver(typeof(Xiph).Assembly, (name, _, _) =>
            name == Lib && Problem() == null ? NativeLibrary.Load(_path!) : IntPtr.Zero);
    }

    /// <summary>Why the converter cannot run, or null (it is then ready).</summary>
    public static string? Problem()
    {
        if (_path != null || _problem != null)
            return _problem;
        using var s = Assembly.GetExecutingAssembly().GetManifestResourceStream(Resource);
        if (s == null)
            return _problem = "This exporter was built without its movie converter (fwxiph.dll): build it with build.ps1.";
        var bytes = new byte[s.Length];
        s.ReadExactly(bytes);
        var hash = ArtSink.Hex(SHA256.HashData(bytes));
        var dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "FactionWarsExporter", hash[..16]);
        var path = Path.Combine(dir, "fwxiph.dll");
        if (!File.Exists(path) || ArtSink.Hex(SHA256.HashData(File.ReadAllBytes(path))) != hash)
        {
            Directory.CreateDirectory(dir);
            File.WriteAllBytes(path + ".partial", bytes);
            File.Move(path + ".partial", path, overwrite: true);
        }
        // Checked again as it is about to be loaded.
        if (ArtSink.Hex(SHA256.HashData(File.ReadAllBytes(path))) != hash)
            return _problem = $"The movie converter at {path} does not match the one in this exporter.";
        _path = path;
        return null;
    }

    public static string Versions() =>
        $"{Marshal.PtrToStringAnsi(th_version_string())}; {Marshal.PtrToStringAnsi(vorbis_version_string())}";

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int ogg_stream_init(IntPtr os, int serialno);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int ogg_stream_clear(IntPtr os);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int ogg_stream_packetin(IntPtr os, IntPtr op);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int ogg_stream_pageout(IntPtr os, IntPtr og);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int ogg_stream_flush(IntPtr os, IntPtr og);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern long ogg_page_granulepos(IntPtr og);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr th_version_string();
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern void th_info_init(IntPtr info);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern void th_info_clear(IntPtr info);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern void th_comment_init(IntPtr tc);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern void th_comment_clear(IntPtr tc);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr th_encode_alloc(IntPtr info);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int th_encode_flushheader(IntPtr enc, IntPtr tc, IntPtr op);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int th_encode_ycbcr_in(IntPtr enc, IntPtr ycbcr);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int th_encode_packetout(IntPtr enc, int last, IntPtr op);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern void th_encode_free(IntPtr enc);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern double th_granule_time(IntPtr enc, long granulepos);

    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr vorbis_version_string();
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern void vorbis_info_init(IntPtr vi);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern void vorbis_info_clear(IntPtr vi);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern void vorbis_comment_init(IntPtr vc);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern void vorbis_comment_clear(IntPtr vc);
    // C long is 32 bits on Windows.
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int vorbis_encode_init_vbr(IntPtr vi, int channels, int rate, float quality);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int vorbis_analysis_init(IntPtr vd, IntPtr vi);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int vorbis_block_init(IntPtr vd, IntPtr vb);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int vorbis_block_clear(IntPtr vb);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern void vorbis_dsp_clear(IntPtr vd);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int vorbis_analysis_headerout(IntPtr vd, IntPtr vc, IntPtr op, IntPtr opComm, IntPtr opCode);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern IntPtr vorbis_analysis_buffer(IntPtr vd, int vals);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int vorbis_analysis_wrote(IntPtr vd, int vals);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int vorbis_analysis_blockout(IntPtr vd, IntPtr vb);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int vorbis_analysis(IntPtr vb, IntPtr op);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int vorbis_bitrate_addblock(IntPtr vb);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern int vorbis_bitrate_flushpacket(IntPtr vd, IntPtr op);
    [DllImport(Lib, CallingConvention = CallingConvention.Cdecl)] public static extern double vorbis_granule_time(IntPtr vd, long granulepos);
}
