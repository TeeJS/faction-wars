import rx, re, cg, sys
G = cg.callgraph()
def run(lo, hi, off):
    pat = f'+ {off}]'
    for f in sorted(G):
        if not (lo <= f < hi): continue
        b = rx.body(f, 0x200)
        if len(b) > 70: continue
        bits = []; slots = []
        for i in b:
            if pat in i.op_str and i.mnemonic in ('or', 'and', 'xor', 'mov', 'test'):
                bits.append(f'{i.mnemonic} {i.op_str}')
            mv = re.match(r'dword ptr \[e[a-d]x \+ (0x[0-9a-f]{3})\]$', i.op_str) if i.mnemonic == 'call' else None
            if mv: slots.append(mv.group(1))
        if bits and slots and any(x.startswith(('or', 'and', 'mov dword ptr [e')) for x in bits):
            print(hex(f), bits[:5], slots[:3])
run(int(sys.argv[1], 16), int(sys.argv[2], 16), sys.argv[3])
