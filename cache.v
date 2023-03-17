`default_nettype none
`timescale 1ns / 1ps

module cache (
    input wire clk,
    input wire reset,

    input wire [31:0] req_addr,
    input wire [31:0] req_data,
    input wire  [1:0] req_type,
    
    input wire req_do,
    
    output wire [31:0] O_data,
    output wire req_done
);
    // 24 bits = tag
    // 1  bit  = valid
    // 32 bits = content
    // -------+
    // 57 bits
    reg [(24 + 1 + 31):0] sets [63:0];
    
    reg [6:0] current_set;
    reg [6:0] next_set;

    reg [0:0] current_block;
    reg [0:0] next_block;

    reg [31:0] proc_data;
    reg [31:0] next_proc_data;

    reg  [1:0] proc_type;
    reg  [1:0] next_proc_type;
    
    reg [31:0] proc_addr;
    reg [31:0] next_proc_addr;
    
    reg        next_do_write;
    reg        next_do_invalidate;
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
        RequestRead         = 2'b00,
        RequestWrite        = 2'b01,
		RequestFlush        = 2'b10;
        
    assign req_done = state == Done;
    assign O_data   = (req_done && proc_type == RequestRead) ? 
        sets[current_set][31:0] : 32'b0;
    
    reg next_bs_req_type;
    reg bs_req_type;
    
    reg [31:0] next_bs_req_data;
    reg [31:0] bs_req_data;
    
    wire [31:0] bs_O_data;
    wire        bs_req_done;
    
    backing_store U_backing_store (
        .clk         (clk),
        .reset       (reset),

        .req_addr    (proc_addr),
        .req_data    (bs_req_data),
        .req_type    (bs_req_type),
    
        .req_do      (state == RequestBackingStore),
    
        .O_data      (bs_O_data),
        .req_done    (bs_req_done)
    );
    
    
    integer i, j;
    always @ (posedge clk, posedge reset) begin
        if (reset) begin
            state <= NoRequest;

            current_set   <= 6'b0;
            current_block <= 1'b0;

            proc_data <= 32'b0;
            proc_type <=  2'b0;
            proc_addr <= 32'b0;

            bs_req_type <=  2'b0;
            bs_req_data <= 32'b0;

            for (i = 0; i < 64; i = i + 1) begin
                sets[i][56:0] <= 0;
            end
        end
        else begin
            state <= next_state;

            current_set   <= next_set;
            current_block <= next_block;

            proc_data <= next_proc_data;
            proc_type <= next_proc_type;
            proc_addr <= next_proc_addr;

            bs_req_type <= next_bs_req_type;
            bs_req_data <= next_bs_req_data;
            
			if (next_do_write)
				sets[current_set] <= {
					proc_addr[31:8], // Tag
					1'b1,            // Validity
					next_content     // Content
				};
            if (next_do_invalidate)
				sets[current_set][32] <= 1'b0;
        end
    end
    
    always @ (
        state,
        current_set, current_block,
        req_addr, req_data, req_type, req_do,
        bs_req_done, bs_O_data,
        proc_type, proc_data, proc_addr
     ) begin
        next_state     = state;

        next_set       = current_set;
        next_block     = current_block;

        next_proc_data = proc_data;
        next_proc_addr = proc_addr;
        next_proc_type = proc_type;

        next_bs_req_type = bs_req_type;
        next_bs_req_data = bs_req_data;

        next_do_write      = 1'b0;
        next_do_invalidate = 1'b0;
        next_content   = 32'b0;
        
        case (state)
            NoRequest: begin
                next_set  = 6'b0;
                next_block = 1'b0;

                next_proc_data = 32'b0;
                next_proc_type =  2'b0;
                next_proc_addr = 32'b0;

                if (req_do) begin
                    next_proc_data = req_data;
                    next_proc_type = req_type;
                    next_proc_addr = req_addr;

                    next_state = FindSet;
                end
            end
            FindSet: begin
                next_set = proc_addr[7:2];

                next_state = FindBlock;
            end
            FindBlock: begin
                // TODO: Change for different associavity
                // Change for replacement policy
                next_block = 1'b0;

                case (proc_type)
                    RequestRead: begin
                        if (
                            sets[current_set][32] &&                       // Validity
                            sets[current_set][56:33] == proc_addr[31:8]    // Correct Tag
                        )
                            next_state = Done;
                        else begin
                            next_bs_req_type = 1'b0; // Read
                            next_state = RequestBackingStore;
                        end
                    end
                    RequestWrite: begin
                        next_bs_req_type = 1'b1; // Write
                        next_bs_req_data = proc_data;

                        next_state = RequestBackingStore;
                    end
                    RequestFlush: begin
                        if (
                            sets[current_set][32] &&                       // Validity
                            sets[current_set][56:33] == proc_addr[31:8]    // Correct Tag
                        ) begin
                            next_bs_req_type = 1'b1; // Write
                            next_bs_req_data = sets[current_set][31:0];

                            next_state = RequestBackingStore;
                        end
                        else begin
                            next_state = Done;
                        end
                    end
                endcase
            end
            RequestBackingStore: begin
                next_state = WaitBackingStore;
            end
            WaitBackingStore: begin
                if (bs_req_done) begin
					if (proc_type == RequestRead) begin
                        next_content  = bs_O_data;
						next_do_write = 1'b1;
					end
					else if (proc_type == RequestWrite) begin
                        next_content  = proc_data;
						next_do_write = 1'b1;
					end
					else if (proc_type == RequestFlush) begin
						next_do_invalidate = 1'b1;
					end

                    next_bs_req_type = 1'b0;
                    next_bs_req_data = 32'b0;

                    next_state = Done;
                end
            end
            Done: begin
                next_state = NoRequest;
            end
        endcase
    end
endmodule
`default_nettype wire