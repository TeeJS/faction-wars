using System.Text;

namespace FactionWarsExporter;

/// <summary>
/// Reads the resource table of a Win32 DLL straight from its bytes - no
/// LoadLibrary, so nothing from the game ever executes and a 32-bit DLL reads
/// fine from a 64-bit process. What the importer needs: RT_STRING tables,
/// RT_RCDATA blobs, RT_BITMAP pictures, RT_CURSOR pointers and the droids'
/// type-302 animation frames.
/// </summary>
public sealed class PeResources
{
    private const int RtCursor = 1;
    private const int RtBitmap = 2;
    private const int RtString = 6;
    private const int RtRcData = 10;
    private const int RtDroidFrame = 302;   // ALSPRITE / EMSPRITE.DLL: a droid's frames, each a delta on the one before

    private readonly byte[] _bytes;
    private readonly List<(uint VirtualAddress, uint VirtualSize, uint RawPointer, uint RawSize)> _sections = new();
    private readonly uint _resourceRva;

    /// <summary>id -> (offset, size) for every RT_RCDATA entry.</summary>
    public IReadOnlyDictionary<int, (int Offset, int Size)> RcData { get; }

    /// <summary>id -> (offset, size) for every RT_BITMAP entry (a DIB: BITMAPINFOHEADER + palette + pixels, no file header).</summary>
    public IReadOnlyDictionary<int, (int Offset, int Size)> Bitmaps { get; }

    /// <summary>id -> (offset, size) for every RT_CURSOR entry (hotspot, then a DIB twice as tall: colours over the AND mask).</summary>
    public IReadOnlyDictionary<int, (int Offset, int Size)> Cursors { get; }

    /// <summary>id -> (offset, size) for every type-302 entry (a droid's animation frame).</summary>
    public IReadOnlyDictionary<int, (int Offset, int Size)> DroidFrames { get; }

    /// <summary>String table entries by string id, as the game reads them.</summary>
    public IReadOnlyDictionary<int, string> Strings { get; }

    public PeResources(string path)
    {
        _bytes = File.ReadAllBytes(path);
        int peOffset = ReadInt32(0x3C);
        if (ReadInt32(peOffset) != 0x00004550)
            throw new InvalidDataException($"{Path.GetFileName(path)} is not a Windows DLL.");
        int coff = peOffset + 4;
        int sectionCount = ReadUInt16(coff + 2);
        int optionalSize = ReadUInt16(coff + 16);
        int optional = coff + 20;
        int magic = ReadUInt16(optional);
        int dataDirs = optional + (magic == 0x20B ? 112 : 96);
        _resourceRva = (uint)ReadInt32(dataDirs + 2 * 8);      // directory 2 = resources
        int sectionTable = optional + optionalSize;
        for (int i = 0; i < sectionCount; i++)
        {
            int s = sectionTable + i * 40;
            _sections.Add(((uint)ReadInt32(s + 12), (uint)ReadInt32(s + 8), (uint)ReadInt32(s + 20), (uint)ReadInt32(s + 16)));
        }

        var rcdata = new Dictionary<int, (int, int)>();
        var bitmaps = new Dictionary<int, (int, int)>();
        var strings = new Dictionary<int, string>();
        var cursors = new Dictionary<int, (int, int)>();
        var droidFrames = new Dictionary<int, (int, int)>();
        if (_resourceRva != 0)
        {
            int root = RvaToOffset(_resourceRva);
            foreach (var (typeId, typeDir) in Entries(root))
            {
                if (typeId != RtString && typeId != RtRcData && typeId != RtBitmap && typeId != RtCursor && typeId != RtDroidFrame) continue;
                foreach (var (nameId, nameDir) in Entries(typeDir))
                {
                    foreach (var (_, dataEntry) in Entries(nameDir, leaf: true))
                    {
                        int dataRva = ReadInt32(dataEntry);
                        int size = ReadInt32(dataEntry + 4);
                        int offset = RvaToOffset((uint)dataRva);
                        if (typeId == RtRcData)
                            rcdata[nameId] = (offset, size);
                        else if (typeId == RtBitmap)
                            bitmaps[nameId] = (offset, size);
                        else if (typeId == RtCursor)
                            cursors[nameId] = (offset, size);
                        else if (typeId == RtDroidFrame)
                            droidFrames[nameId] = (offset, size);
                        else
                            ReadStringBlock(nameId, offset, size, strings);
                        break;   // first language only
                    }
                }
            }
        }
        RcData = rcdata;
        Bitmaps = bitmaps;
        Strings = strings;
        Cursors = cursors;
        DroidFrames = droidFrames;
    }

    /// <summary>
    /// An RT_CURSOR as its hotspot and top-down ARGB pixels: the colour image,
    /// transparent where the AND mask is set. (The game's cursors are black,
    /// white and clear only - no screen-inverting pixels.)
    /// </summary>
    public (int HotX, int HotY, int Width, int Height, int[] Argb) Cursor(int id)
    {
        var (o, _) = Cursors[id];
        int hotX = ReadUInt16(o), hotY = ReadUInt16(o + 2);
        int dib = o + 4;
        int headerSize = ReadInt32(dib);
        int w = ReadInt32(dib + 4);
        int h = ReadInt32(dib + 8) / 2;
        int bpp = ReadUInt16(dib + 14);
        int colours = ReadInt32(dib + 32);
        if (colours == 0 && bpp <= 8) colours = 1 << bpp;
        int palette = dib + headerSize;
        int xorBits = palette + colours * 4;
        int xorStride = (w * bpp + 31) / 32 * 4;
        int andBits = xorBits + xorStride * h;
        int andStride = (w + 31) / 32 * 4;
        var argb = new int[w * h];
        for (int y = 0; y < h; y++)
        {
            int row = h - 1 - y;   // bottom-up
            for (int x = 0; x < w; x++)
            {
                int index = bpp switch
                {
                    1 => (_bytes[xorBits + row * xorStride + x / 8] >> (7 - x % 8)) & 1,
                    4 => (_bytes[xorBits + row * xorStride + x / 2] >> (x % 2 == 0 ? 4 : 0)) & 0xF,
                    8 => _bytes[xorBits + row * xorStride + x],
                    _ => 0,
                };
                bool clear = ((_bytes[andBits + row * andStride + x / 8] >> (7 - x % 8)) & 1) == 1;
                int b = _bytes[palette + index * 4], g = _bytes[palette + index * 4 + 1], r = _bytes[palette + index * 4 + 2];
                argb[y * w + x] = clear ? 0 : unchecked((int)0xFF000000) | (r << 16) | (g << 8) | b;
            }
        }
        return (hotX, hotY, w, h, argb);
    }

    /// <summary>
    /// An RT_BITMAP as a complete .bmp file in memory: the 14-byte BITMAPFILEHEADER
    /// the resource form leaves out, then the DIB as stored.
    /// </summary>
    public byte[] BitmapFile(int id)
    {
        var (offset, size) = Bitmaps[id];
        int headerSize = ReadInt32(offset);
        int bitsPerPixel = ReadUInt16(offset + 14);
        int colours = ReadInt32(offset + 32);
        if (colours == 0 && bitsPerPixel <= 8) colours = 1 << bitsPerPixel;
        int pixelOffset = 14 + headerSize + colours * 4;
        var file = new byte[14 + size];
        file[0] = (byte)'B'; file[1] = (byte)'M';
        BitConverter.GetBytes(14 + size).CopyTo(file, 2);
        BitConverter.GetBytes(pixelOffset).CopyTo(file, 10);
        Buffer.BlockCopy(_bytes, offset, file, 14, size);
        return file;
    }

    /// <summary>An RT_BITMAP's DIB exactly as stored (BITMAPINFOHEADER, palette, pixels).</summary>
    public byte[] BitmapDib(int id)
    {
        var (offset, size) = Bitmaps[id];
        return _bytes.AsSpan(offset, size).ToArray();
    }

    /// <summary>The bytes of one type-302 droid frame.</summary>
    public byte[] DroidFrameBytes(int id)
    {
        var (offset, size) = DroidFrames[id];
        return _bytes.AsSpan(offset, size).ToArray();
    }

    /// <summary>The bytes of one RT_RCDATA entry.</summary>
    public byte[] RcDataBytes(int id)
    {
        var (offset, size) = RcData[id];
        return _bytes.AsSpan(offset, size).ToArray();
    }

    /// <summary>An RCDATA blob as the game's 8-bit text, trailing NULs dropped.</summary>
    public string RcDataText(int id)
    {
        var raw = RcDataBytes(id);
        int end = raw.Length;
        while (end > 0 && raw[end - 1] == 0) end--;
        return Encoding.Latin1.GetString(raw, 0, end).Replace("\r\n", "\n");
    }

    // A string table block holds 16 strings: u16 length, then UTF-16 chars.
    private void ReadStringBlock(int blockId, int offset, int size, Dictionary<int, string> into)
    {
        int baseId = (blockId - 1) * 16;
        int pos = offset;
        int end = offset + size;
        for (int i = 0; i < 16 && pos + 2 <= end; i++)
        {
            int length = ReadUInt16(pos);
            pos += 2;
            if (length > 0)
            {
                into[baseId + i] = Encoding.Unicode.GetString(_bytes, pos, length * 2);
                pos += length * 2;
            }
        }
    }

    // The entries of one resource directory: (id, offset of the child).
    // A non-leaf child is another directory; a leaf child is a data entry.
    private IEnumerable<(int Id, int Child)> Entries(int dirOffset, bool leaf = false)
    {
        int named = ReadUInt16(dirOffset + 12);
        int numbered = ReadUInt16(dirOffset + 14);
        int root = RvaToOffset(_resourceRva);
        for (int i = 0; i < named + numbered; i++)
        {
            int e = dirOffset + 16 + i * 8;
            int id = ReadInt32(e);
            int child = ReadInt32(e + 4);
            bool isDir = (child & unchecked((int)0x80000000)) != 0;
            int childOffset = root + (child & 0x7FFFFFFF);
            if (id < 0) continue;   // named entries are not used by these tables
            if (leaf && isDir)
            {
                // language level: descend once more to the data entry
                foreach (var (_, dataEntry) in Entries(childOffset, leaf: true))
                {
                    yield return (id, dataEntry);
                    break;
                }
            }
            else
            {
                yield return (id, childOffset);
            }
        }
    }

    private int RvaToOffset(uint rva)
    {
        foreach (var s in _sections)
        {
            uint size = Math.Max(s.VirtualSize, s.RawSize);
            if (rva >= s.VirtualAddress && rva < s.VirtualAddress + size)
                return (int)(rva - s.VirtualAddress + s.RawPointer);
        }
        throw new InvalidDataException($"RVA 0x{rva:X} is outside every section.");
    }

    private int ReadInt32(int at) => BitConverter.ToInt32(_bytes, at);
    private int ReadUInt16(int at) => BitConverter.ToUInt16(_bytes, at);
}
