#!/usr/bin/env python3
# Best-effort annotated linear disassembly for 8051 ROM (no external libs)
# Saves 28PIN_DME_PERFORMANCE_annotated.asm
from pathlib import Path

infile = '28PIN_DME_PERFORMANCE.bin'
outfile = '28PIN_DME_PERFORMANCE_annotated.asm'

data = Path(infile).read_bytes()
n = len(data)

def word(b1,b2): return (b1<<8)|b2
def signed(b):
    return b-256 if b>127 else b

# First pass: collect referenced addresses from a small set of opcodes
refs = set()
i = 0
while i < n:
    op = data[i]
    if op == 0x02 and i+2 < n:           # LJMP addr16
        refs.add(word(data[i+1], data[i+2]))
        i += 3
    elif op == 0x12 and i+2 < n:         # LCALL addr16
        refs.add(word(data[i+1], data[i+2]))
        i += 3
    elif op == 0x80 and i+1 < n:         # SJMP rel
        rel = signed(data[i+1])
        addr = (i + 2 + rel) & 0xFFFF
        refs.add(addr)
        i += 2
    elif op == 0x90 and i+2 < n:         # MOV DPTR,#data16
        refs.add(word(data[i+1], data[i+2]))
        i += 3
    elif op == 0x75 and i+2 < n:         # MOV direct,#imm
        i += 3
    elif op == 0x74 and i+1 < n:         # MOV A,#imm
        i += 2
    else:
        i += 1

# Make labels for references that fall inside ROM
labels_map = {}
for addr in sorted(refs):
    if 0 <= addr < n:
        labels_map[addr] = f"loc_{addr:04X}h"

# Second pass: linear disassembly and annotate
asm = []
asm.append("; Annotated, best-effort 8051 linear disassembly")
asm.append("; Recognized opcodes: LJMP(02), LCALL(12), SJMP(80), MOV DPTR(90), INC DPTR(A3),")
asm.append("; MOV A,#(74), MOV direct,#(75), NOP(00), RET(22), CLR A(E4), MOVX @DPTR,A(F0)")
asm.append("; Unknown bytes are emitted as DB directives.")
asm.append("    ORG 0000h\n")

i = 0
while i < n:
    if i in labels_map:
        asm.append(f"{labels_map[i]}: ; referenced target")

    op = data[i]
    if op == 0x00:
        asm.append(f"{i:04X}:    NOP")
        i += 1
    elif op == 0x22:
        asm.append(f"{i:04X}:    RET")
        i += 1
    elif op == 0x02 and i+2 < n:
        addr = word(data[i+1], data[i+2])
        lab = labels_map.get(addr, f"{addr:04X}h")
        asm.append(f"{i:04X}:    LJMP {lab}    ; 02 {data[i+1]:02X} {data[i+2]:02X}")
        i += 3
    elif op == 0x12 and i+2 < n:
        addr = word(data[i+1], data[i+2])
        lab = labels_map.get(addr, f"{addr:04X}h")
        asm.append(f"{i:04X}:    LCALL {lab}   ; 12 {data[i+1]:02X} {data[i+2]:02X}")
        i += 3
    elif op == 0x80 and i+1 < n:
        rel = signed(data[i+1])
        addr = (i + 2 + rel) & 0xFFFF
        lab = labels_map.get(addr, f"{addr:04X}h")
        asm.append(f"{i:04X}:    SJMP {lab}    ; relative {rel:+d}")
        i += 2
    elif op == 0x90 and i+2 < n:
        addr = word(data[i+1], data[i+2])
        asm.append(f"{i:04X}:    MOV DPTR, #{addr:04X}h   ; 90 {data[i+1]:02X} {data[i+2]:02X}")
        i += 3
    elif op == 0xA3:
        asm.append(f"{i:04X}:    INC DPTR")
        i += 1
    elif op == 0x74 and i+1 < n:
        imm = data[i+1]
        asm.append(f"{i:04X}:    MOV A, #{imm:02X}h    ; 74 {imm:02X}")
        i += 2
    elif op == 0x75 and i+2 < n:
        direct = data[i+1]; imm = data[i+2]
        asm.append(f"{i:04X}:    MOV {direct:02X}h, #{imm:02X}h   ; 75 {direct:02X} {imm:02X}")
        i += 3
    elif op == 0xE4:
        asm.append(f"{i:04X}:    CLR A")
        i += 1
    elif op == 0xF0:
        asm.append(f"{i:04X}:    MOVX @DPTR, A")
        i += 1
    else:
        # group up to 16 bytes of unknowns into DB for readability
        j = i
        chunk = []
        while j < n and len(chunk) < 16 and data[j] not in (0x00,0x22,0x02,0x12,0x80,0x90,0xA3,0x74,0x75,0xE4,0xF0):
            chunk.append(data[j]); j += 1
        if chunk:
            hexs = ', '.join(f'0{b:02X}h' for b in chunk)
            asm.append(f"{i:04X}:    DB {hexs}")
            i = j
        else:
            asm.append(f"{i:04X}:    DB 0{data[i]:02X}h")
            i += 1

# Write file
Path(outfile).write_text('\n'.join(asm))
print(f"Annotated disassembly written to: {outfile}")

