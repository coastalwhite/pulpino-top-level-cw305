#!/usr/bin/python3

import sys

if len(sys.argv) < 3:
    print("Usage: {} <Bin code File> <Python Array>".format(sys.argv[0]))
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

LINES = ['RAM = [\n']
for line in file_in_content:
    output = to_addr(line)
    
    if output != None:
        addr, label = output
        #file_out_memfile.writelines('\t# <{}>: \n'.format(label))
        continue

    output = objdump_line_to_hex(line)

    if output != None:
        hex, asm = output
        bs = [hex[0:2], hex[2:4], hex[4:6], hex[6:8]]

        LINES.append('\t0x{}, 0x{}, 0x{}, 0x{}, # {}\n'.format(bs[3], bs[2], bs[1], bs[0], asm))
        continue
LINES.append(']\n')

for line in LINES:
    file_out_memfile.writelines(line)
