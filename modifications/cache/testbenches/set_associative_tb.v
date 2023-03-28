module set_associative_tb();
  wire testmode_i = 1'b0;

  wire        data_mem_en;
  wire [31:0] data_mem_addr;
  wire [31:0] data_mem_wdata;
  wire [31:0] data_mem_rdata;
  wire        data_mem_we;
  wire [3:0]  data_mem_be;

  reg         core_data_req;
  wire        core_data_gnt;
  wire        core_data_rvalid;
  reg [31:0]  core_data_addr;
  reg         core_data_we;
  reg [3:0]   core_data_be;
  wire [31:0] core_data_rdata;
  reg [31:0]  core_data_wdata;

  wire        core_mem_req;
  wire        core_mem_gnt;
  wire        core_mem_rvalid;
  wire [31:0] core_mem_addr;
  wire        core_mem_we;
  wire [3:0]  core_mem_be;
  wire [31:0] core_mem_rdata;
  wire [31:0] core_mem_wdata;

  reg clk;
  reg rst_n;

  sp_ram_wrap
  #(
    .RAM_SIZE   ( 32),
    .DATA_WIDTH ( 32)
  )
  data_mem
  (
    .clk          ( clk            ),
    .rstn_i       ( rst_n          ),
    .en_i         ( data_mem_en    ),
    .addr_i       ( data_mem_addr  ),
    .wdata_i      ( data_mem_wdata ),
    .rdata_o      ( data_mem_rdata ),
    .we_i         ( data_mem_we    ),
    .be_i         ( data_mem_be    ),
    .bypass_en_i  ( testmode_i     )
  );

  ram_mux
  #(
    .ADDR_WIDTH ( 32 ),
    .IN0_WIDTH  ( 32 ),
    .IN1_WIDTH  ( 32              ),
    .OUT_WIDTH  ( 32 )
  )
  data_ram_mux_i
  (
    .clk            ( clk              ),
    .rst_n          ( rst_n            ),

    .port0_req_i    ( 1'b0 ),
    .port0_gnt_o    ( ),
    .port0_rvalid_o ( ),
    .port0_addr_i   ( 32'h0 ),
    .port0_we_i     ( 1'b0 ),
    .port0_be_i     ( 4'b0 ),
    .port0_rdata_o  ( ),
    .port0_wdata_i  ( 32'h0 ),

    .port1_req_i    ( core_mem_req    ),
    .port1_gnt_o    ( core_mem_gnt    ),
    .port1_rvalid_o ( core_mem_rvalid ),
    .port1_addr_i   ( core_mem_addr   ),
    .port1_we_i     ( core_mem_we     ),
    .port1_be_i     ( core_mem_be     ),
    .port1_rdata_o  ( core_mem_rdata  ),
    .port1_wdata_i  ( core_mem_wdata  ),

    .ram_en_o       ( data_mem_en      ),
    .ram_addr_o     ( data_mem_addr    ),
    .ram_we_o       ( data_mem_we      ),
    .ram_be_o       ( data_mem_be      ),
    .ram_rdata_i    ( data_mem_rdata   ),
    .ram_wdata_o    ( data_mem_wdata   )
  );

  set_associative_cache data_mem_cache (
    .clk(clk),
    .reset(~rst_n),

    // Core Side
    .core_addr_i(core_data_addr),
    .core_wdata_i(core_data_wdata),
    .core_we_i(core_data_we),
    .core_req_i(core_data_req),
    .core_be_i(core_data_be), // Write Byte Mask

    .core_rdata_o(core_data_rdata),
    .core_gnt_o(core_data_gnt), // Access Granted
    .core_rvalid_o(core_data_rvalid), // Request Valid
    .core_error_o(),

    // Memory Side
    .mem_addr_o(core_mem_addr),
    .mem_wdata_o(core_mem_wdata),
    .mem_we_o(core_mem_we),
    .mem_req_o(core_mem_req),
    .mem_be_o(core_mem_be),

    .mem_rdata_i(core_mem_rdata),
    .mem_gnt_i(core_mem_gnt),
    .mem_rvalid_i(core_mem_rvalid),
    .mem_error_i(1'b0)

  );

  always #5 clk <= ~clk;

  initial begin
      clk <= 1'b0;
      core_data_req <= 1'b0;
      core_data_addr <= 32'h0010_0000;
      core_data_we <= 1'b0;
      core_data_be <= 4'b0;
      core_data_wdata <= 32'b0;

      rst_n <= 1'b0;
      #5
      #10 
      rst_n <= 1'b1;

      #10
      core_data_req <= 1'b1;
      core_data_we <= 1'b1;
      core_data_wdata <= 32'h1234_ABCD;
      core_data_be <= 4'b1111;

      #10
      core_data_req <= 1'b0;
      core_data_we <= 1'b0;
      core_data_wdata <= 32'h0000_0000;
      core_data_be <= 4'b0;

      // Cache Hit
      #100
      core_data_addr <= 32'h0010_0000;
      core_data_req <= 1'b1;

      #10
      core_data_req <= 1'b0;

      // Cache Miss
      #30
      core_data_addr <= 32'h0010_0200;
      core_data_req <= 1'b1;

      #10
      core_data_req <= 1'b0;

      // Cache Hit
      #70
      core_data_addr <= 32'h0010_0200;
      core_data_req <= 1'b1;

      #10
      core_data_req <= 1'b0;

      // Cache Hit
      #30
      core_data_addr <= 32'h0010_0000;
      core_data_req <= 1'b1;

      #10
      core_data_req <= 1'b0;

      // Cache Miss
      #30
      core_data_addr <= 32'h0010_0300;
      core_data_req <= 1'b1;

      #10
      core_data_req <= 1'b0;

      // Cache Miss
      #70
      core_data_addr <= 32'h0010_0000;
      core_data_req <= 1'b1;

      #10
      core_data_req <= 1'b0;

      // Cache Miss
      #70
      core_data_addr <= 32'h0010_0300;
      core_data_req <= 1'b1;

      #10
      core_data_req <= 1'b0;
      
      // Cache Miss
      #70
      core_data_addr <= 32'h0010_0000;
      core_data_req <= 1'b1;

      #10
      core_data_req <= 1'b0;

      // Cache Miss
      #70
      core_data_addr <= 32'h0010_0300;
      core_data_req <= 1'b1;

      #10
      core_data_req <= 1'b0;
      
      // Cache Miss
      #70
      core_data_addr <= 32'h0010_0004;
      core_data_req <= 1'b1;

      #10
      core_data_req <= 1'b0;

      // Cache Miss
      #70
      core_data_addr <= 32'h0010_0304;
      core_data_req <= 1'b1;

      #10
      core_data_req <= 1'b0;

  end
endmodule