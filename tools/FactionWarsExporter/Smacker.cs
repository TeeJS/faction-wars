namespace FactionWarsExporter;

/// <summary>
/// The original's movies (MDATA\MDATA.000-202): Smacker, decoded in process so
/// the exporter never runs another program (docs/cutscenes-plan.md, option C).
///
/// The format is public (wiki.multimedia.cx "Smacker"); where that page and
/// FFmpeg's reading differ, this follows FFmpeg's, and tools/SmackerCheck
/// proves every frame and every sample against FFmpeg's own decode of the
/// player's files (a dev-only check, not part of the exporter):
///   - a 104-byte header, a size per frame (the low two bits are flags), a
///     type byte per frame (bit 0: a palette; bit 1+t: audio track t), four
///     Huffman trees, then the frames;
///   - a frame: its palette changes, each audio track's chunk, then the video:
///     4x4 blocks in rows, a run of one block type at a time - two colours by
///     a bit map, sixteen colours, unchanged, or one colour;
///   - the 16-bit trees keep their three most recent values on their shortest
///     codes (reset to 0 each frame);
///   - the audio: Huffman-coded differences, 16-bit stereo here, wrapping.
/// SMK4's two extra full-block modes are read too (the original's are SMK2).
/// </summary>
internal sealed class SmackerFile
{
    public int Width { get; }
    public int Height { get; }
    public int FrameCount { get; }
    /// <summary>Frames per second (MDATA: 15, from -6666 = 66.66 ms).</summary>
    public double Fps { get; }
    public bool IsSmk4 { get; }
    public AudioTrack[] Audio { get; } = new AudioTrack[7];

    public sealed record AudioTrack(int Rate, int Channels, int Bits, bool Compressed, bool Present);

    /// <summary>One decoded frame. Pixels and Palette are reused by the next frame.</summary>
    public sealed class Frame
    {
        public int Index;
        /// <summary>Width x Height palette indices, row by row.</summary>
        public byte[] Pixels = Array.Empty<byte>();
        /// <summary>256 RGB triples.</summary>
        public byte[] Palette = new byte[768];
        public bool Keyframe;
        /// <summary>Track 0's samples in this frame, interleaved by channel (none: empty).</summary>
        public short[] Samples = Array.Empty<short>();
    }

    private readonly byte[] _file;
    private readonly uint[] _sizes;
    private readonly byte[] _types;
    private readonly int _firstFrame;
    private readonly BigTree _mmap, _mclr, _full, _type;

    // 6-bit palette components to 8 (the format's own table).
    private static readonly byte[] PalMap =
    {
        0x00, 0x04, 0x08, 0x0C, 0x10, 0x14, 0x18, 0x1C, 0x20, 0x24, 0x28, 0x2C, 0x30, 0x34, 0x38, 0x3C,
        0x41, 0x45, 0x49, 0x4D, 0x51, 0x55, 0x59, 0x5D, 0x61, 0x65, 0x69, 0x6D, 0x71, 0x75, 0x79, 0x7D,
        0x82, 0x86, 0x8A, 0x8E, 0x92, 0x96, 0x9A, 0x9E, 0xA2, 0xA6, 0xAA, 0xAE, 0xB2, 0xB6, 0xBA, 0xBE,
        0xC3, 0xC7, 0xCB, 0xCF, 0xD3, 0xD7, 0xDB, 0xDF, 0xE3, 0xE7, 0xEB, 0xEF, 0xF3, 0xF7, 0xFB, 0xFF,
    };

    // A block type's run: its bits 2-7 index this.
    private static readonly int[] BlockRuns = BuildRuns();

    private static int[] BuildRuns()
    {
        var r = new int[64];
        for (int i = 0; i < 59; i++)
            r[i] = i + 1;
        r[59] = 128; r[60] = 256; r[61] = 512; r[62] = 1024; r[63] = 2048;
        return r;
    }

    public SmackerFile(byte[] file)
    {
        _file = file;
        if (file.Length < 104)
            throw new InvalidDataException("Not a Smacker movie: too short.");
        var sig = System.Text.Encoding.ASCII.GetString(file, 0, 4);
        if (sig != "SMK2" && sig != "SMK4")
            throw new InvalidDataException($"Not a Smacker movie: '{sig}'.");
        IsSmk4 = sig == "SMK4";
        Width = I32(4);
        Height = I32(8);
        FrameCount = I32(12);
        int rate = I32(16);
        Fps = rate > 0 ? 1000.0 / rate : rate < 0 ? 100000.0 / -rate : 10.0;
        int flags = I32(20);
        if ((flags & 6) != 0)
            throw new InvalidDataException("Interlaced or doubled Smacker movies are not read.");
        int treesSize = I32(52);
        for (int t = 0; t < 7; t++)
        {
            uint a = (uint)I32(72 + 4 * t);
            Audio[t] = new AudioTrack((int)(a & 0xFFFFFF), (a & (1u << 28)) != 0 ? 2 : 1, (a & (1u << 29)) != 0 ? 16 : 8,
                (a & (1u << 31)) != 0, (a & (1u << 30)) != 0);
        }
        int frames = FrameCount + ((flags & 1) != 0 ? 1 : 0);   // a ring frame follows the last
        int pos = 104;
        _sizes = new uint[frames];
        for (int i = 0; i < frames; i++, pos += 4)
            _sizes[i] = (uint)I32(pos);
        _types = new byte[frames];
        Array.Copy(file, pos, _types, 0, frames);
        pos += frames;
        var bits = new BitReader(file, pos, treesSize);
        _mmap = BigTree.Read(bits);
        _mclr = BigTree.Read(bits);
        _full = BigTree.Read(bits);
        _type = BigTree.Read(bits);
        _firstFrame = pos + treesSize;
    }

    public static SmackerFile Open(string path) => new(File.ReadAllBytes(path));

    private int I32(int at) => BitConverter.ToInt32(_file, at);

    /// <summary>Every frame in order (the ring frame, a copy of the first, is not).</summary>
    public IEnumerable<Frame> Frames()
    {
        var f = new Frame { Pixels = new byte[Width * Height] };
        var oldPal = new byte[768];
        int pos = _firstFrame;
        for (int i = 0; i < FrameCount; i++)
        {
            int size = (int)(_sizes[i] & ~3u);
            int end = pos + size;
            if (end > _file.Length)
                throw new InvalidDataException($"Frame {i} runs past the end of the file.");
            f.Index = i;
            f.Keyframe = (_sizes[i] & 1) != 0;
            byte type = _types[i];
            int at = pos;
            if ((type & 1) != 0)
            {
                int len = _file[at] * 4;
                Array.Copy(f.Palette, oldPal, 768);
                ReadPalette(at + 1, at + len, oldPal, f.Palette);
                at += len;
            }
            f.Samples = Array.Empty<short>();
            for (int t = 0; t < 7; t++)
            {
                if ((type & (2 << t)) == 0)
                    continue;
                int len = BitConverter.ToInt32(_file, at);
                if (t == 0 && Audio[0].Present)
                    f.Samples = DecodeAudio(at + 4, len - 4, Audio[0]);
                at += len;
            }
            DecodeVideo(at, end - at, f.Pixels);
            yield return f;
            pos = end;
        }
    }

    // ---- the palette ------------------------------------------------------------

    private void ReadPalette(int at, int end, byte[] old, byte[] pal)
    {
        int n = 0;   // entries done
        while (n < 256 && at < end)
        {
            int t = _file[at++];
            if ((t & 0x80) != 0)
            {
                n += (t & 0x7F) + 1;   // these stay as they were
            }
            else if ((t & 0x40) != 0)
            {
                int from = _file[at++];
                int count = (t & 0x3F) + 1;
                if (from + count > 256)
                    throw new InvalidDataException("A palette copy runs past the old palette.");
                for (int k = 0; k < count && n < 256; k++, n++)
                {
                    pal[n * 3] = old[(from + k) * 3];
                    pal[n * 3 + 1] = old[(from + k) * 3 + 1];
                    pal[n * 3 + 2] = old[(from + k) * 3 + 2];
                }
            }
            else
            {
                pal[n * 3] = PalMap[t & 0x3F];
                pal[n * 3 + 1] = PalMap[_file[at++] & 0x3F];
                pal[n * 3 + 2] = PalMap[_file[at++] & 0x3F];
                n++;
            }
        }
    }

    // ---- the video --------------------------------------------------------------

    private void DecodeVideo(int at, int length, byte[] px)
    {
        var bits = new BitReader(_file, at, length);
        _mmap.ResetRecent();
        _mclr.ResetRecent();
        _full.ResetRecent();
        _type.ResetRecent();
        int bw = Width / 4, bh = Height / 4;
        int blocks = bw * bh;
        int w = Width;
        int blk = 0;
        while (blk < blocks)
        {
            int type = _type.Decode(bits);
            int run = BlockRuns[(type >> 2) & 0x3F];
            switch (type & 3)
            {
                case 0:   // two colours by a map
                    for (; run > 0 && blk < blocks; run--, blk++)
                    {
                        int clr = _mclr.Decode(bits);
                        int map = _mmap.Decode(bits);
                        byte hi = (byte)(clr >> 8), lo = (byte)clr;
                        int o = Origin(blk, bw, w);
                        for (int y = 0; y < 4; y++, o += w, map >>= 4)
                        {
                            px[o] = (map & 1) != 0 ? hi : lo;
                            px[o + 1] = (map & 2) != 0 ? hi : lo;
                            px[o + 2] = (map & 4) != 0 ? hi : lo;
                            px[o + 3] = (map & 8) != 0 ? hi : lo;
                        }
                    }
                    break;
                case 1:   // every pixel
                    int mode = 0;
                    if (IsSmk4)
                    {
                        if (bits.Bit() != 0) mode = 1;
                        else if (bits.Bit() != 0) mode = 2;
                    }
                    for (; run > 0 && blk < blocks; run--, blk++)
                    {
                        int o = Origin(blk, bw, w);
                        switch (mode)
                        {
                            case 0:
                                for (int y = 0; y < 4; y++, o += w)
                                {
                                    int p = _full.Decode(bits);
                                    px[o + 2] = (byte)p; px[o + 3] = (byte)(p >> 8);
                                    p = _full.Decode(bits);
                                    px[o] = (byte)p; px[o + 1] = (byte)(p >> 8);
                                }
                                break;
                            case 1:   // SMK4: 2x2 doubled
                                for (int y = 0; y < 2; y++, o += 2 * w)
                                {
                                    int p = _full.Decode(bits);
                                    byte a = (byte)p, b = (byte)(p >> 8);
                                    px[o] = px[o + 1] = px[o + w] = px[o + w + 1] = a;
                                    px[o + 2] = px[o + 3] = px[o + w + 2] = px[o + w + 3] = b;
                                }
                                break;
                            default:   // SMK4: each decoded row twice
                                for (int y = 0; y < 2; y++, o += 2 * w)
                                {
                                    int p1 = _full.Decode(bits);
                                    int p2 = _full.Decode(bits);
                                    for (int r = 0; r < 2; r++)
                                    {
                                        int q = o + r * w;
                                        px[q] = (byte)p2; px[q + 1] = (byte)(p2 >> 8);
                                        px[q + 2] = (byte)p1; px[q + 3] = (byte)(p1 >> 8);
                                    }
                                }
                                break;
                        }
                    }
                    break;
                case 2:   // unchanged
                    blk += Math.Min(run, blocks - blk);
                    break;
                default:   // one colour
                    {
                        byte c = (byte)(type >> 8);
                        for (; run > 0 && blk < blocks; run--, blk++)
                        {
                            int o = Origin(blk, bw, w);
                            for (int y = 0; y < 4; y++, o += w)
                                px[o] = px[o + 1] = px[o + 2] = px[o + 3] = c;
                        }
                    }
                    break;
            }
        }
    }

    private static int Origin(int blk, int bw, int w) => (blk / bw) * 4 * w + (blk % bw) * 4;

    // ---- the audio --------------------------------------------------------------

    private short[] DecodeAudio(int at, int length, AudioTrack track)
    {
        if (!track.Compressed)
        {
            if (track.Bits != 16)
                throw new InvalidDataException("8-bit Smacker audio is not read.");
            var raw = new short[length / 2];
            Buffer.BlockCopy(_file, at, raw, 0, raw.Length * 2);
            return raw;
        }
        int unpacked = BitConverter.ToInt32(_file, at);
        var bits = new BitReader(_file, at + 4, length - 4);
        if (bits.Bit() == 0)
            return Array.Empty<short>();
        bool stereo = bits.Bit() != 0;
        bool sixteen = bits.Bit() != 0;
        if (!sixteen)
            throw new InvalidDataException("8-bit Smacker audio is not read.");
        int channels = stereo ? 2 : 1;
        var trees = new ByteTree?[2 * channels];   // per channel: low byte, high byte
        for (int i = 0; i < trees.Length; i++)
            trees[i] = ByteTree.ReadTagged(bits);
        var pred = new int[2];
        for (int c = channels - 1; c >= 0; c--)
        {
            int v = bits.Bits(16);
            pred[c] = (short)(((v & 0xFF) << 8) | (v >> 8));   // stored high byte first
        }
        int count = unpacked / 2;
        var outp = new short[count];
        int n = 0;
        for (int c = 0; c < channels && n < count; c++)
            outp[n++] = (short)pred[c];
        for (; n < count; n++)
        {
            int c = stereo ? (n & 1) : 0;
            int lo = trees[2 * c]?.Decode(bits) ?? 0;
            int hi = trees[2 * c + 1]?.Decode(bits) ?? 0;
            pred[c] += (short)(lo | (hi << 8));
            outp[n] = (short)pred[c];   // wraps, as the original's
        }
        return outp;
    }

    // ---- the trees --------------------------------------------------------------

    private const int Node = 1 << 30;

    /// <summary>
    /// A Huffman tree flattened in reading order: a node holds Node | the size of
    /// its 0 branch, which follows it; its 1 branch comes after that.
    /// </summary>
    private sealed class ByteTree
    {
        private readonly List<int> _t = new();

        /// <summary>A tree after its presence bit, and the 0 bit that closes it; null if absent.</summary>
        public static ByteTree? ReadTagged(BitReader bits)
        {
            if (bits.Bit() == 0)
                return null;
            var tree = new ByteTree();
            tree.Read(bits, 0);
            bits.Bit();
            return tree;
        }

        private int Read(BitReader bits, int depth)
        {
            if (depth > 32)
                throw new InvalidDataException("A Smacker tree is too deep.");
            if (bits.Bit() == 0)
            {
                _t.Add(bits.Bits(8));
                return 1;
            }
            int at = _t.Count;
            _t.Add(0);
            int left = Read(bits, depth + 1);
            _t[at] = Node | left;
            return 1 + left + Read(bits, depth + 1);
        }

        public int Decode(BitReader bits) => Walk(_t, bits);
    }

    private static int Walk(List<int> t, BitReader bits)
    {
        int p = 0;
        while ((t[p] & Node) != 0)
        {
            if (bits.Bit() != 0)
                p += t[p] & ~Node;
            p++;
        }
        return t[p];
    }

    /// <summary>
    /// A 16-bit tree: its leaves are read through a low-byte and a high-byte
    /// tree; three escape values mark the leaves that hold the three most
    /// recent values decoded (0 at each frame's start).
    /// </summary>
    private sealed class BigTree
    {
        private readonly List<int> _t = new();
        private readonly int[] _recent = { -1, -1, -1 };

        public static BigTree Read(BitReader bits)
        {
            var tree = new BigTree();
            if (bits.Bit() == 0)
            {
                // Absent: every value is 0; the recent slots point at a spare.
                tree._t.Add(0);
                tree._t.Add(0);
                tree._recent[0] = tree._recent[1] = tree._recent[2] = 1;
                return tree;
            }
            var low = ByteTree.ReadTagged(bits);
            var high = ByteTree.ReadTagged(bits);
            var esc = new[] { bits.Bits(16), bits.Bits(16), bits.Bits(16) };
            tree.ReadNode(bits, low, high, esc, 0);
            bits.Bit();
            for (int i = 0; i < 3; i++)
                if (tree._recent[i] < 0)
                {
                    tree._recent[i] = tree._t.Count;
                    tree._t.Add(0);
                }
            return tree;
        }

        private int ReadNode(BitReader bits, ByteTree? low, ByteTree? high, int[] esc, int depth)
        {
            if (depth > 32)
                throw new InvalidDataException("A Smacker tree is too deep.");
            if (bits.Bit() == 0)
            {
                int lo = low?.Decode(bits) ?? 0;
                int hi = high?.Decode(bits) ?? 0;
                int v = lo | (hi << 8);
                for (int i = 0; i < 3; i++)
                    if (v == esc[i])
                    {
                        _recent[i] = _t.Count;
                        v = 0;
                        break;
                    }
                _t.Add(v);
                return 1;
            }
            int at = _t.Count;
            _t.Add(0);
            int left = ReadNode(bits, low, high, esc, depth + 1);
            _t[at] = Node | left;
            return 1 + left + ReadNode(bits, low, high, esc, depth + 1);
        }

        public void ResetRecent()
        {
            foreach (var r in _recent)
                _t[r] = 0;
        }

        public int Decode(BitReader bits)
        {
            int v = Walk(_t, bits);
            if (v != _t[_recent[0]])
            {
                _t[_recent[2]] = _t[_recent[1]];
                _t[_recent[1]] = _t[_recent[0]];
                _t[_recent[0]] = v;
            }
            return v;
        }
    }

    /// <summary>Bits from the low end of each byte first; past the end, zeros.</summary>
    private sealed class BitReader
    {
        private readonly byte[] _b;
        private readonly int _start;
        private readonly long _bits;
        private long _pos;

        public BitReader(byte[] b, int start, int length)
        {
            _b = b;
            _start = start;
            _bits = (long)Math.Max(0, Math.Min(length, b.Length - start)) * 8;
        }

        public int Bit()
        {
            if (_pos >= _bits)
            {
                _pos++;
                return 0;
            }
            int v = (_b[_start + (int)(_pos >> 3)] >> (int)(_pos & 7)) & 1;
            _pos++;
            return v;
        }

        public int Bits(int n)
        {
            int v = 0;
            for (int i = 0; i < n; i++)
                v |= Bit() << i;
            return v;
        }
    }
}
