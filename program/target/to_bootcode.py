#!/usr/bin/python3

import sys

ENTRY_FUNCTION='_start'

if len(sys.argv) < 3:
    print("Usage: {} <Bin code File> <Memory file>".format(sys.argv[0]))
    exit(1)

BIN_CODE = sys.argv[1]
MEM_FILE = sys.argv[2]

file_in_obj  = open(BIN_CODE, "r")
file_out_memfile = open(MEM_FILE, "w+")

file_in_content = file_in_obj.readlines()

def to_addr(line):
    ALLOWED="0123456789abcdefABCDEF"

    if line.isspace():
        return None
    if len(line) < 8:
        return None

    for i in range(8):
        if line[i] not in ALLOWED:
            return None

    addr = line[:8]
    label = line[9:].strip()
    return addr, label

def objdump_line_to_hex(line):
    # Only select lines with instructions
    if line.isspace():
        return None
    if not(line.startswith(' ')):
        return None

    # Shape:
    # <WS> <OFFSET>: <WS> <HEX DATA> <WS> <ASM INSTRUCTION>

    colon_index = line.index(':')
    line = line[colon_index + 1:]
    line = line.strip()
    hex = line[:8]
    asm = line[8:].strip()

    return (hex, asm)

LINES = []
HAS_SEEN_MAIN = False
for line in file_in_content:
    output = to_addr(line)
    
    if output != None:
        addr, label = output
        #file_out_memfile.writelines('@' + addr + ' // ' + label + '\n')
        if '<{}>'.format(ENTRY_FUNCTION) in label:
            HAS_SEEN_MAIN = True
        continue

    if not HAS_SEEN_MAIN:
        continue

    output = objdump_line_to_hex(line)

    if output != None:
        hex, asm = output
        LINES.append('\t32\'h' + hex + ', // \t' + asm + '\n')
        continue

while len(LINES) < 547:
    NOP = '\t32\'h00000013, // nop\n'
    if len(LINES) % 2 == 0:
        LINES.insert(0, NOP)
    else:
        LINES.append(NOP)

for line in LINES:
    file_out_memfile.writelines(line)
