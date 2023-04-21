#![no_std]

pub mod hal;

use core::arch::asm;

use hal::MappedWord;

use hal::{GpioOut, GpioIn};

#[inline]
pub fn led(value: bool) {
    GpioOut::led(value);
}

/// Blocking read from the external machine
#[inline]
pub fn read() -> u8 {
	// Wait for the external to write something
    while !GpioIn::ext_write_flicker() {}

	let byte = GpioIn::data();

	// Coordinate to get back to the original state
	GpioOut::toggle_read_flicker();
    while GpioIn::ext_write_flicker() {}
	GpioOut::toggle_read_flicker();

	byte
}

/// Blocking word read from the external machine. This will read bytes in big endian.
pub fn read_word() -> u32 {
    let bytes = [read(), read(), read(), read()];
    u32::from_be_bytes(bytes)
}

/// Blocking word write to the external machine. This will write bytes in big endian.
pub fn write_word(word: u32) {
    for b in word.to_be_bytes() {
        write(b);
    }
}

/// Blocking write to the external machine
#[inline]
pub fn write(byte: u8) {
    while GpioIn::ext_read_flicker() {}
	GpioOut::data(byte);

	// Coordinate to get back to the original state
	GpioOut::toggle_write_flicker();
    while !GpioIn::ext_read_flicker() {}
	GpioOut::toggle_write_flicker();
}

/// Reads a start and end and writes words to the addresses between those addresses.
/// 
/// Then reads one word for each of the word-aligned addresses between them and writes the
/// read word to that address.
#[inline]
pub fn program() -> bool {
    GpioOut::led(true);

    let mut start = read_word();
    let end       = read_word();

    if start == end {
        return false;
    }

    while start != end {
        let addr = start as *mut u8;
        unsafe { addr.write_volatile(read()) };
        start = start.wrapping_add(1);
    }

    GpioOut::led(false);

    true
}

/// Structure used to time operations on the PULPINO
pub struct Timer;

impl Timer {
    #[inline]
    pub fn start() {
        hal::TimerCtrl::write(1);
    }

    #[inline]
    pub fn stop() {
        hal::TimerCtrl::write(0);
    }

    #[inline]
    pub fn reset() {
        hal::TimerValue::write(0);
    }

    #[inline]
    pub fn value() -> u32 {
        hal::TimerValue::read()
    }
}

#[inline]
pub fn read_registers() {
    unsafe {
        asm!("
            sw      sp,-120(sp)
            addi    sp,sp,-124
            sw      x1,0(sp)
            sw      x3,8(sp)
            sw      x4,12(sp)
            sw      x5,16(sp)
            sw      x6,20(sp)
            sw      x7,24(sp)
            sw      x8,28(sp)
            sw      x9,32(sp)
            sw      x10,36(sp)
            sw      x11,40(sp)
            sw      x12,44(sp)
            sw      x13,48(sp)
            sw      x14,52(sp)
            sw      x15,56(sp)
            sw      x16,60(sp)
            sw      x17,64(sp)
            sw      x18,68(sp)
            sw      x19,72(sp)
            sw      x20,76(sp)
            sw      x21,80(sp)
            sw      x22,84(sp)
            sw      x23,88(sp)
            sw      x24,92(sp)
            sw      x25,96(sp)
            sw      x26,100(sp)
            sw      x27,104(sp)
            sw      x28,108(sp)
            sw      x29,112(sp)
            sw      x30,116(sp)
            sw      x31,120(sp)

            lw      a0,0(sp)
            call    {write_word}
            lw      a0,4(sp)
            call    {write_word}
            lw      a0,8(sp)
            call    {write_word}
            lw      a0,12(sp)
            call    {write_word}
            lw      a0,16(sp)
            call    {write_word}
            lw      a0,20(sp)
            call    {write_word}
            lw      a0,24(sp)
            call    {write_word}
            lw      a0,28(sp)
            call    {write_word}
            lw      a0,32(sp)
            call    {write_word}
            lw      a0,36(sp)
            call    {write_word}
            lw      a0,40(sp)
            call    {write_word}
            lw      a0,44(sp)
            call    {write_word}
            lw      a0,48(sp)
            call    {write_word}
            lw      a0,52(sp)
            call    {write_word}
            lw      a0,56(sp)
            call    {write_word}
            lw      a0,60(sp)
            call    {write_word}
            lw      a0,64(sp)
            call    {write_word}
            lw      a0,68(sp)
            call    {write_word}
            lw      a0,72(sp)
            call    {write_word}
            lw      a0,76(sp)
            call    {write_word}
            lw      a0,80(sp)
            call    {write_word}
            lw      a0,84(sp)
            call    {write_word}
            lw      a0,88(sp)
            call    {write_word}
            lw      a0,92(sp)
            call    {write_word}
            lw      a0,96(sp)
            call    {write_word}
            lw      a0,100(sp)
            call    {write_word}
            lw      a0,104(sp)
            call    {write_word}
            lw      a0,108(sp)
            call    {write_word}
            lw      a0,112(sp)
            call    {write_word}
            lw      a0,116(sp)
            call    {write_word}
            lw      a0,120(sp)
            call    {write_word}

            addi    sp,sp,124
        ", write_word = sym write_word);
    }
}
