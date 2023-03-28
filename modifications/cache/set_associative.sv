`default_nettype none
`timescale 1ns / 1ps

module set_associative_cache #(
    parameter WAY_COUNT = 2,
    parameter SET_COUNT = 64,
    parameter WAY_WORD_COUNT = 4,

	parameter WAY_WORD_IDX_START = 2,
	parameter WAY_WORD_IDX_END   = WAY_WORD_IDX_START + $clog2(WAY_WORD_COUNT) - 1,
	parameter WAY_WORD_IDX_SIZE  = WAY_WORD_IDX_END - WAY_WORD_IDX_START + 1,

	parameter SET_IDX_START      = WAY_WORD_IDX_END + 1,
	parameter SET_IDX_END        = SET_IDX_START + $clog2(SET_COUNT) - 1,
	parameter SET_IDX_SIZE       = SET_IDX_END - SET_IDX_START + 1,

	parameter TAG_IDX_START      = SET_IDX_END + 1,
	parameter TAG_IDX_END        = 31,
	parameter TAG_IDX_SIZE       = TAG_IDX_END - TAG_IDX_START + 1
) (
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

	reg                    line_validity [SET_COUNT][WAY_COUNT];
	reg [TAG_IDX_SIZE-1:0] line_tags     [SET_COUNT][WAY_COUNT];
    reg [31:0]             lines         [SET_COUNT][WAY_COUNT][WAY_WORD_COUNT];

    reg [$clog2(WAY_COUNT)-1:0] fifo_counters [SET_COUNT];

    reg [$clog2(SET_COUNT)-1:0] next_set;
    reg [$clog2(SET_COUNT)-1:0] current_set;

    reg [$clog2(WAY_COUNT)-1:0] current_block;
    reg [$clog2(WAY_COUNT)-1:0] next_block;

    reg [$clog2(WAY_COUNT)-1:0] block_det_outs [2];
    reg block_det_valid [2];

    reg [31:0] proc_data;
    reg        proc_write_enable;
	reg [3:0]  proc_be;
    reg [31:0] proc_addr;

    // *** Utility wires ***
    // The tag in the proc_addr
    wire [TAG_IDX_SIZE-1:0] proc_tag;
    // The set in the proc_addr
    wire [SET_IDX_SIZE-1:0] proc_set;
    // The word in the way of the proc_addr
    wire [WAY_WORD_IDX_SIZE-1:0] proc_way_word;

    assign proc_tag      = proc_addr[TAG_IDX_END:TAG_IDX_START];
    assign proc_set      = proc_addr[SET_IDX_END:SET_IDX_START];
    assign proc_way_word = proc_addr[WAY_WORD_IDX_END:WAY_WORD_IDX_START];

    reg [31:0] next_proc_data;
    reg        next_proc_write_enable;
    reg [3:0]  next_proc_be;
    reg [31:0] next_proc_addr;
    
    reg        fifo_do_increase;
    reg        next_do_write;
    reg [31:0] next_content [WAY_WORD_COUNT];
    
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

    assign core_rdata_o   = lines[current_set][current_block][proc_way_word];
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

    integer i, j, k, bi, top_bit, bot_bit;
    always @ (posedge clk, posedge reset) begin
        if (reset) begin
            state       <= NoRequest;

            current_set   <= 6'b0;
            current_block <=  'b0;

            proc_data         <= 32'b0;
            proc_write_enable <= 1'b0;
            proc_addr         <= 32'b0;
            proc_be           <= 4'b0;

            bs_req_do       <= 1'b0;
            bs_write_enable <= 1'b0;
            bs_wdata <= 32'b0;

            for (i = 0; i < SET_COUNT; i = i + 1) begin
                for (j = 0; j < WAY_COUNT; j = j + 1) begin
					for (k = 0; k < WAY_WORD_COUNT; k = k + 1) begin
						lines[i][j][k] <= 32'b0;
					end 

					line_validity[i][j] <= 'b0;
					line_tags[i][j] <= 'b0;
                end

                fifo_counters[i] <= 'b0;
            end
        end
        else begin
            state       <= next_state;

            current_set   <= next_set;
            current_block <= next_block;

            proc_data         <= next_proc_data;
            proc_write_enable <= next_proc_write_enable;
            proc_addr         <= next_proc_addr;
            proc_be           <= next_proc_be;

            bs_req_do       <= next_bs_req_do;
            bs_write_enable <= next_bs_write_enable;
            bs_wdata <= next_bs_wdata;
            
			if (next_do_write) begin
				line_tags[current_set][current_block] = proc_tag;
				line_validity[current_set][current_block] = CacheLineValid;
				lines[current_set][current_block] <= next_content;
			end

            if (fifo_do_increase)
                if (fifo_counters[current_set] == WAY_COUNT - 1)
                    fifo_counters[current_set] <= 'b0;
                else
                    fifo_counters[current_set] <= fifo_counters[current_set] + 1;

        end
    end
    
    always @ (
        state,
        current_set,
        core_addr_i, core_wdata_i, core_we_i, core_be_i, core_req_i,
        mem_rvalid_i, mem_gnt_i, mem_rdata_i,
        proc_write_enable, proc_data, proc_addr, proc_be,
        bs_wdata, bs_write_enable,
        lines, line_validity, line_tags, fifo_counters
     ) begin
        next_state         = state;

        next_set           = current_set;
        next_block         = current_block;

        next_proc_data         = proc_data;
        next_proc_addr         = proc_addr;
        next_proc_write_enable = proc_write_enable;
        next_proc_be           = proc_be;

        next_bs_req_do       = 1'b0;
        next_bs_write_enable = 1'b0;
        next_bs_wdata        = bs_wdata;

        fifo_do_increase   =  1'b0;
        next_do_write      =  1'b0;
		for (i = 0; i < WAY_WORD_COUNT; i = i + 1) begin
			next_content[i] = 32'b0;
		end

        for (i = 0; i < 2; i = i + 1) begin
            block_det_outs[i] <= 'b0;
            block_det_valid[i] <= 0;
        end
        
        case (state)
            NoRequest: begin
                next_set       = 6'b0;
                next_block  =  'b0;

                next_proc_data         = 32'b0;
                next_proc_write_enable = 1'b0; // CacheRead is just the default type
                next_proc_addr         = 32'b0;
                next_proc_be           = 4'b0;

                if (core_req_i) begin
                    next_proc_data = core_wdata_i;
                    next_proc_write_enable = core_we_i;
                    next_proc_be = core_be_i;
                    next_proc_addr = core_addr_i;

                    next_state = FindSet;
                end
            end
            FindSet: begin
                next_set   = proc_set;
                next_state = FindBlock;
            end
            FindBlock: begin
				// FindBlock has 3 steps. If at any of these steps it finds
				// a suitable block it will move on.
				// 1. See if the `tag` is already in the cache
				// 2. See if there is an empty block
				// 3. Find the next FIFO determined block
                for (j = 0; j < WAY_COUNT; j = j + 1) begin
                    if (
                        line_validity[current_set][j] == CacheLineValid &&
                        line_tags[current_set][j] == proc_tag
                    ) begin
                        block_det_outs[0] = j;
                        block_det_valid[0] = 1;
                        
                        break;
                    end
                end
                
                for (j = 0; j < WAY_COUNT; j = j + 1) begin
                    if (line_validity[current_set][j] == CacheLineInvalid) begin
                        block_det_outs[1] = j;
                        block_det_valid[1] = 1;

                        break;
                    end
                end

                if (block_det_valid[0]) begin
                    // Cache Hit
                    next_block = block_det_outs[0];

                    // Cache hit
                    if (~proc_write_enable)
                        next_state = Done;
                    else
                        next_state = WriteCache;
                end
                else if (block_det_valid[1]) begin
                    // Cache Miss - With Empty Block
                    next_block = block_det_outs[1];

                    next_state = ReadMemReq;
                end
                else begin
                    // Cache Miss - Without Empty Block
                    next_block = fifo_counters[current_set];
                    fifo_do_increase = 1'b1;

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
					for (i = 0; i < WAY_WORD_COUNT; i = i + 1) begin
						if (i == proc_way_word)
							next_content[i] = mem_rdata_i;
						else
							next_content[i] = lines[current_set][current_block][i];
					end
                    next_do_write = 1'b1;

                    if (~proc_write_enable)
                        next_state = Done;
                    else
                        next_state = WriteCache;
                end
			end
            WriteCache: begin
				next_do_write = 1'b1;

				for (i = 0; i < WAY_WORD_COUNT; i = i + 1) begin
					if (i == proc_way_word) begin
						for (bi = 0; bi < 4; bi = bi + 1) begin
							if (proc_be[bi])
								next_content[i][(bi+1)*8-1 -: 8] = proc_data[(bi+1)*8-1 -: 8];
							else
								next_content[i][(bi+1)*8-1 -: 8] = lines[current_set][current_block][i][(bi+1)*8-1 -: 8];
						end
					end
					else
						next_content[i] = lines[current_set][current_block][i];
				end

                next_state = WriteMemReq;
            end
			WriteMemReq: begin
				next_bs_req_do       = 1'b1;
				next_bs_write_enable = 1'b1;
				next_bs_wdata        = lines[current_set][current_block][proc_way_word];

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
                if (core_req_i) begin
                    next_proc_data = core_wdata_i;
                    next_proc_write_enable = core_we_i;
                    next_proc_be = core_be_i;
                    next_proc_addr = core_addr_i;

                    next_state = FindSet;
                end
                else
                    next_state = NoRequest;
            end
        endcase
    end
endmodule
`default_nettype wire