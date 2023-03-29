`default_nettype none
`timescale 1ns / 1ps

module replacement_policy #(
    parameter WAY_COUNT = 2,
    parameter SET_COUNT = 64
) (
    input wire clk,
    input wire reset,

    input wire [$clog2(SET_COUNT)-1:0] set,
    output wire [$clog2(WAY_COUNT)-1:0] way,

    input wire taken,
    output wire ready
);
    reg [$clog2(WAY_COUNT)-1:0] fifo_counters [SET_COUNT-1:0];

    integer i;
    always @ (posedge clk, posedge reset) begin
        if (reset) begin
            for (i = 0; i < SET_COUNT; i = i + 1)
                fifo_counters[i] <= 'b0;
        end
        else begin
            if (taken)
                fifo_counters[set] <= fifo_counters[set] + 1;
        end
    end

    assign way   = fifo_counters[set];
    assign ready = 1'b1;
endmodule
`default_nettype wire