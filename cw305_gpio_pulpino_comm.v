`default_nettype none
`timescale 1ns / 1ps

module gpio_pulpino_comm (
    input  wire          reset_i,

    // USB -> Pulpino
    input  wire [31:0]   read_data,
    output wire [7:0]    gpio_data_in,
    output reg  [1:0]    data_in_io_turn,
    input  wire [1:0]    data_in_pulpino_turn,

    output reg           data_in_done,

    input  wire          do_read,

    // Pulpino -> USB
    output wire [31:0]   write_data,
    input  wire [7:0]    gpio_data_out,
    output reg           data_out_io_turn,
    input  wire [1:0]    data_out_pulpino_turn,

    output reg           data_out_done,

    input  wire          clk
);
    reg [31:0]           data_in;
    reg [31:0]           data_out;

    reg                  data_in_pulpino_known_turn;
    reg                  data_out_pulpino_known_turn;

    reg                  read_cleared;

    assign gpio_data_in  = data_in[7:0];
    assign write_data    = data_out;

    initial begin
        data_in          <= 32'b0;
        data_in_io_turn  <=  2'b0;
        data_in_done     <=  1'b0;
        data_out         <= 32'b0;
        data_out_io_turn <=  1'b0;
        data_out_done    <=  1'b0;
        read_cleared     <=  1'b1;
    end

    always @ (posedge clk) begin
        if (reset_i) begin
            data_in         <= 32'b0;
            data_in_io_turn <=  2'b0;
            data_in_done    <=  1'b0;
            read_cleared    <=  1'b1;
        end
        else begin
            if (do_read == 1'b1 && read_cleared == 1'b1) begin
                read_cleared      <= 1'b0;
                data_in           <= read_data;
                data_in_io_turn   <= 2'b11;
            end
            else begin
                if (do_read == 1'b0 && read_cleared == 1'b0) begin
                    read_cleared  <= 1'b1;
                end

                if (data_in_pulpino_turn[0] != data_in_pulpino_known_turn) begin
                    if (data_in_pulpino_turn[1]) begin
                        data_in_done <= !data_in_done;
                    end
                    else begin
                        data_in_io_turn[1] <= 1'b0;
                        data_in_io_turn[0] <= !data_in_io_turn[0];
                        data_in <= data_in >> 8;
                    end
                end
            end

            data_in_pulpino_known_turn <= data_in_pulpino_turn[0];
        end
    end

    always @ (posedge clk) begin
        if (reset_i) begin
            data_out         <= 32'b0;
            data_out_io_turn <=  1'b0;
            data_out_done    <=  1'b0;
        end
        else begin
            if (data_out_pulpino_turn[0] != data_out_pulpino_known_turn) begin
                if (data_out_pulpino_turn[1]) begin
                    data_out_done <= !data_out_done;
                end

                data_out      <= {gpio_data_out, data_out[31:8]};
                data_out_io_turn  <= !data_out_io_turn;
            end

            data_out_pulpino_known_turn <= data_out_pulpino_turn[0];
        end
    end
endmodule

`default_nettype wire
