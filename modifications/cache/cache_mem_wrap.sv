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

        VALIDITY_NUM_BYTES = TOTAL_NUM_WAYS,
        VALIDITY_ADDR_SIZE = $clog2(VALIDITY_NUM_BYTES),

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
	input wire  [WAY_WORD_COUNT*4-1:0]  line_be_i,

	output reg  [WAY_COUNT-1:0]         line_valid_o,
	output reg  [TAG_IDX_SIZE*WAY_COUNT-1:0] line_tag_o,
	output wire [WAY_WORD_COUNT*32-1:0] line_o
);
    wire [VALIDITY_ADDR_SIZE-1:0] validity_ram_addr;
	wire [WAY_COUNT*8-1:0] validity_ram_rdata;
	reg  [WAY_COUNT*8-1:0] validity_ram_wdata;
    reg  [WAY_COUNT-1:0] validity_ram_be;

    wire [TAG_ADDR_SIZE-1:0] tag_ram_addr;
	reg  [WAY_COUNT*32-1:0] tag_ram_rdata;
	reg  [WAY_COUNT*32-1:0] tag_ram_wdata;
    reg  [4*WAY_COUNT-1:0] tag_ram_be;

    wire [CONTENT_ADDR_SIZE-1:0] content_ram_addr;

    integer i;
    always @ (validity_ram_rdata) begin
        for (i = 0; i < WAY_COUNT; i = i + 1)
            line_valid_o[i] = validity_ram_rdata[i*8];
    end
    always @ (tag_ram_rdata) begin
        for (i = 0; i < WAY_COUNT; i = i + 1)
            line_tag_o[i*TAG_IDX_SIZE +: TAG_IDX_SIZE] = tag_ram_rdata[i*32 +: TAG_IDX_SIZE];
    end
    always @ (way, line_valid_i, line_tag_i) begin
        validity_ram_be      =  'b0;
        validity_ram_be[way] = 1'b1;

        validity_ram_wdata   = 'b0;
        validity_ram_wdata[8*way] = line_valid_i;

        tag_ram_wdata = 'b0;
        tag_ram_wdata[32*way +: TAG_IDX_SIZE] = line_tag_i;

        tag_ram_be = 'b0;
        tag_ram_be[4*way +: 4] = 4'b1111;
    end

    wire [31:0] set_addr = { {(32 - SET_IDX_SIZE) {1'b0}}, set };
	wire [31:0] way_addr = { {(32 - $clog2(WAY_COUNT)) {1'b0}}, way };
    wire [31:0] content_offset = (set_addr * WAY_COUNT + way_addr) * WAY_WORD_COUNT * 4;

    assign validity_ram_addr = set_addr[VALIDITY_ADDR_SIZE-1:0] * WAY_COUNT;
    assign tag_ram_addr      = set_addr[TAG_ADDR_SIZE-1:0] * WAY_COUNT * 4;
    assign content_ram_addr  = content_offset[CONTENT_ADDR_SIZE-1:0];

    sp_ram_wrap
    #(
      .RAM_SIZE   ( VALIDITY_NUM_BYTES ),
      .DATA_WIDTH ( 8 * WAY_COUNT )
    )
    validity_mem
    (
      .clk          ( clk                                      ),
      .rstn_i       ( ~reset                                   ),
      .en_i         ( enable                                   ),
      .addr_i       ( validity_ram_addr                        ),
      .wdata_i      ( validity_ram_wdata                       ),
      .rdata_o      ( validity_ram_rdata                       ),
      .we_i         ( val_write_enable | write_enable          ),
      .be_i         ( validity_ram_be                          ),
      .bypass_en_i  ( 1'b0                                     )
    );
    
    sp_ram_wrap
    #(
      .RAM_SIZE   ( TAG_NUM_BYTES ),
      .DATA_WIDTH ( 32 * WAY_COUNT )
    )
    tag_mem
    (
      .clk          ( clk           ),
      .rstn_i       ( ~reset        ),
      .en_i         ( enable        ),
      .addr_i       ( tag_ram_addr  ),
      .wdata_i      ( tag_ram_wdata ),
      .rdata_o      ( tag_ram_rdata ),
      .we_i         ( write_enable  ),
      .be_i         ( tag_ram_be    ),
      .bypass_en_i  ( 1'b0          )
    );
    
    sp_ram_wrap
    #(
      .RAM_SIZE   ( CONTENT_NUM_BYTES ),
      .DATA_WIDTH ( 32 * WAY_WORD_COUNT )
    )
    content_mem
    (
      .clk          ( clk              ),
      .rstn_i       ( ~reset           ),
      .en_i         ( enable           ),
      .addr_i       ( content_ram_addr ),
      .wdata_i      ( line_i           ),
      .rdata_o      ( line_o           ),
      .we_i         ( write_enable     ),
      .be_i         ( line_be_i        ),
      .bypass_en_i  ( 1'b0             )
    );
endmodule

`default_nettype wire