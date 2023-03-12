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
    fn usb_read_flicker() -> bool {
        Self::read() & 0x100 != 0
    }

    #[inline]
    fn usb_write_flicker() -> bool {
        Self::read() & 0x200 != 0
    }

    #[inline]
    fn ext_read_flicker() -> bool {
        Self::read() & 0x400 != 0
    }

    #[inline]
    fn ext_write_flicker() -> bool {
        Self::read() & 0x800 != 0
    }
}

impl GpioOut {
    #[inline]
    fn data(byte: u8) {
        Self::write((Self::read() & 0xFFFF_FF00) | (byte as u32))
    }

    #[inline]
    fn usb_read_flicker() {
        Self::write(Self::read() ^ 0x0000_0100)
    }

    #[inline]
    fn usb_write_flicker() {
        Self::write(Self::read() ^ 0x0000_0200)
    }

    #[inline]
    fn ext_read_flicker() {
        Self::write(Self::read() ^ 0x0000_0400)
    }

    #[inline]
    fn ext_write_flicker() {
        Self::write(Self::read() ^ 0x0000_0800)
    }
}

#[inline]
fn usb_read() -> u32 {
    let mut word: u32 = 0;
    
    for i in 0..4 {
        while GpioIn::usb_write_flicker() == (i & 1 != 0) { }

		word <<= 8;
		word |= GpioIn::data() as u32;

        GpioOut::usb_read_flicker();
    }

    return word;
}

#[inline]
fn usb_write(mut word: u32) {
    for i in 0..4 {
        GpioOut::data((word & 0xFF) as u8);
		word >>= 8;
		
        GpioOut::usb_write_flicker();

        while GpioIn::usb_read_flicker() == (i & 0x1 != 0) {}
    }

	GpioOut::data(0x00);
}

/// Blocking read from the external machine
pub fn read() -> u32 {
	// Wait for the external to write something
    while !GpioIn::ext_write_flicker() {}

	let word = usb_read();

	// Coordinate to get back to the original state
	GpioOut::ext_read_flicker();
    while GpioIn::ext_write_flicker() {}
	GpioOut::ext_read_flicker();

	return word;
}

/// Blocking write to the external machine
pub fn write(word: u32) {
	usb_write(word);

	// Coordinate to get back to the original state
	GpioOut::ext_write_flicker();
    while !GpioIn::ext_read_flicker() {}
	GpioOut::ext_write_flicker();
}

pub struct MemoryRange;

impl MemoryRange {
    /// Reads a start and end and writes words to the addresses between those addresses.
    /// 
    /// Then reads one word for each of the word-aligned addresses between them and writes the
    /// read word to that address.
    pub fn program() {
        // Ensure the `start` and `end` are word aligned.
        let start = read() & 0xFFFF_FFFC;
        let end   = read() & 0xFFFF_FFFC;

        for addr in (start..end).step_by(4) {
            let addr = addr as *mut u32;
            unsafe { addr.write_volatile(read()) };
        }
    }

    /// Reads a start and end and echoes the words at those ddresses.
    pub fn echo() {
        // Ensure the `start` and `end` are word aligned.
        let start = read() & 0xFFFF_FFFC;
        let end   = read() & 0xFFFF_FFFC;

        for addr in (start..end).step_by(4) {
            let addr = addr as *mut u32;
            write(unsafe { addr.read_volatile() });
        }
    }
}
