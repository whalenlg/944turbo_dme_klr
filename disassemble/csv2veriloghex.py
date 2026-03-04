#!/usr/bin/env python3
import csv
import sys

WORD_BYTES = 16

def parse_addr(s):
    s = s.strip().rstrip(":")
    s = s.strip().lstrip('\ufeff')
    s=s.replace("0x","")
    return int(s,16)

def make_word(text):
    """Return exactly 16 bytes of ASCII padded with spaces."""
    if text is None:
        text = ""
    text = str(text).rstrip("\r\n")

    b = text.encode("ascii", errors="replace")

    if len(b) < WORD_BYTES:
        b = b.ljust(WORD_BYTES, b' ')
    else:
        b = b[:WORD_BYTES]

    return b


def main(csvfile, hexout):
    entries = {}

    # Read CSV rows
    with open(csvfile, newline='') as f:
        r = csv.reader(f)
        for row in r:
            if not row or len(row[0].strip()) == 0:
                continue
            addr = parse_addr(row[0])
            text = row[1] if len(row) > 1 else ""
            entries[addr] = make_word(text)

    if not entries:
        print("No valid rows.")
        return

    # Determine min/max continuous range
    min_addr = min(entries.keys())
    max_addr = max(entries.keys())

    # Write hex file
    with open(hexout, "w") as f:
        for addr in range(min_addr, max_addr + 1):
            if addr in entries:
                word = entries[addr]
            else:
                # missing → 16 spaces
                word = b' ' * WORD_BYTES

            f.write(word.hex().upper() + "\n")

    print(f"Wrote {hexout}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: csv2veriloghex <input.csv> <output.hex>")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])

