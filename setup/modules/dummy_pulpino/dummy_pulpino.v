`default_nettype none
`timescale 1ns / 1ps

module dummy_pulpino(
  input wire clk,
  input wire rst_n,

  input wire fetch_enable_i,

  input wire         spi_clk_i,
  input  wire        spi_cs_i,
  output wire  [1:0] spi_mode_o,
  output wire        spi_sdo0_o,
  output wire        spi_sdo1_o,
  output wire        spi_sdo2_o,
  output wire        spi_sdo3_o,
  input wire         spi_sdi0_i,
  input wire         spi_sdi1_i,
  input wire         spi_sdi2_i,
  input wire         spi_sdi3_i,

  output wire      spi_master_clk_o,
  output wire      spi_master_csn0_o,
  output wire      spi_master_csn1_o,
  output wire      spi_master_sdo0_o,
  input wire       spi_master_sdi0_i,

  // Interface UART
  output wire uart_tx,
  input wire  uart_rx,
  output wire uart_rts,
  output wire uart_dtr,
  input wire  uart_cts,
  input wire  uart_dsr,

  input wire  scl_i,
  output wire scl_o,
  output wire scl_oen_o,
  input wire  sda_i,
  output wire sda_o,
  output wire sda_oen_o,

  // GPIO PORT
  input  wire [31:0] gpio_dir,
  input  wire [31:0] gpio_in,
  output wire [31:0] gpio_out,

  // Debug PORT
  input wire   tck_i,
  input wire   trstn_i,
  input wire   tms_i,
  input wire   tdi_i,
  output wire  tdo_o
  
  );

  assign spi_mode_o = 2'b00;
  assign spi_sdo0_o = 1'b0;
  assign spi_sdo1_o = 1'b0;
  assign spi_sdo2_o = 1'b0;
  assign spi_sdo3_o = 1'b0;

  assign spi_master_clk_o  = 1'b0;
  assign spi_master_csn0_o = 1'b0;
  assign spi_master_csn1_o = 1'b0;
  assign spi_master_sdo0_o = 1'b0;

  // Interface UART
  assign uart_tx  = 1'b0;
  assign uart_rts = 1'b0;
  assign uart_dtr = 1'b0;

  assign scl_o     = 1'b0;
  assign scl_oen_o = 1'b0;
  assign sda_o     = 1'b0;
  assign sda_oen_o = 1'b0;

  assign tdo_o 	   = 1'b1;

  wire [7:0] ext_data;
  wire		 ext_write_flicker;
  wire 		 ext_read_flicker;

  wire [7:0] pulpino_data;
  wire		 pulpino_write_flicker;
  wire 		 pulpino_read_flicker;
  
  assign ext_write_flicker   = gpio_in[9];
  assign ext_read_flicker    = gpio_in[8];
  assign ext_data = gpio_in[7:0];

  reg [3:0] state, next_state;
  
  reg [7:0] next_range_start;
  reg [7:0] next_range_end;
  reg [7:0] range_start;
  reg [7:0] range_end;
  
  assign gpio_out[31:10] = 22'b0;
  assign gpio_out[9]   = pulpino_write_flicker;
  assign gpio_out[8]   = pulpino_read_flicker;
  assign gpio_out[7:0] = pulpino_data;

  localparam
  	  StartState      = 4'b0000,
	  Read1_0         = 4'b0001,
	  Read1_1         = 4'b0010,
	  Read2_0         = 4'b0011,
	  Read2_1         = 4'b0100,
	  Write0  		  = 4'b0101,
	  Write1  		  = 4'b0110,
  	  WriteCheckEnd   = 4'b0111,
  	  Done			  = 4'b1000;

  assign pulpino_data = range_start;
  assign pulpino_read_flicker = state == Read1_1 || state == Read2_1;
  assign pulpino_write_flicker = state == Write1;
  
  always @ (posedge clk, negedge rst_n) begin
	  if (!rst_n) begin
		  state       <= StartState;
		  range_start <= 8'h00;
		  range_end   <= 8'h00;
	  end
	  else begin
		  state       <= next_state;
		  range_start <= next_range_start;
		  range_end   <= next_range_end;
	  end
  end

  always @ (state, range_start, range_end, ext_data, ext_read_flicker, ext_write_flicker) begin
      next_state       = state;
      next_range_end   = range_end;
      next_range_start = range_start;
      
	  case (state)
		  StartState: begin
			  next_range_end   = 8'b0;
			  next_range_start = 8'b0;
			  
			  next_state       = Read1_0;
		  end
		  Read1_0: begin
              if ( ext_write_flicker) begin
                  next_range_start = ext_data;
                  next_state       = Read1_1;
              end
		 end
		 Read1_1: begin
              if (~ext_write_flicker)
                  next_state       = Read2_0;
		 end
		 Read2_0: begin
              if ( ext_write_flicker) begin
                  next_range_end   = ext_data;
                  next_state       = Read2_1;
              end
		 end
		 Read2_1: begin
              if (~ext_write_flicker)
                  next_state       = WriteCheckEnd;
		 end
		 Write0: begin
             if (~ext_read_flicker)
                 next_state        = Write1;
	     end
	     Write1: begin
             if ( ext_read_flicker) begin
                 next_range_start  = range_start + 1;
                 next_state        = WriteCheckEnd;
             end
	     end
         WriteCheckEnd: begin
		     if (range_start < range_end)
                 next_state        = Write0;
             else
                 next_state        = Done;
         end
	 endcase
  end
endmodule

`default_nettype wire

