# Programming the Pulpino on CW305

This README contains all the information needed to program the PULPINO core on
the CW305 given the source files in this repository. This README assumes that
you have a ready synthesized project according to [the setup guide in this
repository](../setup/README.md). First, this README gives a small overview of
the memory system and the solutions to program each of them. Then, all the
specifics a given to program each of them.

## Overview

The PULPINO contains 3 main memories:

1. Bootcode ROM
2. Instruction RAM
3. Data RAM

The Bootcode ROM needs to be defined on Vivado synthesis in the
`./rtl/bootcode.sv` files. The details are explained in [Programming the
Bootcode](#programming-the-bootcode). The Instruction and Data RAM are
programmed each time the core is reset. The details on how to program the RAM
are given in [Programming the RAM](#programming-the-ram).

There exist two prepared implementation on how to program the PULPINO, with Rust
and with C. Both provide an example blinky led program for the RAM called
`blinky_ram`. You can adapt your program from there.

The C and Rust implementations use small libraries called `ext_io` that allow
for IO with the python interface. The communication protocol is documented
[here](../docs/usb-communication.md). The
[ext/connection.py](./ext/connection.py) file provides the python side of that
interface and can be used to start program and start the board.

## Programming the Bootcode

In the current setup the bootcode is used to program the RAM and jump to the
proper entry address. The source code for this bootcode can be found in the
`/program/target/rust/bootcode`. A precompiled version can be found
`/program/target/out/bootcode_program`. This contains the Verilog array that can
be pasted into the `./rtl/bootcode.sv` source file in your PULPINO project.

To compile it yourself.

```bash
cd target
./compile.sh rust/bootcode --out=verilog

# Copy `out/bootcode` array into `rtl/bootcode.sv`
```

## Programming the RAM

The RAM is programmed using the USB interface. The python communication layer
for this is defined in the [ext/connection.py](./ext/connection.py). This
expects an array of bytes in Little-Endian per word. The `target/compile.sh`
script can generate this array for you. Below, is an example for the
`rust/blinky_led`.

```bash
cd target
./compile.sh rust/blinky_led

# Copy `out/blinky_led` array into your python file
```

Within Python you can then run the following to program it.

```python
from connection import PulpinoConnection

RAM = [
	# ...
]

# TODO: add your bitstream
bitpath = "path/to/bitstream.bit"
pulpino = PulpinoConnection(bitpath, force = True)

if not pulpino.get_raw().fpga.isFPGAProgrammed():
    print("ERR: FPGA failed to program")
    exit(1)

# Program the RAM address at an offset of 0x0
pulpino.program(0x0, RAM)

# Stop Programming
pulpino.stop_programming()

# Entry Address
pulpino.send_word(0x0)

# Now the PULPINO is running
```
