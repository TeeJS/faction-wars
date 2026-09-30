import rx, re, sys
def vt_of(ctor):
    vts=[]
    for i in rx.body(ctor):
        m=re.match(r'dword ptr \[(e\w\w)\], (0x[0-9a-f]+)$', i.op_str)
        if i.mnemonic=='mov' and m and 0x650000<=int(m.group(2),16)<0x6a0000: vts.append(int(m.group(2),16))
    return vts[-1] if vts else None
def node_of_loader(ld, depth=0):
    """first 'new' followed by a ctor in the loader or a callee (2 levels)"""
    calls=[i.op_str for i in rx.body(ld) if i.mnemonic=='call']
    if '0x618b70' in calls:
        k=calls.index('0x618b70')
        for c in calls[k+1:k+3]:
            if c.startswith('0x'): return int(c,16)
    if depth < 2:
        for c in calls:
            if c.startswith('0x'):
                t=int(c,16)
                if t in (0x5f4d90,0x5f4dd0,0x4ece30,0x619730,0x4ece90,0x5f5440): continue
                r=node_of_loader(t, depth+1)
                if r: return r
    return None
for a in sys.argv[1:]:
    vt=int(a,16); ld=rx.u32(vt+0x10)
    ctor=node_of_loader(ld)
    nvt=vt_of(ctor) if ctor else None
    print(hex(vt), 'load', hex(ld), 'node ctor', hex(ctor) if ctor else None, 'node vt', hex(nvt) if nvt else None,
          'node save(0x10)', hex(rx.u32(nvt+0x10)) if nvt else None, 'slot14', hex(rx.u32(nvt+0x14)) if nvt else None)
