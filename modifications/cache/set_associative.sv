`default_nettype none
`timescale 1ns / 1ps

module set_associative_cache #(
    parameter WAY_COUNT = 2,
    parameter SET_COUNT = 64,
    parameter WAY_WORD_COUNT = 4,

	localparam
              WAY_WORD_IDX_START = 2,
	          WAY_WORD_IDX_END   = WAY_WORD_IDX_START + $clog2(WAY_WORD_COUNT) - 1,
	          WAY_WORD_IDX_SIZE  = WAY_WORD_IDX_END - WAY_WORD_IDX_START + 1,

	          SET_IDX_START      = WAY_WORD_IDX_END + 1,
	          SET_IDX_END        = SET_IDX_START + $clog2(SET_COUNT) - 1,
	          SET_IDX_SIZE       = SET_IDX_END - SET_IDX_START + 1,

	          TAG_IDX_START      = SET_IDX_END + 1,
	          TAG_IDX_END        = 31,
	          TAG_IDX_SIZE       = TAG_IDX_END - TAG_IDX_START + 1
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
    reg cache_we;
    reg next_cache_we;

    reg                         cache_valid_i;
    reg [TAG_IDX_SIZE-1:0]      cache_tag_i;
    reg [WAY_WORD_COUNT*32-1:0] cache_line_i;
    reg [WAY_WORD_COUNT-1:0]    cache_ww_enable_i;

    reg                         next_cache_valid_i;
    reg [TAG_IDX_SIZE-1:0]      next_cache_tag_i;
    reg [WAY_WORD_COUNT*32-1:0] next_cache_line_i;
    reg [WAY_WORD_COUNT-1:0]    next_cache_ww_enable_i;

    wire [WAY_COUNT-1:0]         cache_valid_o;
    wire [WAY_COUNT*TAG_IDX_SIZE-1:0]      cache_tag_o;
    wire [WAY_WORD_COUNT*32-1:0] cache_line_o;

    wire [$clog2(WAY_COUNT)-1:0] replacement_way;
    reg                          replacement_read;
    reg                          replacement_written;
    reg                          replacement_taken;
    wire                         replacement_ready;

    replacement_policy #(
        .WAY_COUNT     (WAY_COUNT),
        .SET_COUNT     (SET_COUNT)
    ) U_replacement (
        .clk(clk),
        .reset(reset),

	    .set(current_set),
        .way(current_way),

	    .replacement_way(replacement_way),

        .read(replacement_read),
        .written(replacement_written),

        .taken(replacement_taken),
        .ready(replacement_ready)
    );

    cache_mem_wrap #(
        .WAY_COUNT     (WAY_COUNT),
        .SET_COUNT     (SET_COUNT),
        .WAY_WORD_COUNT(WAY_WORD_COUNT)
    ) U_memory (
        .clk(clk),
        .reset(reset),

	    .set(current_set),
	    .way(current_way),

	    .enable(1'b1),
	    .write_enable(cache_we),
	    .val_write_enable(1'b0),

	    .line_valid_i(cache_valid_i),
	    .line_tag_i(cache_tag_i),
	    .line_i(cache_line_i),
	    .line_ww_enable_i(cache_ww_enable_i),

        .line_valid_o(cache_valid_o),
        .line_tag_o(cache_tag_o),
        .line_o(cache_line_o)
    );

    reg [$clog2(SET_COUNT)-1:0] next_set;
    reg [$clog2(SET_COUNT)-1:0] current_set;

    reg [$clog2(WAY_COUNT)-1:0] current_way;
    reg [$clog2(WAY_COUNT)-1:0] next_way;

    reg [$clog2(WAY_COUNT)*2-1:0] block_det_outs;
    reg [1:0] block_det_valid;

    reg [$clog2(WAY_COUNT)*2-1:0] next_block_det_outs;
    reg [1:0] next_block_det_valid;

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
    
    reg [3:0] CS;
    reg [3:0] NS;

    reg [31:0] bs_addr;
    reg bs_write_enable;
    reg bs_req_do;
    reg [31:0] bs_wdata;

    reg [31:0] next_bs_addr;
    reg next_bs_write_enable;
    reg next_bs_req_do;
    reg [31:0] next_bs_wdata;

    reg [31:0] core_rdata;
    reg [31:0] next_core_rdata;
    
    reg [$clog2(WAY_WORD_COUNT)-1:0] word_ctr;
    reg word_ctr_do_increase;
    reg word_ctr_do_reset;

    reg [1:0] delay_ctr;
    
    localparam
        NoRequest           = 4'b0000,
        FindSet             = 4'b0001,
        FindBlock           = 4'b0010,
        SelectBlock         = 4'b0011,
        ReadMemReq          = 4'b0100,
        ReadMemWait         = 4'b0101,
        WriteCache          = 4'b0110,
        WriteMemReq         = 4'b0111,
        WriteMemWait        = 4'b1000,
        Done                = 4'b1001,
        WaySelectDelay      = 4'b1010;

    localparam
        CacheLineValid      = 1'b1,
        CacheLineInvalid    = 1'b0;

    assign core_rdata_o   = core_rdata;
    assign core_gnt_o     = CS == FindSet;
    assign core_rvalid_o  = CS == Done;
    // NOTE: In the pulpino core this is just set to zero.
    assign core_error_o   = 1'b0;

    // Memory Side
    assign mem_addr_o     = bs_addr;
    assign mem_wdata_o    = bs_wdata;
    assign mem_we_o       = bs_write_enable;
    assign mem_req_o      = bs_req_do;
    assign mem_be_o       = 4'b1111;

    integer i, j;
    always @ (posedge clk, posedge reset) begin
        if (reset) begin
            CS       <= NoRequest;

            current_set   <= 6'b0;
            current_way <=  'b0;

            block_det_outs    <=  'b0;
            block_det_valid   <= 2'b00;

            proc_data         <= 32'b0;
            proc_write_enable <= 1'b0;
            proc_addr         <= 32'b0;
            proc_be           <= 4'b0;

            cache_valid_i     <= 1'b0;
            cache_tag_i       <=  'b0;
            cache_line_i      <=  'b0;
            cache_ww_enable_i <=  'b0;

            bs_addr <= 32'b0;
            bs_req_do       <= 1'b0;
            bs_write_enable <= 1'b0;
            bs_wdata <= 32'b0;

            core_rdata <= 32'b0;

            cache_we <= 1'b0;

			delay_ctr <= 2'b11;

            word_ctr <= 32'b0;
        end
        else begin
            CS       <= NS;

            current_set   <= next_set;
            current_way <= next_way;

            block_det_outs    <= next_block_det_outs;
            block_det_valid   <= next_block_det_valid;

            proc_data         <= next_proc_data;
            proc_write_enable <= next_proc_write_enable;
            proc_addr         <= next_proc_addr;
            proc_be           <= next_proc_be;

            cache_valid_i     <= next_cache_valid_i;
            cache_tag_i       <= next_cache_tag_i;
            cache_line_i      <= next_cache_line_i;
            cache_ww_enable_i <= next_cache_ww_enable_i;

            bs_addr <= next_bs_addr;
            bs_req_do       <= next_bs_req_do;
            bs_write_enable <= next_bs_write_enable;
            bs_wdata <= next_bs_wdata;

            core_rdata <= next_core_rdata;

            cache_we <= next_cache_we;

            if (NS == WaySelectDelay)
                delay_ctr <= delay_ctr - 1;
            else
                delay_ctr <= 2'b11;

            if (word_ctr_do_reset)
                word_ctr <= 0;
            else
                if (word_ctr_do_increase)
                    word_ctr <= word_ctr + 1;
                else
                    word_ctr <= word_ctr;
        end
    end
    
    always @ (
        CS,
        current_set, current_way,
        core_addr_i, core_wdata_i, core_we_i, core_be_i, core_req_i,
        mem_rvalid_i, mem_gnt_i, mem_rdata_i,
        proc_write_enable, proc_data, proc_addr, proc_tag, proc_be,
        bs_wdata, bs_write_enable, bs_addr, bs_req_do,
        cache_valid_o, cache_tag_o, cache_line_o,
        cache_valid_i, cache_tag_i, cache_line_i, cache_ww_enable_i,
        block_det_outs, block_det_valid,
        replacement_way, replacement_ready,
        word_ctr, delay_ctr
     ) begin
        NS         = CS;
        
        next_block_det_outs  = block_det_outs;
        next_block_det_valid = block_det_valid;

        next_set           = current_set;
        next_way         = current_way;

        next_proc_data         = proc_data;
        next_proc_addr         = proc_addr;
        next_proc_write_enable = proc_write_enable;
        next_proc_be           = proc_be;

        next_bs_req_do       = 1'b0;
        next_bs_write_enable = 1'b0;
        next_bs_wdata        = bs_wdata;
        next_bs_addr         = bs_addr;

        replacement_read     =  1'b0;
        replacement_written  =  1'b0;
        replacement_taken    =  1'b0;

        next_cache_we        =  1'b0;

        next_cache_valid_i      =  cache_valid_i;
        next_cache_tag_i        =  cache_tag_i;
        next_cache_line_i       =  cache_line_i;
        next_cache_ww_enable_i  =  'b0;

        next_core_rdata    = core_rdata;

        word_ctr_do_reset    = 1'b0;
        word_ctr_do_increase = 1'b0;
        
        case (CS)
            NoRequest: begin
                next_set       = 6'b0;
                next_way       =  'b0;

                next_core_rdata        = 32'b0;

                next_proc_data         = 32'b0;
                next_proc_write_enable = 1'b0;
                next_proc_addr         = 32'b0;
                next_proc_be           = 4'b0;

                if (core_req_i) begin
                    next_proc_data = core_wdata_i;
                    next_proc_write_enable = core_we_i;
                    next_proc_be = core_be_i;
                    next_proc_addr = core_addr_i;

                    next_set   = core_addr_i[SET_IDX_END:SET_IDX_START];

                    NS = FindSet;
                end
            end
            FindSet: begin
                // We need to give some time for the cache to read the tag
                NS = FindBlock;
            end
            FindBlock: begin
				// FindBlock has 3 steps. If at any of these steps it finds
				// a suitable block it will move on.
				// 1. See if the `tag` is already in the cache
				// 2. See if there is an empty block
				// 3. Find the next RP determined block
				next_block_det_valid[0] = 1'b0;
				
                for (j = 0; j < WAY_COUNT; j = j + 1) begin
                    if (
                        cache_valid_o[j] == CacheLineValid &&
                        cache_tag_o[TAG_IDX_SIZE*j +: TAG_IDX_SIZE] == proc_tag
                    ) begin
                        next_block_det_outs[$clog2(WAY_COUNT)-1:0] = j;
                        next_block_det_valid[0] = 1'b1;
                        
                        break;
                    end
                end
                
                next_block_det_valid[1] = 1'b0;
                
                for (j = 0; j < WAY_COUNT; j = j + 1) begin
                    if (
                        cache_valid_o[j] == CacheLineInvalid
                    ) begin
                        next_block_det_outs[$clog2(WAY_COUNT)*2-1:$clog2(WAY_COUNT)] = j;
                        next_block_det_valid[1] = 1'b1;

                        break;
                    end
                end

                NS = SelectBlock;
            end
            SelectBlock: begin
                case (block_det_valid)
                    2'b01, 2'b11: begin
                        // Cache Hit
                        next_way = block_det_outs[0 +: $clog2(WAY_COUNT)];

                        // Cache hit
                        if (~proc_write_enable)
                            NS = WaySelectDelay;
                        else
                            NS = WriteCache;
                    end
                    2'b10: begin
                        // Cache Miss - With Empty Block
                        next_way = block_det_outs[$clog2(WAY_COUNT) +: $clog2(WAY_COUNT)];

                        NS = ReadMemReq;
                    end
                    2'b00: begin
                        if (replacement_ready) begin
                            // Cache Miss - Without Empty Block
                            next_way = replacement_way;
                            replacement_taken = 1'b1;

                            NS = ReadMemReq;
                        end
                        else
                            NS = SelectBlock;
                    end
                endcase
            end
            WaySelectDelay: begin
                if (delay_ctr == 0) begin
                    next_core_rdata = cache_line_o[32*proc_way_word +: 32];
                    NS = Done;
                end
            end
			ReadMemReq: begin
				next_bs_req_do       = 1'b1;
				next_bs_write_enable = 1'b0;
				next_bs_wdata        = 32'b0;

                next_bs_addr         = {
                    proc_addr[31:$clog2(WAY_WORD_COUNT)+2],
                    word_ctr,
                    2'b00
                };

                if (mem_gnt_i) begin
                    NS = ReadMemWait;
                end
			end
			ReadMemWait: begin
                if (mem_rvalid_i) begin
                    next_cache_line_i[word_ctr*32 +: 32] = mem_rdata_i;

                    if (~proc_write_enable && word_ctr == proc_way_word)
                        next_core_rdata = mem_rdata_i;

					word_ctr_do_increase = 1'b1;

                    if ( word_ctr == WAY_WORD_COUNT-1 ) begin
                        word_ctr_do_reset = 1'b1;

                        next_cache_valid_i = 1'b1;
                        next_cache_tag_i   = proc_tag;
                        next_cache_ww_enable_i    = { WAY_WORD_COUNT {1'b1} };
                        
                        next_cache_we      = 1'b1;

                        if (~proc_write_enable)
                            NS = Done;
                        else
                            NS = WriteCache;
                    end
                    else begin
                        NS = ReadMemReq;
                    end
                end
			end
            WriteCache: begin
                next_cache_we      = 1'b1;

                next_cache_valid_i = 1'b1;
                next_cache_tag_i = proc_tag;
                next_cache_line_i[proc_way_word*32 +: 32] = proc_data;
                next_cache_ww_enable_i[proc_way_word] = 1'b1;

                NS = WriteMemReq;
            end
			WriteMemReq: begin
				next_bs_req_do       = 1'b1;
				next_bs_write_enable = 1'b1;
                next_bs_addr         = proc_addr;
				next_bs_wdata        = cache_line_o[32*proc_way_word +: 32];

                if (mem_rvalid_i) begin
                    NS = WriteMemWait;
                end
			end
			WriteMemWait: begin
                if (mem_rvalid_i) begin
                    NS = Done;
                end
			end
            Done: begin
                if (proc_write_enable)
                    replacement_written = 1'b1;
                else
                    replacement_read    = 1'b1;

                NS = NoRequest;
            end
        endcase
    end
endmodule
`default_nettype wire