import rx, re, slot, vt2, ctor, sys
V = vt2.split()
def ctors_of(vt):
    """functions that store vt at [reg] (constructors / destructors)"""
    out = []
    for a in rx.imm_refs(vt):
        ins = rx.dis(a - 2, 1, False)
        f = rx.func_of(a)
        out.append(f)
    return sorted(set(out))
def members(f, offs):
    """in ctor f, find for each member offset: vtable stored at [esi+off] or ctor called with lea ecx,[esi+off]"""
    b = rx.body(f, 0x1000); res = {}
    for k, i in enumerate(b):
        for off in offs:
            pat = f'+ {off:#x}]'
            if i.mnemonic == 'mov' and pat in i.op_str and re.search(r', 0x[0-9a-f]{6}$', i.op_str):
                v = int(i.op_str.split(', ')[-1], 16)
                if v in V: res.setdefault(off, []).append(('vt', hex(v)))
            if i.mnemonic == 'lea' and i.op_str.startswith('ecx,') and pat in i.op_str:
                for j in b[k+1:k+4]:
                    if j.mnemonic == 'call' and j.op_str.startswith('0x'):
                        t = int(j.op_str, 16); vts = ctor.this_vtables(t)
                        res.setdefault(off, []).append(('ctor', hex(t), [hex(x) for x in vts]))
                        break
    return res
if __name__ == '__main__':
    vt = int(sys.argv[1], 16); offs = [int(x, 16) for x in sys.argv[2:]]
    for f in ctors_of(vt):
        print(hex(f), members(f, offs))

def members_deep(f, offs, depth=4, seen=None):
    seen = seen if seen is not None else set()
    if f in seen: return {}
    seen.add(f)
    res = members(f, offs)
    b = rx.body(f, 0x1000)
    regs = {'ecx'}
    for i in b:
        o = i.op_str
        if i.mnemonic == 'mov' and re.match(r'(\w+), (\w+)$', o) and o.split(', ')[1] in regs: regs.add(o.split(', ')[0])
        if i.mnemonic == 'call' and o.startswith('0x') and 'ecx' in regs and depth:
            for k, v in members_deep(int(o, 16), offs, depth - 1, seen).items(): res.setdefault(k, []).extend(v)
        if i.mnemonic in ('mov', 'lea') and o.startswith('ecx,') and not (i.mnemonic == 'mov' and o.split(', ')[1] in regs): regs.discard('ecx')
    return res
