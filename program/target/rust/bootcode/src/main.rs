#![no_main]
#![no_std]

use core::arch::asm;
use core::panic::PanicInfo;

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}

#[export_name = "_start"]
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
