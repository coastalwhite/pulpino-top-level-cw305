# Programming the Pulpino on CW305

This readme contains all the information needed to program the PULPINO core on
the CW305 given the source files in this repository. This readme assumes that
you have a ready synthesized project according to [the setup guide in this
repository](../setup/README.md). First, this readme gives a small overview of
the memory system and the solutions to program each of them. Then, all the
specifics a given to program each of them.

## Overview

The Pulpino contains 3 main memories:

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
`blinky_ram`. You can adapt your program from there. Both, use a small library
of functions that allow for IO with th

## Programming the Bootcode

In the current setup the bootcode is used to program the RAM and jump to the
proper entry address. The source code for this bootcode can be found in the
`/program/target/rust/program_rom`. A precompiled version can be found
`/program/target/out/mem_bootcode.v`. This contains the verilog array that can
be pasted into the `./rtl/bootcode.sv` source file in your PULPINO project.

```bash
# Build the bootcode
cd rust/bootcode
cargo build --release

# Turn the binary into a objdump
riscv32-elf-objdump -d target/riscv32i-unknown-none-elf/release/bootcode > ../../dumps/bootcode.dump
cd ../..

# Turn the objdump into a verilog array
./to_boot_code dumps/bootcode.dump out/bootcode.v
```

## Programming the RAM

```bash
# Build the bootcode
cd rust/blinky_led
cargo build --release

# Turn the binary into a objdump
riscv32-elf-objdump -d target/riscv32i-unknown-none-elf/release/blinky_led > ../../dumps/blinky_led.dump

# Turn the objdump into a verilog array
./to_ram dumps/blinky_led.dump out/blinky_led_mem.py
```
