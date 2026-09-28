import struct, sys
from dat import load
SG = r'C:\Program Files (x86)\GOG Galaxy\Games\Star Wars - Rebellion\SaveGame\SAVEGAME.'
FAMN = {0x08:'fleet',0x10:'troop',0x14:'capship',0x18:'deathstar',0x1c:'fighter',0x20:'allfac',0x22:'ion',0x23:'turbo',0x24:'shield',0x25:'dsshield',
 0x28:'shipyard',0x29:'training',0x2a:'constr',0x2c:'mine',0x2d:'refinery',0x3c:'specforce',0x80:'sector',0x90:'sys.core',0x92:'sys.rim',0x98:'abode',
 0xa0:'mgr.a0',0xa2:'mgr.a2',0xa4:'mgr.a4',0xf1:'uniq.f1',0xf2:'uniq.f2',0xf3:'uniq.f3',0xf8:'uniq.f8',0xf9:'uniq.f9',0xfa:'uniq.fa'}
for f in range(0x30,0x36): FAMN[f]='major'
FAMN[0x38]='minor'
for f in (0x41,0x42,0x43,0x44,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x61,0x62,0x63,0x64,0x65,0x69,0x6a,0x71,0x72,0x73): FAMN[f]='msn%02x'%f
def isstr(b, p):
    if p + 2 > len(b): return None
    L = struct.unpack_from('<H', b, p)[0]
    if L < 1 or L > 80 or p + 2 + L > len(b): return None
    s = b[p+2:p+2+L]
    if all(32 <= c < 127 for c in s) and (L >= 2 or chr(s[0]).isalnum()): return s.decode()
    return None
def tokens(b, p):
    out = []
    while p + 4 <= len(b):
        s = isstr(b, p)
        if s is not None and (len(s) >= 3 or s.isdigit()):
            out.append((p, 'S', s)); p += 2 + len(s); continue
        v = struct.unpack_from('<I', b, p)[0]
        out.append((p, 'U', v)); p += 4
    return out
def fmt(v):
    hi = v >> 24; lo = v & 0xffffff
    if hi in FAMN and lo < 0x100000 and hi != 0: return f'{FAMN[hi]}:{lo:#x}'
    if v < 100000: return str(v)
    if v > 0xffff0000: return str(v - (1 << 32))
    if 0x3c000000 <= v <= 0x44000000:
        return 'f%.4g' % struct.unpack('<f', struct.pack('<I', v))[0]
    return f'{v:#010x}'
if __name__ == '__main__':
    n = sys.argv[1]; a = int(sys.argv[2], 0); ln = int(sys.argv[3], 0)
    b = open(SG + n, 'rb').read()
    L = struct.unpack_from('<H', b, 0)[0]
    toks = tokens(b, 2 + L)
    line = []
    for p, k, v in toks:
        if p < a: continue
        if p >= a + ln: break
        line.append(f'"{v}"' if k == 'S' else fmt(v))
    # print 13 per row with offsets
    rows = [t for t in toks if a <= t[0] < a + ln]
    for i in range(0, len(rows), 12):
        print(f'{rows[i][0]:06x}: ' + '  '.join(f'"{v}"' if k=='S' else fmt(v) for _,k,v in rows[i:i+12]))
