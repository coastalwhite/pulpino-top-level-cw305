`timescale 1ns / 1ps

module dummy_pulpino_write_tb();
    reg reset_i;

    wire [31:0]   pulpino_to_usb_reg;
	reg          ext_read_flicker;

	wire [7:0]   pulpino_to_usb_data;
	wire	     usb_pulpino_read_flicker;
	
	wire 		 pulpino_ext_write_flicker;
	wire 		 pulpino_usb_write_flicker;
	
	reg [31:0]  in_word;

    reg enable;
    
    reg clk;

    usb_pulpino_channel inst (
        .reset_i                       (reset_i),

        // USB -> Pulpino
        .usb_to_pulpino_reg            (32'b0),
        .usb_to_pulpino_data           (),
        .usb_to_pulpino_read_reg       (1'b0),

        // Pulpino -> USB
        .pulpino_to_usb_reg            (pulpino_to_usb_reg),
        .pulpino_to_usb_data           (pulpino_to_usb_data),

		.usb_read_flicker			   (usb_pulpino_read_flicker),
		.usb_write_flicker             (),

		.pulpino_read_flicker          (1'b0),
		.pulpino_write_flicker         (pulpino_usb_write_flicker),
    
        .clk                           (clk)
    );

    dummy_pulpino_write U_write (
        .clk                           (clk),
        .rst_n                         (!reset_i),

        .enable                        (enable),

        .out_data                      (pulpino_to_usb_data),
	    .did_word_write_flicker        (pulpino_ext_write_flicker),
	    .did_byte_write_flicker        (pulpino_usb_write_flicker),

	    .in_word                       (in_word),
	    .did_word_read_flicker         (ext_read_flicker),
	    .did_byte_read_flicker         (usb_pulpino_read_flicker)
    );
    
    always #5 clk = ~clk;
    
    initial begin
        #0
        clk        <= 1'b0;
        reset_i    <= 1'b1;
        
        ext_read_flicker <= 1'b0;

        #80
        reset_i   <= 1'b0;
        enable    <= 1'b1;
        in_word   <= 32'h1234_abcd;
        
		#160
        enable           <= 1'b0;
		ext_read_flicker <= ~ext_read_flicker;

		#60
		ext_read_flicker <= ~ext_read_flicker;
    end
endmodule