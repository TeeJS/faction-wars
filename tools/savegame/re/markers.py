import struct, sys
from tok import SG, FAMN, fmt
def markers(b):
    hits = []
    for p in range(0, len(b) - 3):
        v = struct.unpack_from('<I', b, p)[0]
        if v == p: hits.append(p)
    return hits
if __name__ == '__main__':
    b = open(SG + sys.argv[1], 'rb').read()
    h = markers(b)
    for i, p in enumerate(h):
        nxt = h[i+1] if i + 1 < len(h) else len(b)
        w = struct.unpack_from('<6I', b, p)
        print(f'{p:06x} len={nxt-p:6d} ' + ' '.join(fmt(x) for x in w[1:]))
