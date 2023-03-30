`default_nettype none
`timescale 1ns / 1ps

// Policies:
// 0 = FIFO
// 1 = Random
module replacement_policy #(
    parameter WAY_COUNT = 2,
    parameter SET_COUNT = 64,
    parameter POLICY = 0
) (
    input wire clk,
    input wire reset,

    input wire [$clog2(SET_COUNT)-1:0] set,
    input wire [$clog2(WAY_COUNT)-1:0] way,

    // `way` that is selected for replacement within the `set`
    output wire [$clog2(WAY_COUNT)-1:0] replacement_way,

    // Pulse for a single clock cycle when the `set` + `way` has been read.
    input wire read,
    // Pulse for a single clock cycle when the `set` + `way` has been written
    // to.
    input wire written,

    // Pulse for a single clock cycle when the `replacement_way` is used to
    // replace a way.
    input wire taken,
    output wire ready
);
    generate
    if (POLICY == 0) begin
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

        assign replacement_way = fifo_counters[set];
        assign ready           = 1'b1;
    end
    else if (POLICY == 1) begin
        lfsr #(
            .WIDTH($clog2(WAY_COUNT))
        ) U_lfsr (
            .clk   (clk),
            .reset (reset),
            .bits  (replacement_way)
        );

        assign ready           = 1'b1;
    end
    else
        $error("%m ** Invalid POLICY parameter for `replacement_policy`");
    endgenerate
endmodule
`default_nettype wire