`timescale 1ns / 1ps
`default_nettype none 

module dummy_pulpino_write(

	output reg [7:0] out_data,
	output reg did_word_write_flicker,
	output reg did_byte_write_flicker,

    input wire enable,

	input wire [31:0] in_word,
	input wire did_word_read_flicker,
	input wire did_byte_read_flicker,

	input wire rst_n,
	input wire clk

);

reg [2:0] state;
reg [2:0] next_state;

localparam
	waitwordack   = 3'b000,
	byte1		  = 3'b001,
	byte2		  = 3'b010,
	byte3		  = 3'b011,
	byte4		  = 3'b100,
	waitwordread  = 3'b101;

always @ (posedge clk) begin
	if (~rst_n)
		state <= waitwordack;
	else
		state <= next_state;
end

always @ (state, did_word_read_flicker, did_byte_read_flicker, enable)
begin
    next_state <= state;
    
    did_byte_write_flicker <= did_byte_write_flicker;
    did_word_write_flicker <= did_word_write_flicker;
    
	case (state)
		waitwordack: begin
			did_byte_write_flicker <= 1'b0;
			did_word_write_flicker <= 1'b0;

			out_data <= 8'h00;
			
            if (did_word_read_flicker == 1'b0 && enable == 1'b1)
				next_state <= byte1;
		end
		byte1: begin
            out_data <= in_word[7:0];
            next_state <= byte2;
            did_byte_write_flicker <= 1'b1;
		end
		byte2: begin
			if (did_byte_read_flicker == 1'b1) begin
				out_data <= in_word[15:8];
				next_state <= byte3;
				did_byte_write_flicker <= 1'b0;
			end
		end
		byte3: begin
			if (did_byte_read_flicker == 1'b0) begin
				out_data <= in_word[23:16];
				next_state <= byte4;
				did_byte_write_flicker <= 1'b1;
			end
		end
		byte4: begin
			if (did_byte_read_flicker == 1'b1) begin
				out_data <= in_word[31:24];
				next_state <= waitwordread;
				did_byte_write_flicker <= 1'b0;
				did_word_write_flicker <= 1'b1;
			end
		end
		waitwordread: begin
			if (did_word_read_flicker == 1'b1) begin
				next_state <= waitwordack;
				did_word_write_flicker <= 1'b0;
			end
		end
	endcase
end

endmodule

`default_nettype wire