#![no_main]
#![no_std]

use core::panic::PanicInfo;

use ext_io::Timer;

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}

#[export_name = "_start"]
fn main() {
    // NOTE: Caching only works if you actually added the cache modification.

    const ADDR: *mut u32 = 0x0010_0020 as *mut u32;
    const EVICT_ADDR: *mut u32 = 0x0010_0F20 as *mut u32;

    // Non-cached
    ext_io::write_word(time_addr_read(ADDR));

    // Cached
    ext_io::write_word(time_addr_read(ADDR));

    // Cached
    ext_io::write_word(time_addr_read(ADDR));

    // Non-Cached
    ext_io::write_word(time_addr_read(EVICT_ADDR));

    // Non-Cached
    ext_io::write_word(time_addr_read(ADDR));

    // Cached
    ext_io::write_word(time_addr_read(ADDR));

    loop {}
}

#[inline(never)]
fn time_addr_read(addr: *mut u32) -> u32 {
    Timer::reset();
    Timer::start();
    unsafe { addr.read_volatile(); }
    Timer::stop();

    Timer::value()
}

