"""The save's tail after the game: the two players, the human's windows (its
message list) and message queue. Grammar from REBEXE; every function is named
where used (SAVEGAME-FORMAT.md, "The players").

    python players.py SAVEGAME.001      # the human's block and its messages
"""
import sys, struct
sys.path.insert(0, __import__("os").path.dirname(__file__))
import rebsave


class Bad(Exception):
    pass


def u16(r):
    v = struct.unpack_from('<H', r.b, r.pos)[0]; r.pos += 2; return v


def u8(r):
    v = r.b[r.pos]; r.pos += 1; return v


# ---- UI messages (table 0x6b2fd8, 0x51f730) --------------------------------------------
LAYOUT = {1: 'C', 2: 'C', 0x1e0: 'E', 0x200: 'F', 0x500: 'D', 0x520: 'D', 0x600: 'C'}
for i in list(range(0x100, 0x108)) + list(range(0x120, 0x12d)) + list(range(0x140, 0x157)) + list(range(0x160, 0x164)) \
        + list(range(0x180, 0x184)) + [0x1a0] + list(range(0x1c0, 0x1c7)) + list(range(0x1e1, 0x1e6)) + [0x1f0, 0x1f1] \
        + [0x210, 0x211, 0x212, 0x220, 0x221, 0x230, 0x231]:
    LAYOUT.setdefault(i, 'A')
for i in [0x300, 0x301, 0x302, 0x303, 0x304, 0x305, 0x306, 0x320, 0x321, 0x340, 0x360, 0x361, 0x362, 0x370, 0x380, 0x400]:
    LAYOUT[i] = 'B'


def uimsg(r, code):
    if code not in LAYOUT:
        raise Bad(f'unknown UI message type {code:#x} at {r.pos - 4:#x}')
    m = {'type': code, 'at': r.pos - 4, 'h': r.n(5), 'key': r.u32()}   # 0x51f840 + 0x5840d0
    lay = LAYOUT[code]
    if lay in 'AEF':
        m['a'] = r.n(2)                                                  # 0x539400
        if lay == 'E': m['keys'] = r.n(4)                                # 0x43dcf0
        if lay == 'F': m['key2'] = r.u32(); m['x'] = r.u32()             # 0x43c7c0
    elif lay == 'B': m['keys'] = r.n(2)                                  # 0x5397a0
    elif lay == 'C': m['a'] = r.n(4)                                     # 0x5394f0
    elif lay == 'D': m['title'] = r.s(); m['text'] = r.s()              # 0x539660
    return m


def msglog(r):                            # 0x4bef30 -> 0x4e4eb0 (groups of UI messages)
    n = r.u32()
    out = []
    for _ in range(n):
        g = {'id': r.u32(), 'count': r.u32(), 'g28': r.u32()}
        g['items'] = [uimsg(r, r.u32()) for _ in range(g['count'])]
        out.append(g)
    return out


# ---- game objects in typed lists (table 0x6b6fe0, 0x51f8f0) ------------------------------
def gobj(r, code):
    if code == 1:                         # 0x440ad0: 0x51f9e0 (2) + 0x4f5e50 (3) + 1 + 0x539910 (5)
        return {'type': 1, 'w': r.n(11)}
    raise Bad(f'typed-list object {code:#x} at {r.pos - 4:#x} not decoded')


def typed_list(r):                        # 0x536f70
    n = r.u32()
    return [gobj(r, r.u32()) for _ in range(n)]


def reflist(r):                           # 0x4f5710: count, key + value
    n = r.u32()
    return [r.n(2) for _ in range(n)]


# ---- windows (prototype table 0x6b1f40) ----------------------------------------------------
def wb0(r):                               # 0x4c4f30
    return [r.u32(), r.u32(), r.u32(), u16(r), r.u32(), r.u32(), u16(r), u16(r), u16(r), u16(r), r.u32(), r.u32()]


def wb1(r):                               # 0x4c4c90
    w = {'b0': wb0(r), 's1': r.s(), 's2': r.s(), 'k': r.n(2)}
    return w


def wb2(r):                               # 0x4c51f0
    return {'b0': wb0(r), 's1': r.s(), 's2': r.s(), 'x': r.u32(), 'k': r.u32()}


def window(r, t):
    w = {'type': t, 'at': r.pos - 4}
    if t == 1:                            # 0x49afa0
        w['b0'] = wb0(r); w['x'] = r.n(5); w['lists'] = [reflist(r) for _ in range(4)]
        w['strings'] = [r.s() for _ in range(5)]
    elif t == 2:                          # 0x49c040
        w['b0'] = wb0(r); w['x'] = r.n(4); w['lists'] = [reflist(r) for _ in range(2)]
        w['strings'] = [r.s() for _ in range(2)]
    elif t == 8:                          # 0x49a2c0
        w['b0'] = wb0(r); w['strings'] = [r.s() for _ in range(2)]
    elif t in (3, 4, 0xc, 0x22, 0x2b, 0x13, 0x20):   # 0x48b980, 0x495e70, 0x48e820: b1 + 1
        w.update(wb1(r)); w['x'] = r.n(1)
    elif t in (5, 6, 7, 0xa, 0xb, 0x18, 0x19, 0x1a, 0x1c, 0x1d, 0x24, 0x25, 0x26, 0x27, 0x29, 0x2a, 0x2c, 0x2d):
        w.update(wb1(r))                  # 0x499dd0
    elif t in (9, 0xd, 0xe, 0x10, 0x14, 0x28):       # 0x497910, 0x495580, 0x48c490: b1 + 2
        w.update(wb1(r)); w['x'] = r.n(2)
    elif t == 0xf:                        # 0x4966f0
        w.update(wb1(r)); w['x'] = r.n(4); w['lists'] = [reflist(r) for _ in range(4)]
    elif t == 0x15:                       # 0x495090
        w.update(wb2(r)); w['x'] = r.n(3)
    elif t in (0x1e, 0x1f):               # 0x48f770
        w.update(wb2(r)); w['x'] = r.n(1)
    elif t == 0x21:                       # 0x48be20
        w.update(wb1(r)); w['x'] = r.n(3)
    elif t == 0x23:                       # 0x48d460
        w.update(wb2(r))
    elif t == 0x16:                       # 0x492740
        w.update(wb1(r)); w['x'] = r.n(7)
    elif t == 0x17:                       # 0x4914a0
        w.update(wb1(r)); w['x'] = r.n(6)
    else:
        raise Bad(f'window type {t:#x} at {r.pos - 4:#x} not decoded')
    return w


def windows(r):                           # 0x437720
    n = u16(r)
    return [window(r, r.u32()) for _ in range(n)]


def u16list(r, what):                     # 0x5f5da0: u16 count, items 0x5f5f80 (vt 0x66dd28): 2 words
    n = u16(r)
    return [r.n(2) for _ in range(n)]


# ---- players ------------------------------------------------------------------------------------
def player_base(r):                       # 0x4886d0 -> 0x48a8a0
    p = {'side': r.u32(), 'p14': r.u32()}
    flag = r.u32(); p['p18'] = flag
    p['p1c'] = r.u32()
    if flag:
        raise Bad(f'player +0x20 object at {r.pos:#x} (class 0x440910) not decoded')
    p['p28'] = r.u32(); p['p2c'] = r.u32()
    p['list'] = typed_list(r)
    p['w'] = r.n(6); p['key40'] = r.u32(); p['w3c'] = r.u32()
    return p


def screens(r):                           # 0x488ac0
    s = {'a': r.n(2)}
    s['win1'] = windows(r); s['win2'] = windows(r)
    s['l44'] = u16list(r, 'screens +0x44')
    s['b'] = r.n(3)
    s['win3'] = windows(r)
    return s


def member_list(r):                       # 0x435720: +0xc, count, fixed-class nodes
    m = {'c': r.u32()}
    n = r.u32()
    if n: raise Bad(f'0x435720 list of {n} at {r.pos:#x}: node class not decoded')
    return m


def plan_entry(r, t):                     # 0x49e010 types 0x14 / 0x15 / 0x17, base 0x4c7dc0
    e = {'type': t, 'at': r.pos - 4, 'base': r.n(6)}
    if t == 0x14:                         # 0x4c6c40
        e['a'] = r.n(2); e['keys'] = r.n(2); e['m'] = member_list(r); e['key'] = r.u32()
    elif t == 0x15:                       # 0x4c74b0
        e['a'] = r.n(3); e['keys'] = r.n(2); e['m'] = member_list(r); e['key'] = r.u32()
    elif t == 0x17:                       # 0x49e310
        e['a'] = r.n(2); e['keys'] = r.n(2); e['m'] = member_list(r)
    else:
        raise Bad(f'0x49de40 entry type {t:#x} at {r.pos - 4:#x}')
    return e


def plans(r):                             # 0x49de40
    p = {'c': r.u32()}
    n = u16(r)
    p['entries'] = [plan_entry(r, r.u32()) for _ in range(n)]
    p['ids'] = r.n(3)
    return p


def sysrec(r):                            # 0x4ebd80 (vt 0x65ca10): one per system
    return {'key': r.u32(), 'a': r.n(6), 'b': [u16(r), u16(r)], 'c': r.n(22 + 1)}


def rec2(r):                              # 0x4c61d0 (vt 0x65c610)
    return {'key': r.u32(), 'a': r.n(4), 'b': [u16(r), u16(r), u16(r)], 'keys': r.n(10), 'c': r.n(26)}


def opt_obj(r):                           # class byte, then its key when non-zero
    cls = r.u32()
    return [cls, r.u32()] if cls else [0]


def container(r, node):                   # 0x4c5a90 / 0x4c55d0
    c = {'w': r.u32()}
    n = r.u32()
    c['nodes'] = [node(r) for _ in range(n)]
    c['o10'] = opt_obj(r); c['o0c'] = opt_obj(r)
    return c


def side_node(r):                         # 0x4c5380 (vt 0x65c5b0; loaded by 0x49c6f0)
    e = {'a': r.u32(), 'b': r.u32()}
    n = r.u32(); e['n'] = n; e['c'] = r.u32()
    e['items'] = [[u16(r), r.u32(), r.u32(), r.u32()] for _ in range(n)]
    return e


def side_ui(r):                           # 0x4397a0
    s = {'a': r.n(4), 'g': r.n(5)}
    # 0x49c9f0 (+0x3c): [+0], +0x78, +0x7c, +4, then its containers +8 and +0x20
    c = {'a': r.n(4), 'systems': container(r, sysrec), 'other': container(r, rec2), 'x': r.n(30 + 1)}
    c['obj'] = opt_obj(r)
    s['c'] = c
    n = r.u32(); s['entries'] = [side_node(r) for _ in range(n)]      # 0x4e5210 of 0x4c5380
    s['b'] = r.u32()
    s['plans'] = plans(r)
    s['c34'] = r.u32(); s['b170'] = u8(r)
    s['d'] = r.n(3)                       # +0x160, global, +0x164 (count)
    cnt = s['d'][2]
    s['e'] = r.n(3)                       # +0x188 +0x18c +0x190
    s['arr'] = r.n(cnt)
    s['f'] = r.n(3)
    s['l154'] = u16list(r, 'side ui +0x154')
    return s


def human(r):                             # 0x486440
    h = {'base': player_base(r), 'h50': r.u32(), 'h54': r.u32()}
    h['log'] = msglog(r)
    h['screens'] = screens(r)
    h['side_ui'] = side_ui(r)
    return h


# ---- the AI player (type 3: 0x485990) ------------------------------------------------------
def n2c(r):   # 0x433d10
    return {'key': r.u32(), 'a': r.n(5), 'b': [u16(r), u16(r)], 'c': r.n(3), 'd': r.n(60)}


def n44(r):   # 0x431680
    return {'key': r.u32(), 'a': r.n(9), 'b': [u16(r), u16(r)], 'keys': r.n(10), 'd': r.n(90)}


def n58(r):   # 0x484490
    return {'key': r.u32(), 'a': r.n(7), 'd': r.n(30)}


def n78(r):   # 0x433150
    e = {'key': r.u32(), 'a': r.n(9)}
    n = r.u32(); e['k44'] = r.u32()
    e['sub'] = [r.u32() for _ in range(n)]     # nodes of +0x48 (vf+0x10): assumed one key each
    e['d'] = r.n(30)
    return e


def n8c(r):   # 0x402120
    return {'key': r.u32(), 'a': r.n(7), 'k': r.u32(), 'd': r.n(10)}


def ai_list(r, what):                      # 0x42f2b0 / 0x42eee0 / 0x42f5b0 lists: raise when non-empty
    c = r.u32(); n = r.u32()
    if n: raise Bad(f'AI list {what}: {n} nodes at {r.pos:#x}, classes not decoded')
    return {'c': c}


def ai_state(r):                           # 0x417fa0
    s = {'a': r.n(3), 'b': r.u32(), 'c': r.n(3), 'keys': r.n(6), 'd': r.n(3)}
    w = r.u32(); n = r.u32(); s['c2c'] = {'w': w, 'nodes': [n2c(r) for _ in range(n)], 'o': [opt_obj(r), opt_obj(r)]}
    w = r.u32(); n = r.u32(); s['c44'] = {'w': w, 'nodes': [n44(r) for _ in range(n)], 'o': [opt_obj(r), opt_obj(r)]}
    w = r.u32(); n = r.u32(); s['c58'] = {'w': w, 'nodes': [n58(r) for _ in range(n)], 'x': r.u32()}
    w = r.u32(); n = r.u32(); s['c78'] = {'w': w, 'nodes': [n78(r) for _ in range(n)]}
    s['k130'] = r.u32()
    w = r.u32(); w2 = r.u32(); n = r.u32(); s['c8c'] = {'w': [w, w2], 'nodes': [n8c(r) for _ in range(n)], 'x': r.u32()}
    s['k134'] = r.u32()
    s['la8'] = ai_list(r, '+0xa8 (0x42f5b0)')
    s['lec'] = ai_list(r, '+0xec (0x42eee0)')
    s['ld8'] = ai_list(r, '+0xd8 (0x42f2b0)')
    s['l11c'] = ai_list(r, '+0x11c (0x42f2b0)')
    s['arr'] = r.n(100 + 3 + 13 + 2 + 2 + 12)
    s['obj'] = opt_obj(r)
    return s


def ai(r):                                 # 0x485990
    a = {'base': player_base(r), 'state': ai_state(r), 'log': msglog(r), 'plans': plans(r)}
    a['tail'] = r.n(7)                     # +0x50, (+0x80)->, +0x418 +0x41c +0x420 +0x424, last
    return a


def tail(r):
    """both players, then 0x6b14d8's word, the marker, 0x415f60's word, the marker"""
    out = {'players': []}
    for _ in range(2):
        t = r.u32()
        if t == 1: out['players'].append(('human', human(r)))
        elif t == 3: out['players'].append(('ai', ai(r)))
        else: raise Bad(f'player type {t} at {r.pos - 4:#x}')
    out['g'] = r.u32()
    r.mark('after ui'); out['h'] = r.u32(); r.mark('end')
    return out


def find_human(d, start):
    """The human player's block (type word 1): parsed in full, it must end exactly
    where the file's closing words begin (a word, two markers, a word, a marker)."""
    end = len(d) - 20
    r = rebsave.Reader(d)
    def closes(pos):
        r.pos = pos
        r.u32(); r.mark('after ui'); r.mark('root'); r.u32(); r.mark('end')
        return r.pos == len(d)
    r.pos = start
    t0 = r.u32()
    if t0 == 1:
        h = human(r)
        if r.u32() != 3: raise Bad('the second player is not the AI')
        if not closes(end): raise Bad('the file does not close where expected')
        return h, 'first'
    if t0 != 3: raise Bad(f'first player type {t0}')
    for p in range(start + 4, end - 8):
        if struct.unpack_from('<I', d, p)[0] != 1:
            continue
        r.pos = p + 4
        try:
            h = human(r)
        except (Bad, rebsave.SaveError, struct.error, IndexError, UnicodeDecodeError):
            continue
        if r.pos == end:
            try:
                if closes(end): return h, 'second'
            except rebsave.SaveError:
                continue
    raise Bad('no human player block found')


if __name__ == '__main__':
    d = open(sys.argv[1], 'rb').read()
    rd, g = rebsave.parse(d)
    try:
        h, where = find_human(d, rd.pos)
    except Bad as e:
        print('FAILED:', e); sys.exit(1)
    print('human player', where, 'side', h['base']['side'], '- queued messages', sum(len(x['items']) for x in h['log']))
    for k in ('win1', 'win2', 'win3'):
        for w in h['screens'][k]:
            print(f"  {k} window {w['type']:#x} posted tick {w.get('b0', [0, 0, 0])[2]}: {w.get('s1')!r}")
            print('     ', repr(w.get('s2')))
