#![no_std]

pub mod hal;

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
#[inline]
pub fn read_word() -> u32 {
    let bytes = [read(), read(), read(), read()];
    u32::from_be_bytes(bytes)
}

/// Blocking word write to the external machine. This will write bytes in big endian.
#[inline]
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

