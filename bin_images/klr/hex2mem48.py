#!/usr/bin/env python3
import sys

# -h / --help: print usage and exit before anything else runs.
if __name__ == '__main__' and any(a in ('-h', '--help') for a in sys.argv[1:]):
    print(('usage: hex2mem48.py <input.hex> <output.mem>  (Intel HEX to a 4 KB $readmemh image)').strip())
    sys.exit(0)

def convert(infile, outfile):
    mem = ["00"] * 4096 
    with open(infile, 'r') as f:
        for line in f:
            if line[0] != ':': continue
            count = int(line[1:3], 16)
            addr = int(line[3:7], 16)
            if line[7:9] == '00':
                for i in range(count):
                    mem[addr+i] = line[9+i*2 : 11+i*2]
    with open(outfile, 'w', newline='\n') as f:
        f.write("\n".join(mem))

if __name__ == "__main__":
    convert(sys.argv[1], sys.argv[2])
