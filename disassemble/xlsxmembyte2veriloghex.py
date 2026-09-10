import pandas as pd
import sys
import os

def parse_hex(val):
    try:
        return int(str(val).strip(), 16)
    except:
        return None

def main():
    if len(sys.argv) < 3:
        print("Usage: python extract_byte_mem_32.py <input.xlsx> <output.hex>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found")
        sys.exit(1)

    try:
        df = pd.read_excel(input_file, sheet_name='byte_mem')
        
        # Parse hex addresses
        df['addr_int'] = df['hex addr'].apply(parse_hex)
        df = df.dropna(subset=['addr_int'])
        df['addr_int'] = df['addr_int'].astype(int)
        
        addr_to_desc = dict(zip(df['addr_int'], df['Description']))
        max_addr = int(df['addr_int'].max())
        
        output_lines = []
        WIDTH = 32 # 32 bytes wide
        
        for addr in range(0, max_addr + 1):
            desc = addr_to_desc.get(addr)
            
            # Handle empty or missing descriptions with spaces
            if pd.isna(desc) or str(desc).strip().lower() == 'nan':
                content_str = " " * WIDTH
            else:
                content_str = str(desc).strip().ljust(WIDTH)[:WIDTH]
            
            # Convert string to 64 hex characters
            hex_data = "".join(f"{ord(c):02x}" for c in content_str)
            output_lines.append(hex_data)
            
        with open(output_file, 'w') as f:
            f.write('\n'.join(output_lines))
            
        print(f"Success! Wrote {len(output_lines)} lines (32 bytes wide) to {output_file}")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == '__main__':
    main()
