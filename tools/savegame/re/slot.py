import rx, vt
RUNS = vt.vtables()
def slot(vtva, idx):
    for va, s in RUNS.items():
        if va <= vtva < va + 4 * len(s):
            k = (vtva - va) // 4 + idx
            return s[k] if k < len(s) else None
