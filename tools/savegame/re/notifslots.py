import slot, fieldnames, sys
def notif_slots(vtab, n=260):
    out = []
    for k in range(n):
        f = slot.slot(vtab, k)
        if not f: break
        nm = fieldnames.names_in(f)
        if nm: out.append((k * 4, f, nm))
    return out
if __name__ == '__main__':
    for off, f, nm in notif_slots(int(sys.argv[1], 16)):
        print(f'+{off:#05x} {f:#x} {nm}')
