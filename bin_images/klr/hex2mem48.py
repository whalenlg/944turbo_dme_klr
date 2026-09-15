import sys

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
    with open(outfile, 'w') as f:
        f.write("\n".join(mem))

if __name__ == "__main__":
    convert(sys.argv[1], sys.argv[2])
