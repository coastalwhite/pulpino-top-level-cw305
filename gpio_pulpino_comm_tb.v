`timescale 1ns / 1ps

module gpio_pulpino_comm_tb();
    reg reset_i;
    
    reg [31:0] read_data;
    wire [7:0] gpio_data_in;
    wire [1:0] data_in_io_turn;
    reg [1:0] data_in_pulpino_turn;
    
    wire data_in_done;
    
    reg do_read;
    
    wire [31:0] write_data;
    reg [7:0] gpio_data_out;
    wire data_out_io_turn;
    reg [1:0] data_out_pulpino_turn;
    
    wire data_out_done;
    
    reg clk;
    
    gpio_pulpino_comm inst (
        .reset_i                       (reset_i),

        // USB -> Pulpino
        .read_data                     (read_data),
        .gpio_data_in                  (gpio_data_in),
        .data_in_io_turn               (data_in_io_turn),
        .data_in_pulpino_turn          (data_in_pulpino_turn),

        .data_in_done                  (data_in_done),

        .do_read                       (do_read),

        // Pulpino -> USB
        .write_data                    (write_data),
        .gpio_data_out                 (gpio_data_out),
        .data_out_io_turn              (data_out_io_turn),
        .data_out_pulpino_turn         (data_out_pulpino_turn),
    
        .data_out_done                 (data_out_done),
    
        .clk(clk)
    );
    
    always #5 clk = ~clk;
    
    initial begin
        #0
        clk        <= 1'b0;
        reset_i    <= 1'b1;
        data_in_pulpino_turn <= 2'b00;
        data_out_pulpino_turn <= 2'b00;

        #10
        reset_i   <= 1'b0;
        
        // READ
        do_read   <= 1'b1;
        read_data <= 32'h1234_ABCD;

        #10
        do_read   <= 1'b0;
        
        #10
        data_in_pulpino_turn <= 2'b01;
        
        #20
        data_in_pulpino_turn <= 2'b00;
        
        #20
        data_in_pulpino_turn <= 2'b01;
        
        #20
        data_in_pulpino_turn <= 2'b10;
        
        // WRITE
        #20
        gpio_data_out <= 8'hcd;
        data_out_pulpino_turn <= 2'b01;
        
        #20
        gpio_data_out <= 8'hab;
        data_out_pulpino_turn <= 2'b00;
        
        #20
        gpio_data_out <= 8'h34;
        data_out_pulpino_turn <= 2'b01;
        
        #20
        gpio_data_out <= 8'h12;
        data_out_pulpino_turn <= 2'b10;
    end
endmodule