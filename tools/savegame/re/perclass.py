import allsetters, notifslots, collections, sys
S = allsetters.scan()
def run(vtab, lo, hi, delta=None):
    ns = {off: nm for off, f, nm in notifslots.notif_slots(vtab, 400)}
    mine = [(f, st, sl) for f, st, sl in S if lo <= f < hi]
    if delta is None:
        c = collections.Counter(n - sl[0] for f, st, sl in mine for n in ns if 0 < n - sl[0] < 0x300)
        delta = c.most_common(1)[0][0] if c else 0
    rows = []
    for f, st, sl in mine:
        nm = ns.get(sl[0] + delta)
        rows.append((sl[0], f, st, nm))
    return delta, sorted(rows), ns
if __name__ == '__main__':
    vtab, lo, hi = (int(x, 16) for x in sys.argv[1:4])
    d, rows, ns = run(vtab, lo, hi, int(sys.argv[4], 16) if len(sys.argv) > 4 else None)
    print('delta', hex(d), 'notif slots', {hex(k): v[0] for k, v in sorted(ns.items())})
    for s, f, st, nm in rows: print(f'  slot {s:#x} {f:#x} {st} -> {nm}')
