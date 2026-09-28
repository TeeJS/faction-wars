import rx, re, sys, slot
def this_vtables(f, depth=3):
    """vtables stored at [this+0] in execution order (ecx=this ctor chain)"""
    out = []; thisreg = 'ecx'; regs = {'ecx'}
    for i in rx.body(f, 0x600):
        m, o = i.mnemonic, i.op_str
        mm = re.match(r'(\w+), (\w+)$', o) if m == 'mov' else None
        if mm and mm.group(2) in regs: regs.add(mm.group(1))
        mv = re.match(r'dword ptr \[(\w+)\], (0x[0-9a-f]+)$', o)
        if m == 'mov' and mv and mv.group(1) in regs: out.append(int(mv.group(2), 16))
        if m == 'call' and o.startswith('0x') and depth:
            # thiscall with ecx still this?
            out += this_vtables(int(o, 16), depth - 1) if 'ecx' in regs else []
        if m in ('mov', 'lea') and o.startswith('ecx,') and not (mm and mm.group(2) in regs): regs.discard('ecx')
    return out
def factory_vt(fac):
    """factory = new(size); ctor(this). return final vtable"""
    b = rx.body(fac, 0x400)
    size = None; ctor = None
    for k, i in enumerate(b):
        if i.mnemonic == 'push' and b[k+1].mnemonic == 'call' and b[k+1].op_str == '0x618b70': size = i.op_str
        if i.mnemonic == 'call' and i.op_str.startswith('0x') and i.op_str not in ('0x618b70', '0x619730'): ctor = int(i.op_str, 16); break
    vts = this_vtables(ctor) if ctor else []
    return size, ctor, vts
if __name__ == '__main__':
    for a in sys.argv[1:]:
        s, c, v = factory_vt(int(a, 16))
        print(a, 'size', s, 'ctor', c and hex(c), 'vtables', [hex(x) for x in v], 'save(+8)', hex(slot.slot(v[-1], 2)) if v else None, 'load(+4)', hex(slot.slot(v[-1], 1)) if v else None)
