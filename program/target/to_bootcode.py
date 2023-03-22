#!/usr/bin/python3

import sys

ENTRY_FUNCTION='_start'
BOOTCODE_SIZE=547

if len(sys.argv) < 3:
    print("Usage: {} <Bin code File> <Memory file>".format(sys.argv[0]))
    exit(1)

BIN_CODE = sys.argv[1]
MEM_FILE = sys.argv[2]

file_in_obj  = open(BIN_CODE, "r")
file_out_memfile = open(MEM_FILE, "w+")

file_in_content = file_in_obj.readlines()

# https://stackoverflow.com/a/14981125
def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

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
HAS_SEEN_ENTRY = False
for line in file_in_content:
    output = to_addr(line)
    
    if output != None:
        addr, label = output
        #file_out_memfile.writelines('@' + addr + ' // ' + label + '\n')
        if '<{}>:'.format(ENTRY_FUNCTION) in label:
            HAS_SEEN_ENTRY = True
        continue

    if not HAS_SEEN_ENTRY:
        continue

    output = objdump_line_to_hex(line)

    if output != None:
        hex, asm = output
        if len(LINES) == BOOTCODE_SIZE:
            eprint("Code too large for bootcode")
            exit(1)
            
        LINES.append('\t32\'h' + hex + ', // \t' + asm + '\n')
        continue

# Alternate NOPs before and after to fill buffer
while len(LINES) < BOOTCODE_SIZE:
    NOP = '\t32\'h00000013, // nop\n'
    if len(LINES) % 2 == 0:
        LINES.insert(0, NOP)
    else:
        LINES.append(NOP)

# Remove trailing comma
LINES[-1] = LINES[-1].replace(',', ' ', 1)

for line in LINES:
    file_out_memfile.writelines(line)
