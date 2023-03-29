`default_nettype none
`timescale 1ns / 1ps

module cache_mem_wrap #(
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
	    TAG_IDX_SIZE       = TAG_IDX_END - TAG_IDX_START + 1,
	    
		VALIDITY_OFFSET    = 0,
		TAG_OFFSET         = VALIDITY_OFFSET + SET_COUNT * WAY_COUNT,
		CONTENT_OFFSET     = TAG_OFFSET      + SET_COUNT * WAY_COUNT * 32,

        WAY_IDX_SIZE       = $clog2(WAY_COUNT),
        
        TOTAL_NUM_WAYS     = SET_COUNT * WAY_COUNT,
        TOTAL_NUM_WORDS    = TOTAL_NUM_WAYS * WAY_WORD_COUNT,

        VALIDITY_NUM_BITS  = TOTAL_NUM_WAYS,
        VALIDITY_ADDR_SIZE = $clog2(VALIDITY_NUM_BITS),

        TAG_NUM_BYTES      = TOTAL_NUM_WAYS * 4,
        TAG_ADDR_SIZE      = $clog2(TAG_NUM_BYTES),
        
        CONTENT_NUM_BYTES  = TOTAL_NUM_WORDS * 4,
        CONTENT_ADDR_SIZE  = $clog2(CONTENT_NUM_BYTES)
) (
	input wire                          clk,
	input wire                          reset,

	input wire  [SET_IDX_SIZE-1:0]      set,
	input wire  [$clog2(WAY_COUNT)-1:0] way,

	input wire                          enable,
	input wire					        write_enable,
	input wire					        val_write_enable,

	input wire                          line_valid_i,
	input wire  [TAG_IDX_SIZE-1:0]      line_tag_i,
	input wire  [WAY_WORD_COUNT*32-1:0] line_i,
	input wire  [WAY_WORD_COUNT-1:0]  line_ww_enable_i,

	output reg  [WAY_COUNT-1:0]         line_valid_o,
	output reg  [TAG_IDX_SIZE*WAY_COUNT-1:0] line_tag_o,
	output wire [WAY_WORD_COUNT*32-1:0] line_o
);

    wire [TAG_ADDR_SIZE-1:0] tag_ram_addr;
	reg  [WAY_COUNT*32-1:0] tag_ram_rdata;
	reg  [WAY_COUNT*32-1:0] tag_ram_wdata;

    wire [CONTENT_ADDR_SIZE-1:0] content_ram_addr;

    reg [VALIDITY_NUM_BITS-1:0] validities;

    integer i;
    always @ (tag_ram_rdata) begin
        for (i = 0; i < WAY_COUNT; i = i + 1)
            line_tag_o[i*TAG_IDX_SIZE +: TAG_IDX_SIZE] = tag_ram_rdata[i*32 +: TAG_IDX_SIZE];
    end
    always @ (way, line_tag_i) begin
        tag_ram_wdata = 'b0;
        tag_ram_wdata[32*way +: TAG_IDX_SIZE] = line_tag_i;
    end

    wire [31:0] set_addr = { {(32 - SET_IDX_SIZE) {1'b0}}, set };
	wire [31:0] way_addr = { {(32 - $clog2(WAY_COUNT)) {1'b0}}, way };
    wire [31:0] content_offset = (set_addr * WAY_WORD_COUNT + way_addr) * 4;

    always @ (validities, set_addr) begin
        line_valid_o = validities[set_addr*WAY_COUNT +: WAY_COUNT];
    end

    assign tag_ram_addr      = set_addr[TAG_ADDR_SIZE-1:0] * 4;
    assign content_ram_addr  = content_offset[CONTENT_ADDR_SIZE-1:0];

    always @ (posedge clk, posedge reset) begin
        if (reset) begin
            validities <= 'b0;
        end
        else begin
            if (enable && (write_enable || val_write_enable)) begin
                validities[set * WAY_COUNT + way] <= line_valid_i;
            end
        end
    end
    
    genvar j;
    generate
        for (j = 0; j < WAY_COUNT; j = j + 1) begin
            sp_ram_wrap
            #(
              .RAM_SIZE   ( SET_COUNT * 4 ),
              .DATA_WIDTH ( 32 )
            )
            tag_mem
            (
              .clk          ( clk                        ),
              .rstn_i       ( ~reset                     ),
              .en_i         ( enable                     ),
              .addr_i       ( tag_ram_addr               ),
              .wdata_i      ( tag_ram_wdata[32*j +: 32]  ),
              .rdata_o      ( tag_ram_rdata[32*j +: 32]  ),
              .we_i         ( write_enable && (way == j) ),
              .be_i         ( 4'b1111                    ),
              .bypass_en_i  ( 1'b0                       )
            );
        end
    endgenerate
    
    genvar k;
    generate
        for (k = 0; k < WAY_WORD_COUNT; k = k + 1) begin
            sp_ram_wrap
            #(
              .RAM_SIZE   ( SET_COUNT * WAY_COUNT * 4 ),
              .DATA_WIDTH ( 32 )
            )
            content_mem
            (
              .clk          ( clk                                 ),
              .rstn_i       ( ~reset                              ),
              .en_i         ( enable                              ),
              .addr_i       ( content_ram_addr                    ),
              .wdata_i      ( line_i[32*k +: 32]                  ),
              .rdata_o      ( line_o[32*k +: 32]                  ),
              .we_i         ( write_enable && line_ww_enable_i[j] ),
              .be_i         ( 4'b1111                             ),
              .bypass_en_i  ( 1'b0                                )
            );
        end
    endgenerate
endmodule

`default_nettype wire