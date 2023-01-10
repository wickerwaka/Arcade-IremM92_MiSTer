import sys
import os.path

pairs = sys.argv[1:-1]
output = sys.argv[-1]

if os.path.exists(output):
    print("ERROR: output exists")
    sys.exit(-1)

with open(output, "wb") as fp:
    for idx in range(0, len(pairs), 2):
        low = open(pairs[idx], "rb").read()
        high = open(pairs[idx + 1], "rb").read()

        for l, h in zip(low, high):
            fp.write(bytes([l]))
            fp.write(bytes([h]))

