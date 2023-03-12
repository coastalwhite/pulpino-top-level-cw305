/* 
ChipWhisperer Artix Target - Example of connections between example registers
and rest of system.

Copyright (c) 2016-2020, NewAE Technology Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted without restriction. Note that modules within
the project may have additional restrictions, please carefully inspect
additional licenses.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of NewAE Technology Inc.
*/

`timescale 1ns / 1ps
`default_nettype none 

module cw305_top #(
    parameter pBYTECNT_SIZE = 7,
    parameter pADDR_WIDTH = 21,
    parameter pPT_WIDTH = 128,
    parameter pCT_WIDTH = 128
)(
    // USB Interface
    input wire                          usb_clk,        // Clock
    inout wire [7:0]                    usb_data,       // Data for write/read
    input wire [pADDR_WIDTH-1:0]        usb_addr,       // Address
    input wire                          usb_rdn,        // !RD, low when addr valid for read
    input wire                          usb_wrn,        // !WR, low when data+addr valid for write
    input wire                          usb_cen,        // !CE, active low chip enable
    input wire                          usb_trigger,    // High when trigger requested

    // Buttons/LEDs on Board
    input wire                          j16_sel,        // DIP switch J16
    input wire                          k16_sel,        // DIP switch K16
    input wire                          k15_sel,        // DIP switch K15
    input wire                          l14_sel,        // DIP Switch L14
    input wire                          pushbutton,     // Pushbutton SW4, connected to R1, used here as reset
    output wire                         led1,           // red LED
    output wire                         led2,           // green LED
    output wire                         led3,           // blue LED

    // PLL
    input wire                          pll_clk1,       //PLL Clock Channel #1
    //input wire                        pll_clk2,       //PLL Clock Channel #2 (unused in this example)

    // 20-Pin Connector Stuff
    output wire                         tio_trigger,
    output wire                         tio_clkout,
    input  wire                         tio_clkin
    );

    wire usb_clk_buf;
    wire [7:0] usb_dout;
    wire isout;
    wire [pADDR_WIDTH-pBYTECNT_SIZE-1:0] reg_address;
    wire [pBYTECNT_SIZE-1:0] reg_bytecnt;
    wire reg_addrvalid;
    wire [7:0] write_data;
    wire [7:0] read_data;
    wire reg_read;
    wire reg_write;
    wire pulpino_clk;    

    wire resetn = pushbutton;
    wire reset = !resetn;

	wire [31:0] pulpino_to_usb_reg;
	wire [31:0] usb_to_pulpino_reg;
    wire        usb_to_pulpino_read_reg;

	wire [31:0] pulpino_to_ext_flags;
	wire [31:0] ext_to_pulpino_flags;

    // USB CLK Heartbeat
    reg [24:0] usb_timer_heartbeat;
    always @(posedge usb_clk_buf) usb_timer_heartbeat <= usb_timer_heartbeat +  25'd1;
    assign led1 = usb_timer_heartbeat[24];

    // CRYPT CLK Heartbeat
    reg [20:0] pulpino_clk_heartbeat;
    always @(posedge pulpino_clk) pulpino_clk_heartbeat <= pulpino_clk_heartbeat +  23'd1;
    assign led2 = pulpino_clk_heartbeat[20];


    cw305_usb_reg_fe #(
       .pBYTECNT_SIZE           (pBYTECNT_SIZE),
       .pADDR_WIDTH             (pADDR_WIDTH)
    ) U_usb_reg_fe (
       .rst                     (reset),
       .usb_clk                 (usb_clk_buf), 
       .usb_din                 (usb_data), 
       .usb_dout                (usb_dout), 
       .usb_rdn                 (usb_rdn), 
       .usb_wrn                 (usb_wrn),
       .usb_cen                 (usb_cen),
       .usb_alen                (1'b0),                 // unused
       .usb_addr                (usb_addr),
       .usb_isout               (isout), 
       .reg_address             (reg_address), 
       .reg_bytecnt             (reg_bytecnt), 
       .reg_datao               (write_data), 
       .reg_datai               (read_data),
       .reg_read                (reg_read), 
       .reg_write               (reg_write), 
       .reg_addrvalid           (reg_addrvalid)
    );


    cw305_reg_pulpino #(
       .pBYTECNT_SIZE           (pBYTECNT_SIZE),
       .pADDR_WIDTH             (pADDR_WIDTH),
       .pPT_WIDTH               (pPT_WIDTH),
       .pCT_WIDTH               (pCT_WIDTH)
    ) U_reg_pulpino (
       .reset_i                 (reset),
       .crypto_clk              (pulpino_clk),
       .usb_clk                 (usb_clk_buf), 
       .reg_address             (reg_address[pADDR_WIDTH-pBYTECNT_SIZE-1:0]), 
       .reg_bytecnt             (reg_bytecnt), 
       .read_data               (read_data), 
       .write_data              (write_data),
       .reg_read                (reg_read), 
       .reg_write               (reg_write), 
       .reg_addrvalid           (reg_addrvalid),

       .exttrigger_in           (usb_trigger),

	   .I_pulpino_to_usb		(pulpino_to_usb_reg),
	   .I_pulpino_to_ext_flags	(pulpino_to_ext_flags),

	   .O_usb_to_pulpino		(usb_to_pulpino_reg),
	   .O_ext_to_pulpino_flags	(ext_to_pulpino_flags),

       .O_usb_to_pulpino_read   (usb_to_pulpino_read_reg)
    );

    assign usb_data = isout? usb_dout : 8'bZ;

    clocks U_clocks (
       .usb_clk                 (usb_clk),
       .usb_clk_buf             (usb_clk_buf),
       .I_j16_sel               (j16_sel),
       .I_k16_sel               (k16_sel),
       .I_cw_clkin              (tio_clkin),
       .I_pll_clk1              (pll_clk1),
       .O_cw_clkout             (tio_clkout),
       .O_cryptoclk             (pulpino_clk)
    );

    wire [31:0] gpio_dir;
    wire [31:0] gpio_in;
    wire [31:0] gpio_out;

    wire [7:0]  usb_to_pulpino_data;
    wire [7:0]  pulpino_to_usb_data;

	wire ext_read_flicker;
	wire ext_write_flicker;

	wire usb_read_flicker;
	wire usb_write_flicker;

	wire pulpino_ext_read_flicker;
	wire pulpino_ext_write_flicker;
	wire pulpino_usb_read_flicker;
	wire pulpino_usb_write_flicker;

    assign ext_read_flicker     = ext_to_pulpino_flags[0];
    assign ext_write_flicker    = ext_to_pulpino_flags[1];

    assign pulpino_to_ext_flags[0] = pulpino_ext_read_flicker;
    assign pulpino_to_ext_flags[1] = pulpino_ext_write_flicker;

    assign gpio_dir      = 32'h0000_0000;
    assign gpio_in       = {
        20'b0,
		ext_write_flicker,
		ext_read_flicker,
		usb_write_flicker,
		usb_read_flicker,
        usb_to_pulpino_reg
    };

    assign pulpino_ext_write_flicker = gpio_out[11];
    assign pulpino_ext_read_flicker = gpio_out[10];
    assign pulpino_usb_write_flicker = gpio_out[9];
    assign pulpino_usb_read_flicker = gpio_out[8];
    assign pulpino_to_usb_data = gpio_out[7:0];
    
    assign led3 = (
        ( k15_sel &  l14_sel & pulpino_ext_read_flicker)  |
        ( k15_sel & ~l14_sel & pulpino_ext_write_flicker) |
        (~k15_sel &  l14_sel & ext_read_flicker)          |
        (~k15_sel & ~l14_sel & ext_write_flicker)
    );

    usb_pulpino_channel inst (
        .reset_i                       (reset),

        // USB -> Pulpino
        .usb_to_pulpino_reg            (usb_to_pulpino_reg),
        .usb_to_pulpino_data           (usb_to_pulpino_data),
        .usb_to_pulpino_read_reg       (usb_to_pulpino_read_reg),

        // Pulpino -> USB
        .pulpino_to_usb_reg            (pulpino_to_usb_reg),
        .pulpino_to_usb_data           (usb_to_pulpino_data),

		.usb_read_flicker			   (usb_read_flicker),
		.usb_write_flicker             (usb_write_flicker),

		.pulpino_read_flicker          (pulpino_usb_read_flicker),
		.pulpino_write_flicker         (pulpino_usb_write_flicker),
    
        .clk                           (pulpino_clk)
    );

	// dummy_pulpino U_proc (
	pulpino U_proc (
  		.clk                           (pulpino_clk),
  		.rst_n                         (resetn),

		 .fetch_enable_i               (1'b1),

		 .spi_clk_i                    (1'b0),
		 .spi_cs_i                     (1'b0),
		 .spi_mode_o                   (),
		 .spi_sdo0_o                   (),
		 .spi_sdo1_o                   (),
		 .spi_sdo2_o                   (),
		 .spi_sdo3_o                   (),
		 .spi_sdi0_i                   (1'b0),
		 .spi_sdi1_i                   (1'b0),
		 .spi_sdi2_i                   (1'b0),
		 .spi_sdi3_i                   (1'b0),

		 .spi_master_clk_o             (),
		 .spi_master_csn0_o            (),
		 .spi_master_csn1_o            (),
		 .spi_master_sdo0_o            (),
		 .spi_master_sdi0_i            (1'b0),

		 // Interface UART
		 .uart_tx                      (),
		 .uart_rx                      (1'b0),
		 .uart_rts                     (),
		 .uart_dtr                     (),
		 .uart_cts                     (1'b0),
		 .uart_dsr                     (1'b0),

		 .scl_i                        (1'b0),
		 .scl_o                        (),
		 .scl_oen_o                    (),
		 .sda_i                        (1'b0),
		 .sda_o                        (),
		 .sda_oen_o                    (),

		 // GPIO PORT
		 .gpio_dir                     (gpio_dir),
		 .gpio_in                      (gpio_in),
		 .gpio_out                     (gpio_out),

		 // Debug PORT
		 .tck_i                        (1'b0),
		 .trstn_i                      (1'b0),
		 .tms_i                        (1'b0),
		 .tdi_i                        (1'b0),
		 .tdo_o                        ()
	);

endmodule

`default_nettype wire

