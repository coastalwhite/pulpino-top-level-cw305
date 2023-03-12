`timescale 1ns / 1ps

module dummy_pulpino_read_tb();
    reg reset_i;

	reg [31:0]   usb_to_pulpino_reg;
	reg          usb_to_pulpino_read_reg;
	reg          ext_write_flicker;

	wire [7:0]   usb_to_pulpino_data;
	wire	     usb_pulpino_write_flicker;
	
	wire 		 pulpino_ext_read_flicker;
	wire 		 pulpino_usb_read_flicker;
	
	wire [31:0]  out_word;
    
    reg clk;

    usb_pulpino_channel inst (
        .reset_i                       (reset_i),

        // USB -> Pulpino
        .usb_to_pulpino_reg            (usb_to_pulpino_reg),
        .usb_to_pulpino_data           (usb_to_pulpino_data),
        .usb_to_pulpino_read_reg       (usb_to_pulpino_read_reg),

        // Pulpino -> USB
        .pulpino_to_usb_reg            (),
        .pulpino_to_usb_data           (8'b0),

		.usb_read_flicker			   (),
		.usb_write_flicker             (usb_pulpino_write_flicker),

		.pulpino_read_flicker          (pulpino_usb_read_flicker),
		.pulpino_write_flicker         (1'b0),
    
        .clk                           (clk)
    );

    dummy_pulpino_read U_read (
        .clk                           (clk),
        .rst_n                         (!reset_i),

        .in_data                       (usb_to_pulpino_data),
	    .did_word_write_flicker        (ext_write_flicker),
	    .did_byte_write_flicker        (usb_pulpino_write_flicker),

	    .out_word                      (out_word),
	    .did_word_read_flicker         (pulpino_ext_read_flicker),
	    .did_byte_read_flicker         (pulpino_usb_read_flicker)
    );
    
    always #5 clk = ~clk;
    
    initial begin
        #0
        clk        <= 1'b0;
        reset_i    <= 1'b1;
        
        ext_write_flicker <= 1'b0;
        
        usb_to_pulpino_read_reg <= 1'b0;
		usb_to_pulpino_reg <= 32'b0;

        #80
        reset_i   <= 1'b0;
        
        #5
        usb_to_pulpino_read_reg <= 1'b1;
		usb_to_pulpino_reg <= 32'h1234_1236;
		
		#10
		usb_to_pulpino_read_reg <= 1'b0;
		ext_write_flicker <= ~ext_write_flicker;
		
		#160
		ext_write_flicker <= ~ext_write_flicker;
    end
endmodule