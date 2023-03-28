module cache_mem_wrap_tb();
  reg [5:0] set;
  reg [0:0] way;
  
  reg enable;
  reg write_enable;
  reg val_write_enable;
  
  reg        line_valid_i;
  reg [21:0] line_tag_i;
  reg [127:0] line_i;
  reg [15:0]  line_be_i;

  wire [1:0]   line_valid_o;
  wire [21:0]  line_tag_o;
  wire [127:0] line_o;

  reg clk;
  reg rst_n;

  cache_mem_wrap cache_mem (
    .clk(clk),
    .reset(~rst_n),

	.set(set),
	.way(way),

	.enable(enable),
	.write_enable(write_enable),
	.val_write_enable(val_write_enable),

	.line_valid_i(line_valid_i),
	.line_tag_i(line_tag_i),
	.line_i(line_i),
	.line_be_i(line_be_i),

	.line_valid_o(line_valid_o),
	.line_tag_o(line_tag_o),
	.line_o(line_o)
  );

  always #5 clk <= ~clk;

  initial begin
      clk <= 1'b0;

	  set <= 0;
	  way <= 0;

	  enable <= 0;
	  write_enable <= 0;
	  val_write_enable <= 0;

	  line_valid_i <= 0;
	  line_tag_i <= 0;
	  line_i <= 0;
	  line_be_i <= 16'hFFFF;

      rst_n <= 0;

      #2
      #10 
      rst_n <= 1;

      #10
	  enable <= 1;
      line_valid_i <= 1;
      line_tag_i <= 22'h33_9977;
      line_i <= 128'h1234_5678_ABCD_EF12_1337_4242_4343_6565;
      write_enable <= 1;

      #10
      write_enable <= 0;
      line_valid_i <= 0;
      line_tag_i <= 0;
      line_i <= 0;
      set <= 1;

      #10
      set <= 0;

      #10
      enable <= 0;
  end
endmodule