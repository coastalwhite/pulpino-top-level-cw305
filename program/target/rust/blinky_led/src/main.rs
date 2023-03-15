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
    let mut led_value = false;

    loop {
        for _ in 0..10_000_000 {
            unsafe { asm!("nop"); }
        }
        led_value = !led_value;
        ext_io::led(led_value);
    }
}
