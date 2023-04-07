#!/usr/bin/python3

import sys

if len(sys.argv) < 3:
    print("Usage: {} <Bin code File> <Python Array>".format(sys.argv[0]))
    exit(1)

BLACKLISTED_LABELS = [
    '.riscv.attributes',
    '.comment',
]

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

def find_ws(s):
    for i in range(len(s) - 1):
        if s[i].isspace() and s[i+1].isspace():
            return i

    return None

def objdump_line_to_hex(line):
    # Only select lines with instructions
    if line.isspace():
        return None
    if not(line.startswith(' ')):
        return None

    # Shape:
    # <WS> <OFFSET>: <WS> <HEX DATA> <WS> <ASM INSTRUCTION>

    colon_index = line.index(':')
    offset = line[:colon_index]
    line = line[colon_index + 1:]
    line = line.strip()
    
    ws = find_ws(line)

    if ws == None:
        return None

    hexdata = line[:ws]
    hexdata = hexdata.replace(' ', '')
    asm = line[ws:].strip()

    return (offset, hexdata, asm)

LINES = ['RAM = [\n']
CURRENT_OFFSET = 0x0000
ignore_symbol = False
for line in file_in_content:
    output = to_addr(line)
    
    if output != None:
        addr, label = output

        ignore_symbol = False
        for bl_label in BLACKLISTED_LABELS:
            if '<{}>'.format(bl_label) in label:
                ignore_symbol = True

        #file_out_memfile.writelines('\t# <{}>: \n'.format(label))
        continue

    if ignore_symbol:
        continue

    output = objdump_line_to_hex(line)

    if output != None:
        offset, hexdata, asm = output
        if len(hexdata) % 2 != 0:
            print("[ERROR]: Hex data is not even length")
            exit(1)

        offset = int(offset, 16)
        if offset != CURRENT_OFFSET:
            if offset < CURRENT_OFFSET:
                print("[ERROR]: Offset jumped back!")
                exit(1)

            if (offset - CURRENT_OFFSET) % 4 == 2:
                LINES.append('\t0x00, 0x00, # PADDING\n')
                CURRENT_OFFSET += 2

            for _ in range(CURRENT_OFFSET, offset, 4):
                LINES.append('\t0x00, 0x00, 0x00, 0x00, # PADDING\n')
                CURRENT_OFFSET += 4

            if offset != CURRENT_OFFSET:
                print("[ERROR]: Failed to pad to new offset")
                exit(1)


        bs = [hexdata[i:i+2] for i in range(0, len(hexdata), 2)]

        l = '\t'
        for b in bs[::-1]:
            l += '0x{}, '.format(b)
        l += '# {}\n'.format(asm)
        LINES.append(l)

        CURRENT_OFFSET += len(bs)

        continue
LINES.append(']\n')

for line in LINES:
    file_out_memfile.writelines(line)
