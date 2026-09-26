import pandas as pd
import sys
import os

def parse_addr(addr_str):
    try:
        # Converts hex address (e.g. '0x0000:') to integer
        clean = str(addr_str).lower().replace('0x', '').replace(':', '').strip()
        return int(clean, 16)
    except:
        return None

def main():
    if len(sys.argv) < 2:
        print("Usage: python extract_asm_columns.py <input.xlsx> [array_size]")
        sys.exit(1)

    input_file = sys.argv[1]
    # Default 8192 matches the DME 8051's opcode/instr/ops/opsnums[0:8191]
    # (vcd.v). The KLR side's i8048 core has a smaller 4096-entry address
    # space (klr_vcd.v) — klr/run_klr_regression passes 4096 explicitly.
    array_size_arg = int(sys.argv[2]) if len(sys.argv) > 2 else 8192

    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found")
        sys.exit(1)

    try:
        print(f"Reading {input_file} sheet 'ASM'...")
        df = pd.read_excel(input_file, sheet_name='ASM')
        
        # Parse the address column
        df['addr_int'] = df['Addr'].apply(parse_addr)
        df = df.dropna(subset=['addr_int'])
        df['addr_int'] = df['addr_int'].astype(int)
        max_addr = int(df['addr_int'].max())
        
        # Targeted columns
        columns_to_extract = ['Opcode Ins', 'instr', 'operand_mapped', 'operands numeric']
        WIDTH = 20
        # Iterate through every address up to ARRAY_SIZE-1 (not just
        # max_addr) so each output file always has exactly as many words as
        # the Verilog array it feeds (opcode/instr/ops/opsnums[0:ARRAY_SIZE-1]
        # in vcd.v/klr_vcd.v) — otherwise $readmemh warns "Not enough words
        # in the file for the requested range" for every address beyond
        # max_addr. Addresses past max_addr just get the same blank filler
        # as any other unlabeled address.
        ARRAY_SIZE = array_size_arg
        if max_addr >= ARRAY_SIZE:
            print(f"WARNING: max address 0x{max_addr:04x} exceeds the "
                  f"{ARRAY_SIZE}-word array size — output will be truncated, "
                  f"increase ARRAY_SIZE (and the matching Verilog array "
                  f"bounds in vcd.v) to fix.")

        for col in columns_to_extract:
            # Create a dictionary mapping for quick lookup
            addr_map = dict(zip(df['addr_int'], df[col]))
            output_lines = []

            for addr in range(0, ARRAY_SIZE):
                val = addr_map.get(addr)
                
                # If missing/empty, use spaces. Otherwise pad or truncate to 20.
                if pd.isna(val) or str(val).strip().lower() == 'nan':
                    content_str = " " * WIDTH
                else:
                    content_str = str(val).strip().ljust(WIDTH)[:WIDTH]
                
                # Convert string to hex without spaces
                hex_content = "".join(f"{ord(c):02x}" for c in content_str)
                output_lines.append(hex_content)
                
            # File name conversion: "Opcode Ins" -> "asm_opcode_ins.hex"
            file_name = f"asm_{col.replace(' ', '_').lower()}.hex"
            with open(file_name, 'w') as f:
                f.write('\n'.join(output_lines))
            print(f"Successfully created: {file_name}")

        print("All extractions complete.")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == '__main__':
    main()
