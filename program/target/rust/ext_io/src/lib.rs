#![no_std]

struct GpioDir;
struct GpioIn;
struct GpioOut;

trait MappedWord {
    const PTR: *mut u32;

    #[inline]
    fn read() -> u32 {
        unsafe { Self::PTR.read_volatile() }
    }

    #[inline]
    fn write(value: u32) {
        unsafe { Self::PTR.write_volatile(value) }
    }
}

impl MappedWord for GpioDir {
    const PTR: *mut u32 = 0x1A10_1000 as *mut u32;
}

impl MappedWord for GpioIn {
    const PTR: *mut u32 = 0x1A10_1004 as *mut u32;
}

impl MappedWord for GpioOut {
    const PTR: *mut u32 = 0x1A10_1008 as *mut u32;
}

impl GpioIn {
    #[inline]
    fn data() -> u8 {
        (Self::read() & 0xFF) as u8
    }

    #[inline]
    fn ext_read_flicker() -> bool {
        Self::read() & 0x100 != 0
    }

    #[inline]
    fn ext_write_flicker() -> bool {
        Self::read() & 0x200 != 0
    }
}

impl GpioOut {
    #[inline]
    fn data(byte: u8) {
        Self::write((Self::read() & 0xFFFF_FF00) | (byte as u32))
    }

    #[inline]
    fn toggle_read_flicker() {
        Self::write(Self::read() ^ 0x0000_0100)
    }

    #[inline]
    fn toggle_write_flicker() {
        Self::write(Self::read() ^ 0x0000_0200)
    }

    #[inline]
    fn led(value: bool) {
        Self::write((Self::read() & 0xFFFF_FBFF) | if value { 0x400 } else { 0x000 })
    }
}

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

// #[inline]
// pub fn between() {
//     let mut start = read();
//     let end = read();
//
//     loop {
//         if start == end {
//             break;
//         }
//
//         write(start);
//         start = start.wrapping_add(1);
//     }
// }

pub struct MemoryRange;

impl MemoryRange {
    /// Reads a start and end and writes words to the addresses between those addresses.
    /// 
    /// Then reads one word for each of the word-aligned addresses between them and writes the
    /// read word to that address.
    #[inline]
    pub fn program() -> bool {
        GpioOut::led(true);

        let mut start = read_word();
        let end       = read_word();

        write_word(start);
        write_word(end);

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
}
