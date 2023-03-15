#![no_main]
#![no_std]

use core::arch::{asm, global_asm};
use core::panic::PanicInfo;

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}

global_asm!{
r#"
.globl _start
_start:
    li  sp,0x0
    lui sp,0x00108
    j main
"#}

#[no_mangle]
fn main() {
    while ext_io::MemoryRange::program() {}

    let entry = ext_io::read_word();

    unsafe {
        asm!(
            "jalr a0",
            in ("a0") entry,
        );
    }

    loop {}
}
