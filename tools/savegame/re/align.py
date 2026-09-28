import allsetters, notifslots, slot, collections, sys
S = allsetters.scan()
def align(vtab, name):
    ns = {off: nm for off, f, nm in notifslots.notif_slots(vtab, 300)}
    # setters whose first fired slot exists in this vtable
    cand = collections.Counter()
    for f, stores, slots in S:
        for s in slots[:1]:
            for n in ns:
                if 0 < n - s < 0x200: cand[n - s] += 1
    return ns, cand
if __name__ == '__main__':
    vtab = int(sys.argv[1], 16)
    ns, cand = align(vtab, '')
    print('top deltas', cand.most_common(5))
    d = int(sys.argv[2], 16) if len(sys.argv) > 2 else cand.most_common(1)[0][0]
    rows = []
    for f, stores, slots in S:
        s = slots[0]
        if s + d in ns:
            rows.append((s, f, stores, ns[s + d]))
    for s, f, stores, nm in sorted(rows):
        print(f'slot {s:#x} setter {f:#x} stores {stores} -> {nm}')
