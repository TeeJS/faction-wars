using System.Text;

namespace RebellionArtImporter;

/// <summary>
/// Reads the resource table of a Win32 DLL straight from its bytes - no
/// LoadLibrary, so nothing from the game ever executes and a 32-bit DLL reads
/// fine from a 64-bit process. Only what the Encyclopedia needs: RT_STRING
/// tables and RT_RCDATA blobs.
/// </summary>
public sealed class PeResources
{
    private const int RtString = 6;
    private const int RtRcData = 10;

    private readonly byte[] _bytes;
    private readonly List<(uint VirtualAddress, uint VirtualSize, uint RawPointer, uint RawSize)> _sections = new();
    private readonly uint _resourceRva;

    /// <summary>id -> (offset, size) for every RT_RCDATA entry.</summary>
    public IReadOnlyDictionary<int, (int Offset, int Size)> RcData { get; }

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
        var strings = new Dictionary<int, string>();
        if (_resourceRva != 0)
        {
            int root = RvaToOffset(_resourceRva);
            foreach (var (typeId, typeDir) in Entries(root))
            {
                if (typeId != RtString && typeId != RtRcData) continue;
                foreach (var (nameId, nameDir) in Entries(typeDir))
                {
                    foreach (var (_, dataEntry) in Entries(nameDir, leaf: true))
                    {
                        int dataRva = ReadInt32(dataEntry);
                        int size = ReadInt32(dataEntry + 4);
                        int offset = RvaToOffset((uint)dataRva);
                        if (typeId == RtRcData)
                            rcdata[nameId] = (offset, size);
                        else
                            ReadStringBlock(nameId, offset, size, strings);
                        break;   // first language only
                    }
                }
            }
        }
        RcData = rcdata;
        Strings = strings;
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
