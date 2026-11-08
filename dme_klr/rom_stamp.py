#!/usr/bin/env python3
"""
rom_stamp.py: the ROM images a run used, as dash.log lines.

    python3 rom_stamp.py <full sim log>

Reads the "DME: ROM loaded from <path>" / "KLR: ROM loaded from <path>"
lines that i8051_top.v and klr_top.v print at start, and prints

    DME: [ROM] <file name> sha=<16 hex digits> path=<path>
    KLR: [ROM] <file name> sha=<16 hex digits> path=<path>

sha is the start of the SHA-256 of the 8 KB image (bytes, not file name;
the same key live/map_graphs.py files its graphs under), or "unknown" when
the file can't be read. The run scripts put these at the top of every
.dash.log so the dashboard knows which ROM a log came from.
"""
import hashlib, os, re, sys

# -h / --help: print usage and exit before anything else runs.
if __name__ == '__main__' and any(a in ('-h', '--help') for a in sys.argv[1:]):
    print((__doc__).strip())
    sys.exit(0)

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'live'))
from map_graphs import load_image  # noqa: E402  (no matplotlib needed for this)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    seen = set()
    with open(sys.argv[1], errors='replace') as f:
        for line in f:
            m = re.match(r'^(DME|KLR): ROM loaded from (.+?)\s*$', line)
            if not m or m.group(1) in seen:
                continue
            seen.add(m.group(1))
            path = m.group(2)
            try:
                sha = hashlib.sha256(load_image(path)).hexdigest()[:16]
            except (OSError, ValueError):
                sha = 'unknown'
            print(f'{m.group(1)}: [ROM] {os.path.basename(path)} sha={sha} path={path}')
            if len(seen) == 2:
                break


if __name__ == '__main__':
    main()
