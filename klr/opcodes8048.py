import pandas as pd
import argparse
import binascii

def text_to_left_padded_hex(excel_path, output_path, sheet_name="8048opcodes", char_width=32):
    try:
        # header=None tells pandas that the first row is NOT a header
        # If your Excel has a header you want to skip, use header=0 and skip it manually
        df = pd.read_excel(excel_path, sheet_name=sheet_name, header=None)
        
        # Target the 2nd column (index 1) for Mnemonics
        mnemonics = df.iloc[:, 1].astype(str)
        
        with open(output_path, 'w') as f:
            # i starts at 0 (Opcode 00)
            for i in range(256):
                # Check if the row exists in the spreadsheet
                if i < len(mnemonics):
                    clean_entry = mnemonics.iloc[i].strip()
                else:
                    clean_entry = "Illegal"
                
                # Truncate and Left-justify with spaces (ASCII 20)
                clean_entry = clean_entry[:char_width]
                padded_text = clean_entry.ljust(char_width, ' ')
                
                # Convert string to hex-encoded ASCII
                hex_val = binascii.hexlify(padded_text.encode('ascii')).decode('ascii')
                
                # Write flat hex line
                f.write(f"{hex_val}\n")
                
        print(f"Success! Row 1 (Index 0) is now mapped to Opcode 00.")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fix skew by reading Excel with no header.")
    parser.add_argument("-i", "--input", default="8048opcodes.xlsx", help="Input Excel file")
    parser.add_argument("-o", "--output", default="mnemonics.hex", help="Output .hex file")
    
    args = parser.parse_args()
    text_to_left_padded_hex(args.input, args.output)
