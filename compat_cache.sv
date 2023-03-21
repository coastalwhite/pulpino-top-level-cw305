`default_nettype none
`timescale 1ns / 1ps

module compat_cache (
    input wire         clk,
    input wire         reset,

    // Core Side
    input wire  [31:0] core_addr_i,
    input wire  [31:0] core_wdata_i,
    input wire         core_we_i,
    input wire         core_req_i,
    input wire  [3:0]  core_be_i, // Write Byte Mask

    output wire [31:0] core_rdata_o,
    output wire        core_gnt_o, // Access Granted
    output wire        core_rvalid_o, // Request Valid
    output wire        core_error_o,

    // Memory Side
    output wire [31:0] mem_addr_o,
    output wire [31:0] mem_wdata_o,
    output wire        mem_we_o,
    output wire        mem_req_o,
    output wire [3:0]  mem_be_o,

    input wire  [31:0] mem_rdata_i,
    input wire         mem_gnt_i,
    input wire         mem_rvalid_i,
    input wire         mem_error_i
);
    // 24 bits = tag
    // 1  bit  = valid
    // 32 bits = content
    // -------+
    // 57 bits
    reg [63:0] sets [63:0];

    reg [6:0] current_set;
    reg [6:0] next_set;

    reg [31:0] proc_data;
    reg        proc_write_enable;
	reg [3:0]  proc_be;
    reg [31:0] proc_addr;

    reg [31:0] next_proc_data;
    reg        next_proc_write_enable;
    reg [3:0]  next_proc_be;
    reg [31:0] next_proc_addr;
    
    reg        next_do_write;
    reg [31:0] next_content;
    
    reg [3:0] state;
    reg [3:0] next_state;

    reg bs_write_enable;
    reg bs_req_do;
    reg [31:0] bs_wdata;

    reg next_bs_write_enable;
    reg next_bs_req_do;
    reg [31:0] next_bs_wdata;
    
    localparam
        NoRequest           = 4'b0000,
        FindSet             = 4'b0001,
        FindBlock           = 4'b0010,
        ReadMemReq          = 4'b0011,
        ReadMemWait         = 4'b0100,
        WriteCache          = 4'b0101,
        WriteMemReq         = 4'b0110,
        WriteMemWait        = 4'b0111,
        Done                = 4'b1000;

    localparam
        CacheLineValid      = 1'b1,
        CacheLineInvalid    = 1'b0;

    assign core_rdata_o   = sets[current_set][31:0];
    assign core_gnt_o     = state == FindSet;
    assign core_rvalid_o  = state == Done;
    // NOTE: In the pulpino core this is just set to zero.
    assign core_error_o   = 1'b0;

    // Memory Side
    assign mem_addr_o     = proc_addr;
    assign mem_wdata_o    = bs_wdata;
    assign mem_we_o       = bs_write_enable;
    assign mem_req_o      = bs_req_do;
    assign mem_be_o       = 4'b1111;

    integer i, bi, top_bit, bot_bit;
    always @ (posedge clk, posedge reset) begin
        if (reset) begin
            state       <= NoRequest;

            current_set <= 6'b0;

            proc_data         <= 32'b0;
            proc_write_enable <= 1'b0;
            proc_addr         <= 32'b0;
            proc_be           <= 4'b0;

            bs_req_do       <= 1'b0;
            bs_write_enable <= 1'b0;
            bs_wdata <= 32'b0;

            for (i = 0; i < 64; i = i + 1) begin
                sets[i] <= {
                    7'b0,             // Padding
					24'b0,            // Tag
					CacheLineInvalid, // Validity 
					32'b0             // Content
				};
            end
        end
        else begin
            state       <= next_state;

            current_set <= next_set;

            proc_data         <= next_proc_data;
            proc_write_enable <= next_proc_write_enable;
            proc_addr         <= next_proc_addr;
            proc_be           <= next_proc_be;

            bs_req_do       <= next_bs_req_do;
            bs_write_enable <= next_bs_write_enable;
            bs_wdata <= next_bs_wdata;
            
			if (next_do_write)
				sets[current_set] <= {
                    7'b0,            // Padding
					proc_addr[31:8], // Tag
					CacheLineValid,  // Validity
					next_content     // Content
				};
        end
    end
    
    always @ (
        state,
        current_set,
        core_addr_i, core_wdata_i, core_we_i, core_be_i, core_req_i,
        mem_rvalid_i, mem_gnt_i, mem_rdata_i,
        proc_write_enable, proc_data, proc_addr, proc_be,
        bs_wdata, bs_write_enable,
        sets
     ) begin
        next_state         = state;

        next_set           = current_set;

        next_proc_data         = proc_data;
        next_proc_addr         = proc_addr;
        next_proc_write_enable = proc_write_enable;
        next_proc_be           = proc_be;

        next_bs_req_do       = 1'b0;
        next_bs_write_enable = 1'b0;
        next_bs_wdata        = bs_wdata;

        next_do_write      =  1'b0;
        next_content       = 32'b0;
        
        case (state)
            NoRequest: begin
                next_set       = 6'b0;

                next_proc_data         = 32'b0;
                next_proc_write_enable = 1'b0; // CacheRead is just the default type
                next_proc_addr         = 32'b0;

                if (core_req_i) begin
                    next_proc_data = core_wdata_i;
                    next_proc_write_enable = core_we_i;
                    next_proc_be = core_be_i;
                    next_proc_addr = core_addr_i;

                    next_state = FindSet;
                end
            end
            FindSet: begin
                next_set   = proc_addr[7:2];

                next_state = FindBlock;
            end
            FindBlock: begin
				if (
					sets[current_set][32] == CacheLineValid &&     // Validity
					sets[current_set][56:33] == proc_addr[31:8]    // Correct Tag
				) begin
					// Cache hit
					if (~proc_write_enable)
                        next_state = Done;
                    else
                        next_state = WriteCache;
                end
                else begin
					// Cache Miss
					next_state = ReadMemReq;
                end
            end
			ReadMemReq: begin
				next_bs_req_do       = 1'b1;
				next_bs_write_enable = 1'b0;
				next_bs_wdata        = 32'b0;

                if (mem_gnt_i) begin
                    next_state = ReadMemWait;
                end
			end
			ReadMemWait: begin
                if (mem_rvalid_i) begin
                    next_content  = mem_rdata_i;
                    next_do_write = 1'b1;

                    if (~proc_write_enable)
                        next_state = Done;
                    else
                        next_state = WriteCache;
                end
			end
            WriteCache: begin
				next_do_write = 1'b1;

				for (bi = 0; bi < 4; bi = bi + 1) begin
					if (proc_be[bi])
						next_content[(bi+1)*8-1 -: 8] = proc_data[(bi+1)*8-1 -: 8];
					else
						next_content[(bi+1)*8-1 -: 8] = sets[current_set][(bi+1)*8-1 -: 8];
				end

                next_state = WriteMemReq;
            end
			WriteMemReq: begin
				next_bs_req_do       = 1'b1;
				next_bs_write_enable = 1'b1;
				next_bs_wdata        = sets[current_set][31:0];

                if (mem_rvalid_i) begin
                    next_state = WriteMemWait;
                end
			end
			WriteMemWait: begin
                if (mem_rvalid_i) begin
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