`default_nettype none
`timescale 1ns / 1ps

module cache (
    input wire clk,
    input wire reset,

    input wire [31:0] req_addr,
    input wire [31:0] req_data,
    input wire req_type,
    
    input wire req_do,
    
    output wire [31:0] O_data,
    output wire req_done
);
    // 24 bits = tag
    // 1  bit  = valid
    // 32 bits = content
    // -------+
    // 57 bits
    reg [24 + 1 + 31:0] sets [0:0][63:0];
    
    reg [6:0] current_set;
    reg [6:0] next_set;
    
    reg [31:0] proc_addr;
    reg [31:0] next_proc_addr;
    
    reg        next_do_write;
    reg [31:0] next_content;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    localparam
        NoRequest           = 3'b000,
        FindSet             = 3'b001,
        FindBlock           = 3'b010,
        RequestBackingStore = 3'b011,
        WaitBackingStore    = 3'b100,
        Done                = 3'b101;
     
    localparam
        RequestRead  = 1'b0,
        RequestWrite = 1'b1;
    
    localparam
        DataFromCache = 1'b0,
        DataFromInput = 1'b1;
        
    assign req_done = state == Done;
    assign O_data   = sets[current_set][0];
    
    reg next_bs_req_type;
    reg bg_req_type;
    
    reg next_bg_input_data_type;
    reg bg_input_data_type;
    
    wire [31:0] backing_store_O_data;
    wire        backing_store_req_done;
    
    backing_store U_backing_store (
        .clk         (clk),
        .reset       (reset),

        .req_addr    (proc_addr),
        .req_data    (),
        .req_type    (),
    
        .req_do      (state == RequestBackingStore),
    
        .O_data      (backing_store_O_data),
        .req_done    (backing_store_req_done)
    );
    
    
    integer i;
    always @ (posedge clk, posedge reset) begin
        if (reset) begin
            state <= NoRequest;
            current_set <= 6'b0;
            proc_addr <= 32'b0;
            for (i=0; i<1024; i=i+1) begin
                sets[i][0] <= 57'b0;
            end
        end
        else begin
            state <= next_state;
            current_set <= next_set;
            proc_addr <= next_proc_addr;
            
            if (next_do_write)
                sets[current_set][0] <= next_content;
        end
    end
    
    always @ (state, req_addr, req_data, req_type, req_do) begin
        next_state     = state;
        next_set       = current_set;
        next_proc_addr = proc_addr;
        next_do_write  = 1'b0;
        next_content   = 32'b0;
        
        case (state)
            NoRequest: begin
                next_set  = 6'b0;
                if (req_do) begin
                    next_state = FindSet;
                end
            end
            FindSet: begin
                next_set = req_addr[7:2];
                next_state = FindBlock;
            end
            FindBlock: begin
                if (
                    sets[current_set][0][32] &&                   // Validity
                    sets[current_set][0][56:33] == req_addr[31:8] // Correct Tag
                )
                    next_state = Done;
                else
                    next_state = RequestBackingStore;
            end
            RequestBackingStore: begin
                next_state = WaitBackingStore;
            end
//            WaitBackingStore: begin
//                if (backingstore_req_done) begin
//                    next_content  = backingstore_O_data;
//                    next_do_write = 1'b1;
//                    next_state = Done;
//                end
//            end
//            BackingStoreDone: begin
//                next_state = NoRequest
//            end
            Done: begin
                next_state = NoRequest;
            end
        endcase
    end
endmodule
`default_nettype wire