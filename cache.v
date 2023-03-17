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
        CacheRead           = 2'b00,
        CacheWrite          = 2'b01,
		CacheFlush          = 2'b10;

    localparam
        BackingStoreRead    = 1'b0,
        BackingStoreWrite   = 1'b1;

    localparam
        CacheLineValid      = 1'b0,
        CacheLineInvalid   = 1'b1;
        
    assign req_done = state == Done;
    assign O_data   = (
		req_done && proc_type == CacheRead
	) ? sets[current_set][31:0] : 32'b0;
    
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
    
    integer i;
    always @ (posedge clk, posedge reset) begin
        if (reset) begin
            state       <= NoRequest;

            current_set <= 6'b0;

            proc_data   <= 32'b0;
            proc_type   <= CacheRead;
            proc_addr   <= 32'b0;

            bs_req_type <= BackingStoreRead;
            bs_req_data <= 32'b0;

            for (i = 0; i < 64; i = i + 1) begin
                sets[i][56:0] <= {
					24'b0,            // Tag
					CacheLineInvalid, // Validity 
					32'b0             // Content
				};
            end
        end
        else begin
            state       <= next_state;

            current_set <= next_set;

            proc_data   <= next_proc_data;
            proc_type   <= next_proc_type;
            proc_addr   <= next_proc_addr;

            bs_req_type <= next_bs_req_type;
            bs_req_data <= next_bs_req_data;
            
			if (next_do_write)
				sets[current_set] <= {
					proc_addr[31:8], // Tag
					CacheLineValid,  // Validity
					next_content     // Content
				};
            if (next_do_invalidate)
				sets[current_set][32] <= CacheLineInvalid;
        end
    end
    
    always @ (
        state,
        current_set,
        req_addr, req_data, req_type, req_do,
        bs_req_done, bs_O_data,
        proc_type, proc_data, proc_addr
     ) begin
        next_state         = state;

        next_set           = current_set;

        next_proc_data     = proc_data;
        next_proc_addr     = proc_addr;
        next_proc_type     = proc_type;

        next_bs_req_type   = bs_req_type;
        next_bs_req_data   = bs_req_data;

        next_do_write      =  1'b0;
        next_do_invalidate =  1'b0;
        next_content       = 32'b0;
        
        case (state)
            NoRequest: begin
                next_set       = 6'b0;

                next_proc_data = 32'b0;
                next_proc_type = CacheRead; // CacheRead is just the default type
                next_proc_addr = 32'b0;

                if (req_do) begin
                    next_proc_data = req_data;
                    next_proc_type = req_type;
                    next_proc_addr = req_addr;

                    next_state = FindSet;
                end
            end
            FindSet: begin
                next_set   = proc_addr[7:2];

                next_state = FindBlock;
            end
            FindBlock: begin
                case (proc_type)
                    CacheRead: begin
                        if (
                            sets[current_set][32] &&                       // Validity
                            sets[current_set][56:33] == proc_addr[31:8]    // Correct Tag
                        )
                            next_state = Done;
                        else begin
                            next_bs_req_type = BackingStoreRead;
                            next_state       = RequestBackingStore;
                        end
                    end
                    CacheWrite: begin
                        next_bs_req_type = BackingStoreWrite;
                        next_bs_req_data = proc_data;

                        next_state       = RequestBackingStore;
                    end
                    CacheFlush: begin
                        if (
                            sets[current_set][32] &&                       // Validity
                            sets[current_set][56:33] == proc_addr[31:8]    // Correct Tag
                        ) begin
                            next_bs_req_type = BackingStoreWrite;
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
					if (proc_type == CacheRead) begin
                        next_content  = bs_O_data;
						next_do_write = 1'b1;
					end
					else if (proc_type == CacheWrite) begin
                        next_content  = proc_data;
						next_do_write = 1'b1;
					end
					else if (proc_type == CacheFlush) begin
						next_do_invalidate = 1'b1;
					end

                    next_bs_req_type = BackingStoreRead; // Read is the default type
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