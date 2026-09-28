"""bit setters: functions calling the bit helper 0x53a640(mask, value, &field) then firing a vtable slot"""
import rx, re, cg, sys
G = cg.callgraph()
def run(lo, hi):
    out = []
    for f in sorted(G):
        if not (lo <= f < hi): continue
        b = rx.body(f, 0x200)
        if len(b) > 80: continue
        calls = [i for i in b if i.mnemonic == 'call']
        if not any(c.op_str == '0x53a640' for c in calls): continue
        # mask = the push right before call 0x53a640
        mask = None; field = None
        for k, i in enumerate(b):
            if i.mnemonic == 'call' and i.op_str == '0x53a640':
                pushes = [j for j in b[max(0, k-5):k] if j.mnemonic == 'push']
                mask = pushes[-1].op_str if pushes else None
                leas = [j.op_str for j in b[max(0, k-6):k] if j.mnemonic == 'lea']
                field = leas[-1] if leas else None
                break
        slots = [m.group(1) for i in b if i.mnemonic == 'call' for m in [re.match(r'dword ptr \[e[a-d]x \+ (0x[0-9a-f]{2,3})\]$', i.op_str)] if m]
        out.append((f, field, mask, slots[:1]))
    return out
if __name__ == '__main__':
    for f, field, mask, sl in run(int(sys.argv[1], 16), int(sys.argv[2], 16)):
        print(hex(f), field, 'mask', mask, 'fires', sl)
