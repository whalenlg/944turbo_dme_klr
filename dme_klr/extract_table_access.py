import sys
import re
import subprocess

def is_nonzero(val: str) -> bool:
    """
    Returns True if the logic bitstring is non-zero.
    Strips leading zeroes and handles bus states (e.g., '0000').
    """
    cleaned = val.strip().lower().lstrip('0')
    if not cleaned:
        return False
    return set(cleaned) <= {'1'}

def extract_signals_on_trigger(fst_path: str, signal_names: list[str], trigger_signal: str):
    # 1. Start fst2vcd process streaming VCD format to stdout
    try:
        proc = subprocess.Popen(
            ["fst2vcd", fst_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True
        )
    except FileNotFoundError:
        print("Error: 'fst2vcd' utility not found. Install GTKWave (e.g. `brew install gtkwave`).", file=sys.stderr)
        sys.exit(1)

    id_to_name = {}
    current_values = {sig: "0" for sig in signal_names}

    # Regex patterns for VCD token matching
    var_pattern = re.compile(r'^\$var\s+\w+\s+\d+\s+(\S+)\s+(.+?)\s+\$end')
    time_pattern = re.compile(r'^#(\d+)')
    scalar_pattern = re.compile(r'^([01xzX-Z])(\S+)$')
    vector_pattern = re.compile(r'^[bB]([01xzX-Z]+)\s+(\S+)$')

    current_time = 0

    # 2. Line-by-line stream parser
    for line in proc.stdout:
        line = line.strip()
        if not line:
            continue

        # Header Phase: Map VCD symbol identifiers to target signal names
        if line.startswith("$var"):
            match = var_pattern.match(line)
            if match:
                vcd_id, full_name = match.group(1), match.group(2)
                for target in signal_names:
                    if full_name == target or full_name.endswith("." + target):
                        id_to_name[vcd_id] = target
            continue

        # Data Phase: Time step marker
        if line.startswith("#"):
            t_match = time_pattern.match(line)
            if t_match:
                current_time = int(t_match.group(1))
            continue

        # Data Phase: Value changes
        sig_id = None
        val = None

        if line.startswith(('b', 'B')):
            v_match = vector_pattern.match(line)
            if v_match:
                val, sig_id = v_match.group(1), v_match.group(2)
        else:
            s_match = scalar_pattern.match(line)
            if s_match:
                val, sig_id = s_match.group(1), s_match.group(2)

        # 3. Update signal state and check trigger condition
        if sig_id and sig_id in id_to_name:
            sig_name = id_to_name[sig_id]
            current_values[sig_name] = val

            # Check if u_dme.u_vcd.data_from_rom is non-zero
            trigger_val = current_values.get(trigger_signal, "0")
            if is_nonzero(trigger_val):
                formatted = " | ".join(f"{k}: {v}" for k, v in current_values.items())
                print(f"Time: {current_time:10d} ns -> {formatted}")

    proc.stdout.close()
    proc.wait()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 extract_table_access.py <path_to_fst_file>")
        sys.exit(1)

    fst_file = sys.argv[1]

    # Target 8051 DME signals to extract
    TARGET_SIGNALS = [
        "u_dme.i8051_top.u_cpu.pc",
        "u_dme.i8051_top.u_cpu.addr_bus",
        "u_dme.u_vcd.data_from_rom"
    ]

    # Gate output on ROM data being active
    TRIGGER_SIGNAL = "u_dme.u_vcd.data_from_rom"

    extract_signals_on_trigger(fst_file, TARGET_SIGNALS, TRIGGER_SIGNAL)
