import pandas as pd
import sys
import os

def parse_hex(val):
    try:
        # Converts hex address (e.g. '00', 'AF') to integer
        return int(str(val).strip(), 16)
    except:
        return None

def main():
    if len(sys.argv) < 3:
        print("Usage: python extract_bit_mem.py <input.xlsx> <output.hex>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    if not os.path.exists(input_file):
        print(f"Error: {input_file} not found")
        sys.exit(1)

    try:
        print(f"Reading {input_file} sheet 'bit_mem'...")
        df = pd.read_excel(input_file, sheet_name='bit_mem')
        
        # 1. Parse 'hex_bit_addr' to integers
        df['addr_int'] = df['hex_bit_addr'].apply(parse_hex)
        df = df.dropna(subset=['addr_int'])
        df['addr_int'] = df['addr_int'].astype(int)
        
        # 2. Map addresses to 'Description'
        addr_to_msg = dict(zip(df['addr_int'], df['Description']))
        
        # 3. Iterate through all bit addresses up to the maximum found
        max_addr = int(df['addr_int'].max())
        output_lines = []
        WIDTH = 32 
        
        for addr in range(0, max_addr + 1):
            msg = addr_to_msg.get(addr)
            
            # Fill missing/empty messages with spaces
            if pd.isna(msg) or str(msg).strip().lower() == 'nan':
                content_str = " " * WIDTH
            else:
                # Pad/truncate message to exactly 32 characters
                content_str = str(msg).strip().ljust(WIDTH)[:WIDTH]
            
            # Convert string to hex without spaces
            hex_data = "".join(f"{ord(c):02x}" for c in content_str)
            output_lines.append(hex_data)
            
        # 4. Save file
        with open(output_file, 'w') as f:
            f.write('\n'.join(output_lines))
            
        print(f"Success! Processed {len(output_lines)} bit addresses to {output_file}")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == '__main__':
    main()
