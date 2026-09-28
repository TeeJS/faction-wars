# REBEXE helper: VA<->offset, disassembly, call xrefs.
import pefile, capstone, struct, sys, os, pickle
EXE = r'C:\Program Files (x86)\GOG Galaxy\Games\Star Wars - Rebellion\REBEXE.EXE'
pe = pefile.PE(EXE, fast_load=True)
BASE = pe.OPTIONAL_HEADER.ImageBase
DATA = open(EXE, 'rb').read()
SECS = [(BASE + s.VirtualAddress, s.Misc_VirtualSize, s.PointerToRawData, s.SizeOfRawData, s.Name.rstrip(b'\0').decode()) for s in pe.sections]
def off(va):
    for v, vs, r, rs, n in SECS:
        if v <= va < v + max(vs, rs): return r + (va - v)
    return None
def u32(va): return struct.unpack_from('<I', DATA, off(va))[0]
def cstr(va, n=200):
    o = off(va); e = DATA.index(b'\0', o); return DATA[o:e][:n].decode('latin1')
md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32); md.detail = False
TEXT = [s for s in SECS if s[4] == '.text'][0]
def dis(va, n=400, stop_ret=True):
    o = off(va); out = []
    for ins in md.disasm(DATA[o:o+n*8], va):
        out.append(ins)
        if len(out) >= n: break
        if stop_ret and ins.mnemonic == 'ret': break
        if stop_ret and ins.mnemonic == 'int3': break
    return out
def pr(va, n=400, stop_ret=True):
    for i in dis(va, n, stop_ret):
        print(f'{i.address:08x}  {i.mnemonic:6} {i.op_str}')
_X = None
def xrefs():
    """map target -> [callsites] for E8 rel32 calls and E9 jmps in .text"""
    global _X
    if _X is not None: return _X
    cache = os.path.join(os.path.dirname(__file__), 'xrefs.pkl')
    if os.path.exists(cache):
        _X = pickle.load(open(cache, 'rb')); return _X
    v, vs, r, rs, n = TEXT
    X = {}
    for i in range(r, r + rs - 5):
        op = DATA[i]
        if op in (0xE8, 0xE9):
            t = (v + (i - r) + 5 + struct.unpack_from('<i', DATA, i + 1)[0]) & 0xffffffff
            if v <= t < v + vs:
                X.setdefault(t, []).append((v + (i - r), 'call' if op == 0xE8 else 'jmp'))
    pickle.dump(X, open(cache, 'wb')); _X = X; return X
def callers(t): return xrefs().get(t, [])
def imm_refs(value):
    """find instructions embedding a 32-bit immediate/address (push/mov etc.)"""
    b = struct.pack('<I', value); v, vs, r, rs, n = TEXT; res = []; i = DATA.find(b, r)
    while 0 <= i < r + rs:
        res.append(v + (i - r)); i = DATA.find(b, i + 1)
    return res
if __name__ == '__main__':
    pr(int(sys.argv[1], 16), int(sys.argv[2]) if len(sys.argv) > 2 else 400)

import bisect
_STARTS = None
def func_starts():
    global _STARTS
    if _STARTS is None: _STARTS = sorted(xrefs().keys())
    return _STARTS
def func_of(va):
    s = func_starts(); i = bisect.bisect_right(s, va) - 1
    return s[i] if i >= 0 else None
def body(start, maxlen=0x4000):
    """disassemble from start to the next known function start"""
    s = func_starts(); i = bisect.bisect_right(s, start)
    end = s[i] if i < len(s) else start + maxlen
    end = min(end, start + maxlen)
    o = off(start)
    return list(md.disasm(DATA[o:o + (end - start)], start))
def prb(start, maxlen=0x4000):
    for i in body(start, maxlen):
        print(f'{i.address:08x}  {i.mnemonic:6} {i.op_str}')

def body(start, maxlen=0x6000):
    """linear disassembly until a ret that no earlier branch jumps past"""
    o = off(start); out = []; far = start
    for i in md.disasm(DATA[o:o + maxlen], start):
        out.append(i)
        m = i.mnemonic
        if m.startswith('j') and i.op_str.startswith('0x'):
            t = int(i.op_str, 16)
            if t > far: far = t
        if m == 'ret' and i.address >= far: break
        if m == 'jmp' and i.address >= far and not i.op_str.startswith('0x'): break
    return out
def prb(start, maxlen=0x6000):
    for i in body(start, maxlen):
        if i.mnemonic == 'nop': continue
        print(f'{i.address:08x}  {i.mnemonic:6} {i.op_str}')

def body(start, maxlen=0x6000):
    o = off(start); out = []; far = start
    for i in md.disasm(DATA[o:o + maxlen], start):
        out.append(i)
        m = i.mnemonic
        if m.startswith('j') and i.op_str.startswith('0x'):
            t = int(i.op_str, 16)
            tail = (m == 'jmp') and (t < start or t > i.address + 0x800)
            if not tail and t > far: far = t
            if tail and i.address >= far: break
        if m == 'ret' and i.address >= far: break
        if m == 'jmp' and not i.op_str.startswith('0x') and i.address >= far: break
        if m == 'int3' and i.address >= far: break
    return out
