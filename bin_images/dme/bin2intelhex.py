#!/usr/bin/env python3
"""
Convert a raw binary file into an Intel HEX file, using 16-byte
data records (type 00), with extended linear address (type 04)
records emitted whenever the 64KB segment changes.

Usage: python3 bin_to_ihex.py input.bin output.hex [start_address_hex]
"""

import sys
from pathlib import Path

if len(sys.argv) not in (3, 4):
    print("Usage: python3 bin_to_ihex.py input.bin output.hex [start_address_hex]")
    sys.exit(1)

infile  = Path(sys.argv[1])
outfile = Path(sys.argv[2])
start_addr = int(sys.argv[3], 16) if len(sys.argv) == 4 else 0x0000

data = infile.read_bytes()
if not data:
    print("Input file is empty.")
    sys.exit(1)

def ihex_checksum(byte_list):
    return ((~(sum(byte_list) & 0xFF) + 1) & 0xFF)

out = []
last_upper = None

for offset in range(0, len(data), 16):
    addr = start_addr + offset
    chunk = list(data[offset:offset + 16])
    count = len(chunk)

    low_addr = addr & 0xFFFF
    upper_addr = (addr >> 16) & 0xFFFF

    # Emit extended linear address record when the upper 16 bits change
    if upper_addr != last_upper:
        rec = [0x02, 0x00, 0x00, 0x04, (upper_addr >> 8) & 0xFF, upper_addr & 0xFF]
        chk = ihex_checksum(rec)
        out.append(":" + "".join(f"{b:02X}" for b in rec) + f"{chk:02X}")
        last_upper = upper_addr

    rec = [count, (low_addr >> 8) & 0xFF, low_addr & 0xFF, 0x00] + chunk
    chk = ihex_checksum(rec)
    out.append(":" + "".join(f"{b:02X}" for b in rec) + f"{chk:02X}")

# End-of-file record
out.append(":00000001FF")

outfile.write_text("\n".join(out) + "\n")
print(f"Converted {len(data)} bytes -> {outfile}")
