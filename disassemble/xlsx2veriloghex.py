import pandas as pd
import sys
import os

def parse_addr(addr_str):
    try:
        # Clean string "0x0000:" to integer
        clean = str(addr_str).lower().replace('0x', '').replace(':', '').strip()
        return int(clean, 16)
    except:
        return None

def main():
    if len(sys.argv) < 3:
        print("Usage: python extract_labels.py <input.xlsx> <output.hex>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found")
        sys.exit(1)

    print(f"Reading {input_file}...")
    # Loading 'ASM' sheet
    df = pd.read_excel(input_file, sheet_name='ASM')
    
    # Map existing addresses to their labels
    df['addr_int'] = df['Addr'].apply(parse_addr)
    df = df.dropna(subset=['addr_int'])
    df['addr_int'] = df['addr_int'].astype(int)
    addr_to_label = dict(zip(df['addr_int'], df['labels']))
    
    max_addr = int(df['addr_int'].max())
    output_lines = []
    
    # Process every address from 0 to max_addr
    for addr in range(0, max_addr + 1):
        label = addr_to_label.get(addr)
        
        # Determine 20-character string (label padded with spaces or 20 spaces)
        if pd.isna(label) or str(label).strip().lower() == 'nan':
            content_str = " " * 20
        else:
            content_str = str(label).replace(':', '').strip().ljust(20)
        
        # Slice to ensure exactly 20 chars, then convert to hex string without spaces
        hex_content = "".join(f"{ord(c):02x}" for c in content_str[:20])
        output_lines.append(hex_content)

    # Write only the hex content lines to the file
    with open(output_file, 'w') as f:
        f.write('\n'.join(output_lines))
    
    print(f"Success! Wrote {len(output_lines)} lines to {output_file}")

if __name__ == '__main__':
    main()
