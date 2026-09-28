import rx, re, cg, pickle, os
G = cg.callgraph()
STORE = re.compile(r'(dword|word|byte) ptr \[(e(?:si|di|bx|cx|bp)) \+ (0x[0-9a-f]+)\], (\w+)$')
def scan():
    if os.path.exists('setters.pkl'): return pickle.load(open('setters.pkl', 'rb'))
    out = []
    for f in sorted(G):
        b = rx.body(f, 0x200)
        if not (4 < len(b) < 80): continue
        thisreg = {'ecx'}; stores = []; slots = []
        for i in b:
            o = i.op_str
            if i.mnemonic == 'mov' and re.match(r'(e\w\w), ecx$', o): thisreg.add(o.split(',')[0])
            m = STORE.match(o) if i.mnemonic in ('mov', 'or', 'and') else None
            if m and m.group(2) in thisreg: stores.append((i.mnemonic, m.group(1), m.group(3)))
            mv = re.match(r'dword ptr \[e[a-d]x \+ (0x[0-9a-f]{3})\]$', o) if i.mnemonic == 'call' else None
            if mv and stores: slots.append(int(mv.group(1), 16))
        if stores and slots: out.append((f, stores, slots))
    pickle.dump(out, open('setters.pkl', 'wb'))
    return out
if __name__ == '__main__':
    s = scan(); print(len(s))
