import chipwhisperer as cw
from chipwhisperer.capture.targets.CW305 import CW305

PULPINO_CLK_FREQ = 10E8
FPGA_REGS = dict(
    REG_EXT_PULPINO_DATA  = 0x00,
    REG_PULPINO_EXT_DATA  = 0x01,
    REG_EXT_PULPINO_FLAGS = 0x02,
    REG_PULPINO_EXT_FLAGS = 0x03,
)

class PulpinoConnection():
    _ext_read_flicker = False
    _ext_write_flicker = False

    def __init__(self, bitfile_path, force = False):
        self.ftarget = cw.target(
            CW305,
            bsfile=bitfile_path,
            fpga_id='100t', force=force
        )
        self.bitfile_path = bitfile_path

        # Disable all the clocks on the FPGA
        self.ftarget.vccint_set(1.0)

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

    def _pulpino_ext_read_flicker(self) -> bool:
        pulpino_ext_flags = self.ftarget.fpga_read(FPGA_REGS['REG_PULPINO_EXT_FLAGS'])
        return (pulpino_ext_flags & 0x1) != 0

    def _pulpino_ext_write_flicker(self) -> bool:
        pulpino_ext_flags = self.ftarget.fpga_read(FPGA_REGS['REG_PULPINO_EXT_FLAGS'])
        return (pulpino_ext_flags & 0x2) != 0

    def _ext_pulpino_write_flicker(self):
        if self._ext_write_flicker:
            ext_write_flicker = 0
        else:
            ext_write_flicker = 1

        if self._ext_read_flicker:
            ext_read_flicker = 1
        else:
            ext_read_flicker = 0
            
        value = (ext_write_flicker << 1) | ext_read_flicker

        self.ftarget.fpga_write(
            FPGA_REGS['REG_EXT_PULPINO_FLAGS'],
            value
        )

    def _ext_pulpino_read_flicker(self):
        if self._ext_write_flicker:
            ext_write_flicker = 1
        else:
            ext_write_flicker = 0

        if self._ext_read_flicker:
            ext_read_flicker = 0
        else:
            ext_read_flicker = 1
            
        value = (ext_write_flicker << 1) | ext_read_flicker

        self.ftarget.fpga_write(
            FPGA_REGS['REG_EXT_PULPINO_FLAGS'],
            value
        )

    def send_word(self, word):
        if len(word) != 4:
            raise Exception("Not 4 bytes sent")
            
        self.ftarget.fpga_write(
            FPGA_REGS['REG_EXT_PULPINO_DATA'],
            word
        )

        self._ext_pulpino_write_flicker()
        while ( not self._pulpino_ext_read_flicker() ):
            continue
        self._ext_pulpino_write_flicker()
    
    def receive_word(self):
        while ( not self._pulpino_ext_write_flicker() ):
            continue


        word = self.ftarget.fpga_read(FPGA_REGS['REG_PULPINO_EXT_DATA'])

        self._ext_pulpino_read_flicker()
        while ( self._pulpino_ext_write_flicker() ):
            continue
        self._ext_pulpino_read_flicker()
        
        return word

    def get_raw(self):
        return self.ftarget