`default_nettype none
`timescale 1ns / 1ps

// NOTE: This is a really bad implementation of LFSR.
// Don't ever use this in a real design.

module lfsr #(
    parameter WIDTH = 8
) (
    input wire clk,
    input wire reset,

    output wire [WIDTH-1:0] bits
);
    reg [16 + WIDTH - 1:0] shift_reg;

    always @ (posedge clk, posedge reset) begin
        if (reset)
            shift_reg <= 'b0;
        else
            shift_reg[16 + WIDTH - 2:0] <= shift_reg[16 + WIDTH - 1:1];
            shift_reg[16 + WIDTH - 1] <= (
                shift_reg[WIDTH + 5] ~^
                shift_reg[WIDTH + 3] ~^
                shift_reg[WIDTH + 2] ~^
                shift_reg[WIDTH]
            );
    end

    assign bits = shift_reg[WIDTH-1:0];
endmodule
`default_nettype wire