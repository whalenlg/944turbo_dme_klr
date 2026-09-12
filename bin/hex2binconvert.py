#!/usr/bin/env python3
"""
Convert any Intel HEX file to 16-byte records (record type 00 only).
All addresses and extended linear address records are preserved.
"""

import sys
from pathlib import Path

if len(sys.argv) != 3:
    print("Usage: python3 ihex_to_16byte.py input.hex output.hex")
    sys.exit(1)

infile  = Path(sys.argv[1])
outfile = Path(sys.argv[2])

lines = infile.read_text().splitlines()

# Memory buffer (address → byte)
memory = {}
upper = 0    # extended linear address (upper 16 bits)

for line in lines:
    if not line.startswith(":"):
        continue

    count   = int(line[1:3],16)
    addr    = int(line[3:7],16)
    rectype = int(line[7:9],16)
    data    = bytes.fromhex(line[9:9+count*2])

    # Data record
    if rectype == 0x00:
        base = (upper << 16) | addr
        for i,b in enumerate(data):
            memory[base + i] = b

    # Extended linear address record
    elif rectype == 0x04:
        upper = int(line[9:13],16)

    # End record ignored here (rebuilt later)
    elif rectype == 0x01:
        pass

# Produce sorted linear address range
if not memory:
    print("No data records found.")
    sys.exit(1)

start = min(memory.keys())
end   = max(memory.keys())

# Output data in 16-byte records
out = []

def ihex_checksum(byte_list):
    return ((~(sum(byte_list) & 0xFF) + 1) & 0xFF)

# Emit 16-byte records
for addr in range(start, end + 1, 16):
    chunk = [memory.get(a, 0xFF) for a in range(addr, addr + 16)]
    count = 16

    # Compute low 16-bit address for the record
    low_addr = addr & 0xFFFF

    # Compute upper address for extended linear block boundary
    upper_addr = (addr >> 16) & 0xFFFF

    # Emit extended linear address record when needed
    if addr == start or (addr >> 16) != ((addr - 16) >> 16):
        rec = [0x02, 0x00, 0x00, 0x04, (upper_addr >> 8) & 0xFF, upper_addr & 0xFF]
        chk = ihex_checksum(rec)
        out.append(":" + "".join(f"{b:02X}" for b in rec) + f"{chk:02X}")

    # Emit 16-byte data record
    rec = [count, (low_addr >> 8) & 0xFF, low_addr & 0xFF, 0x00] + chunk
    chk = ihex_checksum(rec)
    out.append(":" + "".join(f"{b:02X}" for b in rec) + f"{chk:02X}")

# End-of-file record
out.append(":00000001FF")

# Write output
outfile.write_text("\n".join(out))
print(f"Converted HEX written to: {outfile}")

