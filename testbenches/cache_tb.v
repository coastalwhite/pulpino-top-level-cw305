`timescale 1ns / 1ps

module cache_tb();
    reg clk;
    reg reset;
    
    reg [31:0] req_addr;
    reg [31:0] req_data;
    reg        req_type;
    reg        req_do;
    
    wire [31:0] O_data;
    wire        req_done;

    cache U_cache(
        .clk       (clk),
        .reset     (reset),
    
        .req_addr  (req_addr),
        .req_data  (req_data),
        .req_type  (req_type),
        .req_do    (req_do),
        
        .O_data    (O_data),
        .req_done  (req_done)
    );
    
    always #5 clk <= ~clk;
    
    initial begin
        clk <= 1'b1;
        reset <= 1'b1;
        req_do   <=  1'b0;
        req_addr <= 32'h0000_0000;
        req_data <= 32'h0000_0000;
        req_type <=  1'b0;
        
        #10
        reset <= 1'b0;

        #10
        req_addr <= 32'h0000_03FC;
        req_data <= 32'h0000_0000;
        req_type <=  1'b0;
        req_do   <=  1'b1;
        
        #10
        req_do   <=  1'b0;
        
        #10
        req_addr <= 32'h0000_0000;
        
        #70
        req_addr <= 32'h0000_0200;
        req_data <= 32'h0000_0000;
        req_type <=  1'b0;
        req_do   <=  1'b1;
        
        #10
        req_do   <=  1'b0;

        #10
        req_addr <= 32'h0000_0000;
        
        #70
        req_addr <= 32'h0000_03FC;
        req_data <= 32'hAABB_CCDD;
        req_type <=  1'b1;
        req_do   <=  1'b1;
        
        #10
        req_do   <=  1'b0;
        
        #10
        req_addr <= 32'h2222_2222;
        req_data <= 32'h3333_3333;
        req_type <=  1'b0;
        
        #70
        req_addr <= 32'h0000_0200;
        req_data <= 32'h1234_5678;
        req_type <=  1'b1;
        req_do   <=  1'b1;
        
        #10
        req_do   <=  1'b0;
        
        #10
        req_addr <= 32'h2222_2222;
        req_data <= 32'h3333_3333;
        req_type <=  1'b0;
        
        #70
        req_addr <= 32'h0000_03FC;
        req_data <= 32'h0000_0000;
        req_type <=  1'b0;
        req_do   <=  1'b1;
        
        #10
        req_do   <=  1'b0;
        
        #10
        req_addr <= 32'h0000_0000;
        
        #50
        req_addr <= 32'h0000_0200;
        req_data <= 32'h0000_0000;
        req_type <=  1'b0;
        req_do   <=  1'b1;
        
        #10
        req_do   <=  1'b0;
        
        #50
        req_addr <= 32'h0000_0000;
        
    end
endmodule