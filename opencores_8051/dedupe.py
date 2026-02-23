#!/usr/bin/env python3

import sys

COL_INDEX = 5  # column #6 (0-based)

prev_key = None

for line in sys.stdin:
    stripped = line.rstrip("\n")
    fields = stripped.split()

    # If line doesn't have column 6, pass it through
    if len(fields) <= COL_INDEX:
        sys.stdout.write(line)
        prev_key = None
        continue

    key = fields[COL_INDEX]

    # Emit line only if column-6 value changed
    if key != prev_key:
        sys.stdout.write(line)

    prev_key = key

