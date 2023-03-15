from time import sleep
import chipwhisperer as cw
from chipwhisperer.capture.targets.CW305 import CW305

PULPINO_CLK_FREQ = 100_000_000
FPGA_REGS = dict(
    REG_EXT_PULPINO_DATA   = 0x00,
    REG_PULPINO_EXT_DATA   = 0x01,
    REG_EXT_PULPINO_FLAGS  = 0x02,
    REG_PULPINO_EXT_FLAGS  = 0x03,
)

def word_to_byte_array(word):
    arr = []

    for _ in range(4):
        arr.append(word & 0xFF)
        word >>= 8

    return bytearray(arr)

def byte_array_to_word(barr):
    word = 0

    for b in barr[::-1]:
        word <<= 8
        word |= b

    return word

class PulpinoConnection():
    _ext_read_flicker = False
    _ext_write_flicker = False

    def __init__(self, bitfile_path, force = False):
        self.ftarget = cw.target(
            scope = None,
            target_type = CW305,
            bsfile=bitfile_path,
            fpga_id='100t', force=force
        )
        self.bitfile_path = bitfile_path

        # Disable all the clocks on the FPGA
        self.ftarget.vccint_set(1.0)

        self.ftarget.gpio_mode()

        self.ftarget.pll.pll_enable_set(True)
        self.ftarget.pll.pll_outenable_set(False, 0)
        self.ftarget.pll.pll_outenable_set(True, 1)
        self.ftarget.pll.pll_outenable_set(False, 2)

        self.ftarget.pll.pll_outfreq_set(PULPINO_CLK_FREQ, 1)

        # 1ms is plenty of idling time
        self.ftarget.clkusbautooff = False
        self.ftarget.clksleeptime = 1

    # Useful for when instruction memory gets corrupted
    def reprogram_fpga(self, bitfile_path = None):
        if bitfile_path == None:
            bitfile_path = self.bitfile_path

        self.ftarget.fpga.FPGAProgram(
            open(bitfile_path, "rb"),
            exceptOnDoneFailure=False,
            prog_speed=10E6
        )

    def disconnect(self):
        self.ftarget.dis()

    def _reg_write(self, reg, byte):
        if byte < 0 or byte >= pow(2, 8):
            raise Exception("Byte value out of range (0 ..= 2**8 - 1)")

        while self.ftarget.fpga_read(reg, 1)[0] != byte:
            self.ftarget.fpga_write(reg, bytearray([byte]))

    def _pulpino_flags(self):
        flags = self.ftarget.fpga_read(FPGA_REGS['REG_PULPINO_EXT_FLAGS'], 1)
        return flags[0]

    def _pulpino_read_flicker(self) -> bool:
        return (self._pulpino_flags() & 0x1) != 0

    def _pulpino_write_flicker(self) -> bool:
        return (self._pulpino_flags() & 0x2) != 0

    def _write_ext_flags(self, read_flicker, write_flicker):
        if read_flicker:
            ext_read_flicker = 1
        else:
            ext_read_flicker = 0

        if write_flicker:
            ext_write_flicker = 1
        else:
            ext_write_flicker = 0

        value = (ext_write_flicker << 1) | ext_read_flicker

        self._reg_write(FPGA_REGS['REG_EXT_PULPINO_FLAGS'], value)
        
    def _toggle_ext_read_flicker(self):
        self._ext_read_flicker = not self._ext_read_flicker
        self._write_ext_flags(self._ext_read_flicker, self._ext_write_flicker)

    def _toggle_ext_write_flicker(self):
        self._ext_write_flicker = not self._ext_write_flicker
        self._write_ext_flags(self._ext_read_flicker, self._ext_write_flicker)

    def send_byte(self, byte):
        self._reg_write(FPGA_REGS['REG_EXT_PULPINO_DATA'], byte)

        self._toggle_ext_write_flicker()
        while ( not self._pulpino_read_flicker() ):
            continue
        self._toggle_ext_write_flicker()

    def receive_byte(self):
        while ( not self._pulpino_write_flicker() ):
            continue

        byte = self.ftarget.fpga_read(
            FPGA_REGS['REG_PULPINO_EXT_DATA'],
            readlen=1
        )[0]

        self._toggle_ext_read_flicker()
        while ( self._pulpino_write_flicker() ):
            continue
        self._toggle_ext_read_flicker()

        return byte

    def send_word(self, word):
        if word < 0 or word >= pow(2, 32):
            raise Exception("Word value out of range (0 ..= 2**32 - 1)")

        bs = [
            (word & 0xFF00_0000) >> 24,
            (word & 0x00FF_0000) >> 16,
            (word & 0x0000_FF00) >>  8,
            (word & 0x0000_00FF) >>  0,
        ]

        for b in bs:
            self.send_byte(b)

    def receive_word(self):
        return (
            (self.receive_byte() << 24) |
            (self.receive_byte() << 16) |
            (self.receive_byte() <<  8) |
            (self.receive_byte() <<  0)
        )

    def program(self, start, ram_memory):
        end = (start + len(ram_memory)) % pow(2, 32)

        print(end)
        print("Start Program")
        self.send_word(start)
        print("Sent start")
        print("start: 0x{:x}".format(self.receive_word()))
        self.send_word(end)
        print("Sent end")
        print("end: 0x{:x}".format(self.receive_word()))

        for b in ram_memory:
            print("Sent Byte")
            self.send_byte(b)

    def get_raw(self):
        return self.ftarget