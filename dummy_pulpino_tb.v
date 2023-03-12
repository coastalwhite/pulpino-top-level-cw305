`timescale 1ns / 1ps

module dummy_pulpino_tb();
    reg reset_i;

	reg [31:0] usb_to_pulpino_reg;
	reg ext_write_flicker;
	reg ext_read_flicker;
	reg usb_to_pulpino_read_reg;

	wire [7:0] usb_to_pulpino_data;
	wire		 usb_pulpino_write_flicker;
	wire 		 usb_pulpino_read_flicker;

	wire [31:0] pulpino_to_usb_reg;
	wire [7:0] pulpino_to_usb_data;
	wire		 pulpino_ext_write_flicker;
	wire 		 pulpino_ext_read_flicker;
	wire		 pulpino_usb_write_flicker;
	wire 		 pulpino_usb_read_flicker;
    
    reg clk;

    wire [31:0] gpio_dir;
    wire [31:0] gpio_in;
    wire [31:0] gpio_out;

    assign gpio_in       = {
        20'b0,
		ext_write_flicker,
		ext_read_flicker,
		usb_pulpino_write_flicker,
		usb_pulpino_read_flicker,
        usb_to_pulpino_data
    };

    assign gpio_dir = 32'b0;

	assign pulpino_ext_write_flicker = gpio_out[11];
	assign pulpino_ext_write_flicker = gpio_out[10];
	assign pulpino_usb_write_flicker = gpio_out[9];
	assign pulpino_usb_read_flicker = gpio_out[8];
    assign pulpino_to_usb_data = gpio_out[7:0];

    usb_pulpino_channel inst (
        .reset_i                       (reset_i),

        // USB -> Pulpino
        .usb_to_pulpino_reg            (usb_to_pulpino_reg),
        .usb_to_pulpino_data           (usb_to_pulpino_data),
        .usb_to_pulpino_read_reg       (usb_to_pulpino_read_reg),

        // Pulpino -> USB
        .pulpino_to_usb_reg            (pulpino_to_usb_reg),
        .pulpino_to_usb_data           (usb_to_pulpino_data),

		.usb_read_flicker			   (usb_pulpino_read_flicker),
		.usb_write_flicker             (usb_pulpino_write_flicker),

		.pulpino_read_flicker          (pulpino_usb_read_flicker),
		.pulpino_write_flicker         (pulpino_usb_write_flicker),
    
        .clk                           (pulpino_clk)
    );

    dummy_pulpino pulp (
        .clk                           (clk),
        .rst_n                         (!reset_i),

        //input wire fetch_enable_i,

        .spi_clk_i                     (1'b0),
        .spi_cs_i                      (1'b0),
        .spi_mode_o                    (),
        .spi_sdo0_o                    (),
        .spi_sdo1_o                    (),
        .spi_sdo2_o                    (),
        .spi_sdo3_o                    (),
        .spi_sdi0_i                    (1'b0),
        .spi_sdi1_i                    (1'b0),
        .spi_sdi2_i                    (1'b0),
        .spi_sdi3_i                    (1'b0),

        .spi_master_clk_o              (),
        .spi_master_csn0_o             (),
        .spi_master_csn1_o             (),
        .spi_master_sdo0_o             (),
        .spi_master_sdi0_i             (1'b0),

        // Interface UART
        .uart_tx                       (),
        .uart_rx                       (1'b0),
        .uart_rts                      (),
        .uart_dtr                      (),
        .uart_cts                      (1'b0),
        .uart_dsr                      (1'b0),

        .scl_i                         (1'b0),
        .scl_o                         (),
        .scl_oen_o                     (),
        .sda_i                         (1'b0),
        .sda_o                         (),
        .sda_oen_o                     (),

        // GPIO PORT
        .gpio_dir                      (gpio_dir),
        .gpio_in                       (gpio_in),
        .gpio_out                      (gpio_out),

        // Debug PORT
        .tck_i                         (1'b0),
        .trstn_i                       (1'b0),
        .tms_i                         (1'b0),
        .tdi_i                         (1'b0),
        .tdo_o                         ()
    );
    
    always #5 clk = ~clk;
    
    initial begin
        #0
        clk        <= 1'b0;
        reset_i    <= 1'b1;
		usb_to_pulpino_reg <= 32'b0;

        #10
        reset_i   <= 1'b0;
		usb_to_pulpino_read_reg <= 1'b1;
        
		#50
		usb_to_pulpino_read_reg <= 1'b1;
    end
endmodule