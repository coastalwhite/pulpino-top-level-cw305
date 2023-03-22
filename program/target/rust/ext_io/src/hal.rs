pub trait MappedWord {
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

pub struct GpioDir;
pub struct GpioIn;
pub struct GpioOut;

pub struct TimerValue;
pub struct TimerCtrl;
pub struct TimerCmp;


impl MappedWord for GpioDir {
    const PTR: *mut u32 = 0x1A10_1000 as *mut u32;
}

impl MappedWord for GpioIn {
    const PTR: *mut u32 = 0x1A10_1004 as *mut u32;
}

impl MappedWord for GpioOut {
    const PTR: *mut u32 = 0x1A10_1008 as *mut u32;
}

impl MappedWord for TimerValue {
    const PTR: *mut u32 = 0x1A10_3000 as *mut u32;
}

impl MappedWord for TimerCtrl {
    const PTR: *mut u32 = 0x1A10_3004 as *mut u32;
}

impl MappedWord for TimerCmp {
    const PTR: *mut u32 = 0x1A10_3008 as *mut u32;
}

impl GpioIn {
    #[inline]
    pub fn data() -> u8 {
        (Self::read() & 0xFF) as u8
    }

    #[inline]
    pub fn ext_read_flicker() -> bool {
        Self::read() & 0x100 != 0
    }

    #[inline]
    pub fn ext_write_flicker() -> bool {
        Self::read() & 0x200 != 0
    }
}

impl GpioOut {
    #[inline]
    pub fn data(byte: u8) {
        Self::write((Self::read() & 0xFFFF_FF00) | (byte as u32))
    }

    #[inline]
    pub fn toggle_read_flicker() {
        Self::write(Self::read() ^ 0x0000_0100)
    }

    #[inline]
    pub fn toggle_write_flicker() {
        Self::write(Self::read() ^ 0x0000_0200)
    }

    #[inline]
    pub fn led(value: bool) {
        Self::write((Self::read() & 0xFFFF_FBFF) | if value { 0x400 } else { 0x000 })
    }
}