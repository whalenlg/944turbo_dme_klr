import sys

# Full 256-opcode lookup table for fixed instructions
BASE_OPCODES = {
    0x00: "NOP",    0x02: "OUTL BUS, A", 0x03: "ADD A, #data", 0x05: "EN I",
    0x07: "DEC A",  0x08: "INS A, BUS",  0x09: "IN A, P1",     0x0A: "IN A, P2",
    0x12: "JB0 addr", 0x13: "ADDC A, #data", 0x15: "DIS I",    0x16: "JTF addr",
    0x17: "INC A",  0x22: "SEL NI",      0x23: "MOV A, #data", 0x25: "STOP TCNT",
    0x26: "JT0 addr", 0x27: "CLR A",      0x32: "JB1 addr",    0x35: "EN TCNTI",
    0x36: "JNT0 addr",0x37: "CPL A",      0x39: "OUTL P1, A",  0x3A: "OUTL P2, A",
    0x42: "MOV A, T", 0x43: "ORL A, #data", 0x45: "STRT CNT",  0x46: "JT1 addr",
    0x47: "SWAP A",   0x52: "JB2 addr",    0x53: "ANL A, #data", 0x55: "STRT T",
    0x56: "JNT1 addr",0x62: "MOV T, A",    0x65: "STOP TCNT",   0x67: "RRC A",
    0x72: "JB3 addr", 0x75: "ENT0 CLK",    0x76: "JF1 addr",    0x77: "DA A",
    0x77: "DA A",     0x83: "RET",         0x85: "CLR F0",      0x86: "JNI addr",
    0x89: "ORL P1, #data", 0x8A: "ORL P2, #data", 0x92: "JB4 addr", 0x93: "RETR",
    0x95: "CPL F0",   0x96: "JNZ addr",    0x97: "CLR C",       0x99: "ANL P1, #data",
    0x9A: "ANL P2, #data", 0xA3: "MOVP A, @A", 0xA5: "CLR F1",  0xA7: "CPL C",
    0xB2: "JB5 addr", 0xB3: "JMPP @A",     0xB5: "CPL F1",      0xB6: "JF0 addr",
    0xC5: "SEL RB0",  0xC6: "JZ addr",     0xD2: "JB6 addr",    0xD3: "XRL A, #data",
    0xD5: "SEL RB1",  0xE7: "RL A",        0xE3: "MOVP3 A, @A", 0xE5: "SEL MB0",
    0xE6: "JNC addr", 0xF2: "JB7 addr",    0xF5: "SEL MB1",     0xF6: "JC addr",
    0xF7: "RLC A",    0x01: "???",         0x11: "INC @R1",     0x75: "ENT0 CLK",
}

def disassemble(data):
    pc = 0
    print(f"{'ADDR':<6} {'HEX':<9} {'MNEMONIC'}")
    print("-" * 40)
    
    while pc < len(data):
        op = data[pc]
        mnemonic = "???"
        bytes_used = 1
        
        # 1. JMP/CALL Page Logic
        if (op & 0x1F) == 0x04:
            mnemonic = f"JMP   {((op & 0xE0) << 3) | data[pc+1]:03X}h"
            bytes_used = 2
        elif (op & 0x1F) == 0x14:
            mnemonic = f"CALL  {((op & 0xE0) << 3) | data[pc+1]:03X}h"
            bytes_used = 2
            
        # 2. XCHD A, @Ri (30h-31h)
        elif (op & 0xFE) == 0x30:
            mnemonic = f"XCHD  A, @R{op&1}"

        # 3. Register Bank Operations (Rn)
        elif (op & 0xF8) == 0x18: mnemonic = f"INC   R{op&7}"
        elif (op & 0xF8) == 0x28: mnemonic = f"XCH   A, R{op&7}"
        elif (op & 0xF8) == 0x48: mnemonic = f"ORL   A, R{op&7}"
        elif (op & 0xF8) == 0x58: mnemonic = f"ANL   A, R{op&7}"
        elif (op & 0xF8) == 0x68: mnemonic = f"ADD   A, R{op&7}"
        elif (op & 0xF8) == 0x78: mnemonic = f"ADDC  A, R{op&7}"
        elif (op & 0xF8) == 0xA8: mnemonic = f"MOV   R{op&7}, A"
        elif (op & 0xF8) == 0xB8:
            mnemonic = f"MOV   R{op&7}, #{data[pc+1]:02X}h"
            bytes_used = 2
        elif (op & 0xF8) == 0xC8: mnemonic = f"DEC   R{op&7}"
        elif (op & 0xF8) == 0xD8: mnemonic = f"XRL   A, R{op&7}"
        elif (op & 0xF8) == 0xE8:
            mnemonic = f"DJNZ  R{op&7}, {data[pc+1]:02X}h"
            bytes_used = 2
        elif (op & 0xF8) == 0xF8: mnemonic = f"MOV   A, R{op&7}"

        # 4. Indirect RAM Operations (@Ri)
        elif (op & 0xFE) == 0x10: mnemonic = f"INC   @R{op&1}"
        elif (op & 0xFE) == 0x20: mnemonic = f"XCH   A, @R{op&1}"
        elif (op & 0xFE) == 0x40: mnemonic = f"ORL   A, @R{op&1}"
        elif (op & 0xFE) == 0x50: mnemonic = f"ANL   A, @R{op&1}"
        elif (op & 0xFE) == 0x60: mnemonic = f"ADD   A, @R{op&1}"
        elif (op & 0xFE) == 0x70: mnemonic = f"ADDC  A, @R{op&1}"
        elif (op & 0xFE) == 0x80: mnemonic = f"MOVX  A, @R{op&1}"
        elif (op & 0xFE) == 0x90: mnemonic = f"MOVX  @R{op&1}, A"
        elif (op & 0xFE) == 0xA0: mnemonic = f"MOV   @R{op&1}, A"
        elif (op & 0xFE) == 0xB0:
            mnemonic = f"MOV   @R{op&1}, #{data[pc+1]:02X}h"
            bytes_used = 2
        elif (op & 0xFE) == 0xD0: mnemonic = f"XRL   A, @R{op&1}"
        elif (op & 0xFE) == 0xF0: mnemonic = f"MOV   A, @R{op&1}"

        # 5. Fixed Table Lookup
        elif op in BASE_OPCODES:
            mnemonic = BASE_OPCODES[op]
            if "addr" in mnemonic or "data" in mnemonic:
                mnemonic = mnemonic.replace("addr", f"{data[pc+1]:02X}h").replace("data", f"{data[pc+1]:02X}h")
                bytes_used = 2

        # Print
        hex_output = " ".join(f"{data[pc+i]:02X}" for i in range(bytes_used))
        print(f"{pc:03X}:   {hex_output:<9} {mnemonic}")
        pc += bytes_used

if __name__ == "__main__":
    if len(sys.argv) < 2: print("Usage: python disasm.py input.bin")
    else:
        with open(sys.argv[1], "rb") as f: disassemble(f.read())
