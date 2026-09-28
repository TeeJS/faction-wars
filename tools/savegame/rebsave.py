"""Reader for Star Wars: Rebellion save games (SaveGame\\SAVEGAME.nnn).

The grammar is transcribed from the game's own save code in REBEXE.EXE (GOG
build, sha256 b3fe3997...ed6ab). Every rule names the function it mirrors;
SAVEGAME-FORMAT.md explains the layout. Read-only: nothing here writes a save.

    python rebsave.py SAVEGAME.001          # parse, report, check every marker
"""
import struct, sys, json

class SaveError(Exception):
    pass

class Reader:
    def __init__(self, data):
        self.b = data; self.pos = 0; self.marks = 0
    def u32(self):
        if self.pos + 4 > len(self.b): raise SaveError(f'u32 past end at {self.pos:#x}')
        v = struct.unpack_from('<I', self.b, self.pos)[0]; self.pos += 4; return v
    def u16(self):
        v = struct.unpack_from('<H', self.b, self.pos)[0]; self.pos += 2; return v
    def s(self):                                   # 0x5f38f0: u16 length + bytes
        n = self.u16(); v = self.b[self.pos:self.pos + n]; self.pos += n
        return v.decode('latin1')
    def mark(self, what):                          # 0x5f4d70: the u32 is its own offset
        at = self.pos; v = self.u32()
        if v != at: raise SaveError(f'marker expected at {at:#x} ({what}), found {v:#x}')
        self.marks += 1
    def n(self, k): return [self.u32() for _ in range(k)]

# ---------------------------------------------------------------- game objects

def base(r, o):                                    # 0x4f9450 GameObj::Save
    o['serial'] = r.u32()                          # +0x18
    o['flags'] = r.u32()                           # +0x24  owner 0xC0, copy 0x30
    o['template'] = r.u32()                        # +0x2c -> +0x18, the .DAT id
    if r.u32(): o['name'] = r.s()                  # +0x34
    o['f50'], o['f38'], o['f3c'], o['f40'], o['f44'], o['f48'], o['f4c'] = r.n(7)
    return (o['flags'] & 0x30) == 0                # master copy: state block follows

# state blocks, [obj+0x54], master copy only
def st_base(r): return r.n(5)                      # 0x553fa0
def st_capship(r): return r.n(10)                  # 0x558740
def st_fighter(r): return r.n(7)                   # 0x58b280
def st_facility(r): return r.n(9)                  # 0x5846b0
def st_character(r): return r.n(13)                # 0x5408e0
def st_mission(r): return r.n(12)                  # 0x583720
def st_system(r): return r.n(32)                   # 0x55a3b0
def st_manager(r):                                 # 0x5838f0
    v = r.n(5); v.append(reflist(r, 'manager')); return v

def reflist(r, where, size=2):                     # 0x4f5710: count + nodes (vf+0x14)
    n = r.u32()                                    # node 0x65d1f0 = key + value (0x4f5c20)
    if size is None and n:                         # global node 0x65ca50 = key (0x4ece10)
        raise SaveError(f'{where}: non-empty list ({n}) at {r.pos:#x} - node class not decoded yet')
    return [r.n(size) for _ in range(n)]

def char_common(r, o):                             # 0x534d20
    o['w16a'] = [r.u16() for _ in range(8)]
    o['c'] = r.n(5)

def mission(r, o):                                 # 0x523910
    o['m'] = r.n(11)
    o['lists'] = [reflist(r, 'mission') for _ in range(4)]
    o['m_a4'] = r.u32()

def cls_f3_list(r):                                # 0x583b90; node 0x66a0e0 = 0x583d80
    a = r.u32(); n = r.u32()
    return [a, [r.n(3) for _ in range(n)]]

CLASSES = {}
def cls(codes, state):
    def deco(fn):
        for c in codes: CLASSES[c] = (fn, state)
        return fn
    return deco

@cls([0x08], st_base)
def fleet(r, o, m): o['x'] = r.n(1)                             # 0x4fef70
@cls([0x10], st_base)
def troop(r, o, m): o['x'] = r.n(3)                             # 0x5046d0
@cls([0x14, 0x18], st_capship)
def capship(r, o, m): o['x'] = r.n(4)                           # 0x501f40
@cls([0x1c], st_fighter)
def fighter(r, o, m): o['x'] = r.n(3)                           # 0x503660
@cls([0x20, 0x22, 0x23, 0x24, 0x25], st_base)
def defence(r, o, m): pass                                      # 0x526be0
@cls([0x28, 0x29, 0x2a], st_facility)
def manufacturing(r, o, m): o['x'] = r.n(3)                     # 0x53aba0
@cls([0x2c, 0x2d], st_facility)
def production(r, o, m): o['x'] = r.n(6)                        # 0x55acf0
@cls([0x30, 0x34, 0x35, 0x38], st_character)
def character(r, o, m):                                         # 0x4ef940
    char_common(r, o); o['w16b'] = [r.u16() for _ in range(16)]; o['x'] = r.n(5)
@cls([0x31, 0x32, 0x33], st_character)
def character_b(r, o, m):                                       # 0x5728b0
    character(r, o, m); o['x'].append(r.u32())
@cls([0x3c], st_base)
def special_force(r, o, m): char_common(r, o)                   # 0x503f60
@cls([0x41, 0x42, 0x43, 0x44, 0x51, 0x54, 0x56, 0x57, 0x61, 0x62, 0x63, 0x64, 0x65, 0x69, 0x6a, 0x72, 0x73], st_mission)
def mission_plain(r, o, m): mission(r, o)
@cls([0x52, 0x55, 0x58, 0x71], st_mission)
def mission_1(r, o, m): mission(r, o); o['x'] = r.n(1)          # 0x5730e0, 0x5750b0
@cls([0x53], st_mission)
def mission_2(r, o, m): mission(r, o); o['x'] = r.n(2)          # 0x56cb80
@cls([0x80, 0x98, 0xf2], st_base)
def plain(r, o, m): pass                                        # 0x4f29d0
@cls([0x90, 0x92], st_system)
def system(r, o, m): o['x'] = r.n(13)                           # 0x50e4e0
@cls([0xa0, 0xa2, 0xa4], st_manager)
def manager(r, o, m): o['x'] = r.n(10); o['text'] = r.s()       # 0x52a510
@cls([0xf1], st_base)
def galaxy(r, o, m):                                            # 0x518ef0
    if m: o['x'] = r.n(4 + 8 + 1 + 6 + 1)
@cls([0xf3], st_base)
def side(r, o, m):                                              # 0x531020
    o['x'] = r.n(6 + 6)
    o['l1'] = cls_f3_list(r); o['l2'] = cls_f3_list(r)
    o['y'] = r.n(14)
    a = r.u32(); n = r.u32(); o['l3'] = [a, [r.n(3) for _ in range(n)]]   # 0x4f41c0 / 0x540bb0
    o['z'] = r.n(4)
@cls([0xf8], st_base)
def uniq_f8(r, o, m): o['x'] = r.n(5)                           # 0x549f00
@cls([0xf9], st_base)
def uniq_f9(r, o, m): o['x'] = r.n(4)                           # 0x5570f0
@cls([0xfa], st_base)
def uniq_fa(r, o, m): o['x'] = r.n(2 if m else 1)               # 0x562200

def obj(r, code):
    fn, state = CLASSES.get(code, (None, None))
    if fn is None: raise SaveError(f'unknown class code {code:#x} at {r.pos - 4:#x}')
    o = {'class': code, 'at': r.pos}
    master = base(r, o)
    if master: o['state'] = state(r)
    fn(r, o, master)
    o['children'] = children(r)
    return o

def children(r):                                   # 0x53a350 child walker
    kids = []
    if not r.u32(): return kids                    # has a child list
    r.u32()                                        # list +0x0c
    n = r.u32()                                    # child count
    if n: r.mark('children')
    for _ in range(n):
        kids.append(obj(r, r.u32()))               # class code (vf+4), then Save
    return kids

# ---------------------------------------------------------------- whole file

def event(r):                                      # a8/ac/b0 nodes: code, then vf+0xc
    code = r.u32()
    if 0x380 <= code <= 0x394: k = 12              # 0x586360
    elif 0x300 <= code <= 0x31d or code in (0x320, 0x321): k = 14   # 0x586470 / 0x586660
    elif code in (0x370, 0x371, 0x372): k = 9      # 0x54f080
    elif code == 0x373: k = 10                     # 0x562e00
    elif code == 0x3f0: k = 13                     # 0x5802f0
    else: raise SaveError(f'unknown event code {code:#x} at {r.pos - 4:#x}')
    return [code] + r.n(k)

def eventlist(r):                                  # 0x54eb80
    return [event(r) for _ in range(r.u32())]

def typed_list(r, where):                          # 0x536f70 / 0x568980 nodes
    n = r.u32()
    if n: raise SaveError(f'{where}: non-empty list ({n}) at {r.pos:#x} - node class not decoded yet')
    return []

def parse(data):
    r = Reader(data); g = {}
    g['name'] = r.s()                              # 0x411970 header
    g['header'] = r.n(6)                           # ?, ?, single/multi, slot, side, ?
    r.mark('root')                                 # 0x4095b0
    g['root'] = r.n(4)
    if g['root'][1] != 2: raise SaveError('not a mode-2 save')
    r.mark('settings')
    r.mark('settings body')                        # 0x41de70
    g['settings'] = r.n(7)
    r.mark('game')
    r.mark('game body')                            # 0x51d2c0
    n = r.u32(); g['strings_x'] = r.u32(); g['strings'] = [r.s() for _ in range(n)]   # 0x568a80
    g['game'] = r.n(19)
    g['timers'] = [r.n(5) for _ in range(3)]       # 0x539910
    r.mark('a4')
    g['a4'] = typed_list(r, 'a4')                  # 0x536f70: count, then nodes
    r.mark('events')
    g['events'] = eventlist(r)
    r.mark('events ac')
    g['events_ac'] = eventlist(r)
    r.mark('events b0')
    g['events_b0'] = eventlist(r)
    r.mark('b4')
    g['b4'] = [r.u32(), typed_list(r, 'b4')]       # 0x568980
    r.mark('b8')
    g['b8'] = [r.u32(), typed_list(r, 'b8')]
    r.mark('bc')
    g['bc'] = [r.u32(), reflist(r, 'bc', None)]    # 0x568c80
    r.mark('galaxy')
    g['global_list'] = reflist(r, 'global', 1)     # 0x53f610 -> 0x4f5710
    g['views'] = []
    for v in range(3):                             # 0x513df0: master, Alliance, Empire
        g['views'].append(obj(r, 0xf1))            # no class code: Save + children only
    g['one'] = r.u32()                             # constant 1
    g['tail'] = r.n(20 + 30)                       # 0x5685a0: 0x5682d0 + 3 x 0x5684c0
    r.mark('after game')                           # 0x41de70
    g['ui'] = r.n(6)                               # 0x435ec0 (object present)
    return r, g

if __name__ == '__main__':
    data = open(sys.argv[1], 'rb').read()
    try:
        r, g = parse(data)
        print('parsed to', hex(r.pos), 'of', hex(len(data)), 'markers', r.marks)
    except SaveError as e:
        print('FAILED:', e)
