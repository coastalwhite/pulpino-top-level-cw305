`default_nettype none
`timescale 1ns / 1ps
module backing_store(
    input wire clk,
    input wire reset,

    input wire [31:0] req_addr,
    input wire [31:0] req_data,
    input wire req_type,
    
    input wire req_do,
    
    output wire [31:0] O_data,
    output wire req_done
);
    reg [7:0] data [1023:0];
    
    reg [1:0] state;
    reg [1:0] next_state;
    
    reg [1:0] proc_cnt;
    reg [1:0] next_proc_cnt;
    
    reg next_do_write;
    reg [31:0] next_content;
    
    reg [31:0] proc_addr;
    reg [31:0] next_proc_addr;
    
    reg proc_type;
    reg next_proc_type;
    
    localparam
        RequestRead  = 1'b0,
        RequestWrite = 1'b1;
    
    localparam
        NoRequest           = 2'b00,
        Processing          = 2'b01,
        Done                = 2'b10;
        
    assign req_done = state == Processing && proc_cnt == 2'b11;
    assign O_data   = (req_done && proc_type == RequestRead) ? {
        data[{proc_addr[9:2], 2'b11}],
        data[{proc_addr[9:2], 2'b10}],
        data[{proc_addr[9:2], 2'b01}],
        data[{proc_addr[9:2], 2'b00}]
    } : 32'b0;
    
    integer i;
    always @ (posedge clk, posedge reset) begin
        if (reset) begin
            state <= NoRequest;
            proc_cnt <= 2'b0;
            proc_addr <= 32'b0;
            proc_type <= 1'b0;
            
            for (i = 0; i < 1024; i = i + 1) data[i] <= 8'b00;
        end
        else begin
            state <= next_state;
            proc_cnt <= next_proc_cnt;
            proc_addr <= next_proc_addr;
            proc_type <= next_proc_type;
            
            if (next_do_write) begin
                data[{proc_addr[9:2], 2'b11}] <= next_content[31:24];
                data[{proc_addr[9:2], 2'b10}] <= next_content[23:16];
                data[{proc_addr[9:2], 2'b01}] <= next_content[15: 8];
                data[{proc_addr[9:2], 2'b00}] <= next_content[ 7: 0];
            end
        end
    end
    
    always @ (state, proc_cnt, proc_addr, proc_type, req_addr, req_data, req_type, req_do) begin
        next_state = state;
        next_proc_cnt = proc_cnt;
        next_proc_addr = proc_addr;
        next_proc_type = proc_type;
        next_do_write = 1'b0;
        next_content = 32'b0;
        
        case (state)
            NoRequest: begin
                if (req_do) begin
                    next_proc_addr = req_addr;
                    next_proc_type = req_type;
                    next_state = Processing;
                end
            end
            Processing: begin
                if (proc_cnt == 2'b00 && proc_type == RequestWrite) begin
                    next_do_write = 1'b1;
                    next_content = req_data;
                end
                
                // Introduce some artificial delay
                next_proc_cnt = proc_cnt + 1;
                if (proc_cnt == 2'b11)
                    next_state = NoRequest;
            end
        endcase
    end
endmodule
`default_nettype wire