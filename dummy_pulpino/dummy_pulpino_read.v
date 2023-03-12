`timescale 1ns / 1ps
`default_nettype none 

module dummy_pulpino_read(
	input wire [7:0] in_data,
	input wire did_word_write_flicker,
	input wire did_byte_write_flicker,

	output reg [31:0] out_word,
	output reg did_word_read_flicker,
	output reg did_byte_read_flicker,

	input wire rst_n,
	input wire clk

);

reg [2:0] state;
reg [2:0] next_state;

localparam
	WaitWordWrite = 3'b000,
	Byte1		  = 3'b001,
	Byte2		  = 3'b010,
	Byte3		  = 3'b011,
	Byte4		  = 3'b100,
	WaitWordAck   = 3'b101;

always @ (posedge clk) begin
	if (~rst_n)
		state <= WaitWordWrite;
	else
		state <= next_state;
end

always @ (state, did_word_write_flicker, did_byte_write_flicker)
begin
    next_state <= state;
    
    did_byte_read_flicker <= did_byte_read_flicker;
    did_word_read_flicker <= did_word_read_flicker;
    
	case (state)
		WaitWordWrite: begin
			did_byte_read_flicker <= 1'b0;
			did_word_read_flicker <= 1'b0;

			out_word <= 32'h0000_0000;
			
			if (did_word_write_flicker == 1'b1)
				next_state <= Byte1;
		end
		Byte1: begin
			if (did_byte_write_flicker == 1'b1) begin
				out_word[7:0] <= in_data;
				next_state <= Byte2;
				did_byte_read_flicker <= 1'b1;
			end
		end
		Byte2: begin
			if (did_byte_write_flicker == 1'b0) begin
				out_word[15:8] <= in_data;
				next_state <= Byte3;
				did_byte_read_flicker <= 1'b0;
			end
		end
		Byte3: begin
			if (did_byte_write_flicker == 1'b1) begin
				out_word[23:16] <= in_data;
				next_state <= Byte4;
				did_byte_read_flicker <= 1'b1;
			end
		end
		Byte4: begin
			if (did_byte_write_flicker == 1'b0) begin
				out_word[31:24] <= in_data;
				next_state <= WaitWordAck;
				did_byte_read_flicker <= 1'b0;
				did_word_read_flicker <= 1'b1;
			end
		end
		WaitWordAck: begin
			if (did_word_write_flicker == 1'b0) begin
				next_state <= WaitWordWrite;
				did_word_read_flicker <= 1'b0;
			end
		end
	endcase
end

endmodule

`default_nettype wire