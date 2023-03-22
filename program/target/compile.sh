#!/bin/sh

function usage() {
    echo "Usage: $0 <directory> [flags]"
    echo "Flags:"
    echo "   --out=<verilog/python>                         (default: python)"
    echo "   --outname=<file.py>                            (default: \$dir.py)"
    echo "   --outdir=/path/to/dir                          (default: ./out)"
    echo "   --xclip                                        (default: false)"
    echo "   --help"
    echo ""
    echo "This command compiles the source code in a directory and outputs "
    echo "either a 'python' array of bytes or a 'verilog' array. This is "
    echo "controlled by the '--out' flag."
    echo ""
    echo "If the directory starts with 'c/', it will use the RISC-V GCC "
    echo "compiler to compile the files specified in the 'gcc_files' file "
    echo "within the target directory. If the directory starts with "
    echo "'rust/',  it will invote a 'cargo build --release'."
    echo ""
    echo "The output file will be written to '\$outdir/\$outname'. With the "
    echo "'--xclip' flag, the result can also be written to the clipboard "
    echo "for Linux X11 based systems."
    echo ""
    echo "Example:"
    echo "    ./compile.sh rust/blinky_led --out=python --outname=program.py"
}

RISCV_GCC="riscv-none-elf-gcc -march=rv32i"
RISCV_OBJDUMP="riscv-none-elf-objdump"

if [ -z $1 ] ; then
    usage
    exit 1
fi

PROG_DIR="$1" 
OUT_FORMAT="python"
OUT_NAME="$(basename "$PROG_DIR")"
OUT_DIR="./out"
DO_XCLIP=0

if [[ $PROG_DIR == "--help" ]]; then
	usage
	exit 0
fi

IS_FIRST_ARG=0
for arg in "$@";
do
    if [ $IS_FIRST_ARG -eq 0 ]; then
        IS_FIRST_ARG=1
        continue
    fi

    if [[ $arg == "--out=verilog" ]]; then
        OUT_FORMAT="verilog"
    elif [[ $arg == "--out=python" ]]; then
        OUT_FORMAT="python"
    elif [[ $arg == "--xclip" ]]; then
        DO_XCLIP=1
    elif [[ $arg == --outname=* ]]; then
        OUT_NAME="$(echo "$arg" | cut -d'=' -f 2)"
    elif [[ $arg == --outdir=* ]]; then
        OUT_DIR="$(echo "$arg" | cut -d'=' -f 2)"
    elif [[ $arg == "--help" ]]; then
        usage
        exit 0
    else
        usage
        exit 2
    fi
done

TARGET_TYPE=""

if [[ $PROG_DIR == rust/* ]]; then
    TARGET_TYPE="rust"
elif [[ $PROG_DIR == c/* ]]; then
    TARGET_TYPE="c"
else
    echo "ERR: target directory must be in either 'rust/' or 'c/'"
    exit 2
fi

# Turn on: Exit on error
set -e

pushd "$PROG_DIR" > /dev/null

if [[ $TARGET_TYPE == "rust" ]]; then
    # Requirements:
    # - cargo
    # - rustup target install riscv32i-unknown-none-elf
    # - xpack riscv gcc (https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack)
    
    echo "Compiling Rust Directory..."
    BIN_PATH="target/riscv32i-unknown-none-elf/release/$(basename $PROG_DIR)"
    cargo build --release
else
    # Requirements:
    # - xpack riscv gcc (https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack)

    echo "Compiling C Directory..."
    mkdir -p target
    BIN_PATH="target/$(basename $PROG_DIR)"
    CFILES=$(cat gcc_files)
    $RISCV_GCC -fdata-sections -ffunction-sections $C_FILES -o "$BIN_PATH" -Wl,--gc-sections 
fi

echo "Dumping binary file..."
$RISCV_OBJDUMP -d $BIN_PATH > "../../dumps/$(basename $PROG_DIR).dump"

popd > /dev/null

out_path="$OUT_DIR/$OUT_NAME"

# Generate the proper output format
echo "Generating output file..."
if [[ $OUT_FORMAT == "python" ]]; then
    ./to_ram.py "dumps/$(basename $PROG_DIR).dump" "$out_path"
elif [[ $OUT_FORMAT == "verilog" ]]; then
    ./to_bootcode.py "dumps/$(basename $PROG_DIR).dump" "$out_path"
else
    echo "ERR: Unknown output format '$OUT_FORMAT'"
    exit 1
fi

# Conditinally copy to the clipboard
if [[ $DO_XCLIP == 1 ]]; then
    echo "Copying to XClip..."
    cat "$OUT_DIR/$OUT_NAME" | xclip -sel clip
fi
