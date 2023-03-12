`default_nettype none
`timescale 1ns / 1ps

module dummy_pulpino(
  input wire clk,
  input wire rst_n,

  //input wire fetch_enable_i,

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
  input wire [31:0]  gpio_dir,
  input wire [31:0]  gpio_in,
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

  wire [7:0] usb_to_pulpino_data;
  wire		 ext_write_flicker;
  wire 		 ext_read_flicker;
  wire		 usb_pulpino_write_flicker;
  wire 		 usb_pulpino_read_flicker;

  wire [7:0]  pulpino_to_usb_data;
  wire		  pulpino_ext_write_flicker;
  wire 		  pulpino_ext_read_flicker;
  wire		  pulpino_usb_write_flicker;
  wire 		  pulpino_usb_read_flicker;

  assign ext_write_flicker   = gpio_in[11];
  assign ext_read_flicker    = gpio_in[10];
  assign usb_pulpino_write_flicker   = gpio_in[9];
  assign usb_pulpino_read_flicker    = gpio_in[8];
  assign usb_to_pulpino_data = gpio_in[7:0];

  assign gpio_out[31:12] = 20'b0;
  assign gpio_out[11]  = pulpino_ext_write_flicker;
  assign gpio_out[10]  = pulpino_ext_read_flicker;
  assign gpio_out[9]   = pulpino_usb_write_flicker;
  assign gpio_out[8]   = pulpino_usb_read_flicker;
  assign gpio_out[7:0] = pulpino_to_usb_data;

  reg [2:0] state, next_state;

  localparam
  	  StartState      = 3'b000,
	  Read            = 3'b001,
	  Write  		  = 3'b010,
  	  WriteWaitFinish = 3'b011,
  	  WriteCheckEnd   = 3'b100,
  	  Done			  = 3'b101;

  always @ (posedge clk) begin
	  if (!rst_n) begin
		  state <= StartState;
	  end
	  else begin
		  state <= next_state;
	  end
  end 

  reg [15:0] range_start;
  reg [15:0] range_end;

  wire [31:0] out_word;

  reg write_enable;
  reg [31:0] in_word;

  dummy_pulpino_read U_read (
      .clk                           (clk),
      .rst_n                         (rst_n),

      .in_data                       (usb_to_pulpino_data),
      .did_word_write_flicker        (ext_write_flicker),
      .did_byte_write_flicker        (usb_pulpino_write_flicker),

      .out_word                      (out_word),
      .did_word_read_flicker         (pulpino_ext_read_flicker),
      .did_byte_read_flicker         (pulpino_usb_read_flicker)
  );

  dummy_pulpino_write U_write (
        .clk                           (clk),
        .rst_n                         (rst_n),

        .enable                        (write_enable),

        .out_data                      (pulpino_to_usb_data),
	    .did_word_write_flicker        (pulpino_ext_write_flicker),
	    .did_byte_write_flicker        (pulpino_usb_write_flicker),

	    .in_word                       (in_word),
	    .did_word_read_flicker         (ext_read_flicker),
	    .did_byte_read_flicker         (usb_pulpino_read_flicker)
    );

  always @ (state, pulpino_ext_read_flicker, pulpino_ext_write_flicker) begin
      next_state <= state;

	  case (state)
		  StartState: begin
			  write_enable <= 1'b0;
			  next_state <= Read;
		  end
		  Read: begin 
              if (pulpino_ext_read_flicker == 1'b1) begin
                  range_start <= out_word[31:16];
                  range_end <= out_word[15:0];
                  next_state <= WriteCheckEnd;
              end 
		 end
		 Write: begin
             write_enable <= 1'b1;
             in_word <= { 16'b0, range_start };
             next_state <= WriteWaitFinish;
	     end
         WriteWaitFinish: begin
             if (pulpino_ext_write_flicker == 1'b1) begin
                 write_enable <= 1'b0;
                 in_word <= 32'b0;
                 next_state <= WriteCheckEnd;
                 range_start <= range_start + 1;
             end
         end
         WriteCheckEnd: begin
             if (pulpino_ext_write_flicker == 1'b0) begin
                 if (range_start != range_end)
                     next_state <= Write;
                 else
                     next_state <= Done;
             end
         end
		 Done: next_state <= Done;
	 endcase
  end
endmodule

`default_nettype wire
