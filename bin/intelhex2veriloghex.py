import sys

def convert_intel_hex_to_byte_per_line(input_file, output_file):
    try:
        with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
            for line_num, line in enumerate(infile, 1):
                line = line.strip()
                if not line or not line.startswith(':'):
                    continue

                try:
                    # Intel HEX record structure:
                    # : [1:3]ByteCount [3:7]Address [7:9]RecordType [9:...]Data [last 2]Checksum
                    byte_count = int(line[1:3], 16)
                    record_type = int(line[7:9], 16)
                    
                    # Record Type 00 is 'Data Record'
                    if record_type == 0:
                        data_hex = line[9 : 9 + (byte_count * 2)]
                        
                        # Write each byte (2 hex chars) to a new line in the output file
                        for i in range(0, len(data_hex), 2):
                            byte_val = data_hex[i:i+2].upper()
                            outfile.write(byte_val + '\n')
                            
                except ValueError:
                    print(f"Error parsing hex on line {line_num}", file=sys.stderr)
        
        print(f"Success: Processed {input_file} and saved to {output_file}")

    except FileNotFoundError:
        print(f"Error: Input file '{input_file}' not found.", file=sys.stderr)
    except Exception as e:
        print(f"An error occurred: {e}", file=sys.stderr)

if __name__ == "__main__":
    # Check if correct number of arguments are provided
    if len(sys.argv) != 3:
        print("Usage: python script_name.py <input_file.hex> <output_file.txt>")
    else:
        input_name = sys.argv[1]
        output_name = sys.argv[2]
        convert_intel_hex_to_byte_per_line(input_name, output_name)
