import sys
import mif

with open(sys.argv[1]) as f:
    mem = mif.load(f)


vals = []
for m in mem:
    m = list(reversed(m))
    for i in range(0, len(m), 8):
        bits = m[i:i+8]
        val = 0
        for b in bits:
            if b:
                val = (val * 2) + 1
            else:
                val = (val * 2)
        vals.append(val)

with open(sys.argv[2], 'wb') as f:
    f.write(bytes(vals))


