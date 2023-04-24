`default_nettype none
`timescale 1ns / 1ps

// All the different replacement policies
localparam
    RP_FIFO = 0, // First-In-First-Out
    RP_RND  = 1, // Random
    RP_LRU  = 2, // Least-Recently Used
    RP_MRU  = 3; // Most-Recently Used
module replacement_policy #(
    parameter WAY_COUNT = 2,
    parameter SET_COUNT = 64,
    parameter POLICY = RP_FIFO
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
    if (POLICY == RP_FIFO) begin
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
    else if (POLICY == RP_RND) begin
        lfsr #(
            .WIDTH($clog2(WAY_COUNT))
        ) U_lfsr (
            .clk   (clk),
            .reset (reset),
            .bits  (replacement_way)
        );

        assign ready           = 1'b1;
    end
    else if (POLICY == RP_LRU || POLICY == RP_MRU) begin
        reg [$clog2(WAY_COUNT)*WAY_COUNT*SET_COUNT-1:0] counters;

        reg update_lru;
        reg [$clog2(WAY_COUNT)-1:0] next_counter_value;
        reg [$clog2(WAY_COUNT)-1:0] current_counter_value;

        reg CS;
        reg NS;

        reg [$clog2(SET_COUNT)-1:0] prev_set;
        reg [$clog2(SET_COUNT)-1:0] next_prev_set;

        reg [$clog2(WAY_COUNT)-1:0] O_replacement_way;
        reg [$clog2(WAY_COUNT)-1:0] next_replacement_way;
        reg next_ready;
        reg O_ready;

        assign replacement_way = O_replacement_way;
        assign ready = O_ready;

        integer i, j, k;
        always @ (posedge clk, posedge reset) begin
            if (reset) begin
                current_counter_value <= 'b0;
                CS <= 'b0;

                prev_set <= 'b0;

                O_replacement_way = 'b0;
				O_ready <= 'b0;

                for (i = 0; i < SET_COUNT; i = i + 1)
                    for (j = 0; j < WAY_COUNT; j = j + 1)
                        counters[(i*WAY_COUNT+j)*$clog2(WAY_COUNT) +: $clog2(WAY_COUNT)] <= WAY_COUNT-1;
            end
            else begin
                current_counter_value <= next_counter_value;
                CS <= NS;
                
                prev_set <= next_prev_set;

                O_replacement_way = next_replacement_way;
				O_ready = next_ready;

                if (update_lru) begin
                    for (i = 0; i < WAY_COUNT; i = i + 1) begin
                        if (i == way)
                            counters[(set*WAY_COUNT+i)*$clog2(WAY_COUNT) +: $clog2(WAY_COUNT)] <= 'b0;
                        else if (counters[(set*WAY_COUNT+i)*$clog2(WAY_COUNT) +: $clog2(WAY_COUNT)] < next_counter_value)
                            counters[(set*WAY_COUNT+i)*$clog2(WAY_COUNT) +: $clog2(WAY_COUNT)] <=
                                counters[(set*WAY_COUNT+i)*$clog2(WAY_COUNT) +: $clog2(WAY_COUNT)] + 1;
                        else
                            counters[(set*WAY_COUNT+i)*$clog2(WAY_COUNT) +: $clog2(WAY_COUNT)] <=
                                counters[(set*WAY_COUNT+i)*$clog2(WAY_COUNT) +: $clog2(WAY_COUNT)];
                    end
                end
            end
        end

        always @ (
            CS,
            counters,
            taken, read, written,
            set, way, prev_set,
            O_replacement_way, O_ready,
            current_counter_value
        ) begin
            NS = CS;

            update_lru = 1'b0;
            next_counter_value = current_counter_value;

            next_replacement_way = O_replacement_way;

			next_prev_set = prev_set;

			next_ready = 1'b0;

            case (CS)
                1'b0: begin
                    next_prev_set = set;

                    for (k = 0; k < WAY_COUNT; k = k + 1) begin
                        if (
                            (POLICY == RP_LRU && counters[(set*WAY_COUNT+k)*$clog2(WAY_COUNT) +: $clog2(WAY_COUNT)] == WAY_COUNT-1) ||
                            (POLICY == RP_MRU && counters[(set*WAY_COUNT+k)*$clog2(WAY_COUNT) +: $clog2(WAY_COUNT)] == 0)
                        )
                            next_replacement_way = k;
                    end

                    NS = 1'b1;
                end
                1'b1: begin
                    if (set != prev_set)
                        NS = 1'b0;
					else if (taken || read || written) begin
                        update_lru = 1'b1;
                        next_counter_value = counters[(set*WAY_COUNT+way)*$clog2(WAY_COUNT) +: $clog2(WAY_COUNT)];
                        NS = 1'b0;
                    end
                    else
                        next_ready = 1'b1;
                end
            endcase
        end
    end
    else
        $error("%m ** Invalid POLICY parameter for `replacement_policy`");
    endgenerate
endmodule
`default_nettype wire