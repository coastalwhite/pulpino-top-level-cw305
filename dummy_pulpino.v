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
  output reg [31:0]  gpio_out,

  // Debug PORT
  input wire   tck_i,
  input wire   trstn_i,
  input wire   tms_i,
  input wire   tdi_i,
  output wire  tdo_o
  
  );

  assign spi_mode_o <= 2'b00;
  assign spi_sdo0_o <= 1'b0;
  assign spi_sdo1_o <= 1'b0;
  assign spi_sdo2_o <= 1'b0;
  assign spi_sdo3_o <= 1'b0;

  assign spi_master_clk_o  <= 1'b0;
  assign spi_master_csn0_o <= 1'b0;
  assign spi_master_csn1_o <= 1'b0;
  assign spi_master_sdo0_o <= 1'b0;

  // Interface UART
  assign uart_tx  <= 1'b0;
  assign uart_rts <= 1'b0;
  assign uart_dtr <= 1'b0;

  assign scl_o     <= 1'b0;
  assign scl_oen_o <= 1'b0;
  assign sda_o     <= 1'b0;
  assign sda_oen_o <= 1'b0;

  assign tdo_o <= 0'b1;

  initial gpio_out <= 32'b0;
endmodule

`default_nettype wire
