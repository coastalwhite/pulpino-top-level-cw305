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

  assign tdo_o <= 0'b1;

  reg [63:0] internal_memory;

  reg [2:0] read_counter;
  reg       read_known_io_turn;
  wire      read_io_turn;
  assign    read_io_turn = gpio_in[8];

  wire      do_read;
  assign    do_read      = gpio_in[9];

  reg [2:0] write_counter;
  reg       write_known_io_turn;
  wire      write_io_turn;
  assign    write_io_turn = gpio_in[10];

  wire      write_pc_turn;
  assign    write_pc_turn = gpio_in[13];
  reg       write_known_pc_turn;

  initial begin
      gpio_out            <= 32'b0;
      internal_memory     <= 64'h1234_abcd_1337_4242;
      read_counter        <= 3'b0;
      read_known_io_turn  <= 1'b0;
      write_counter       <= 3'b0;
      write_known_io_turn <= 1'b0;
      write_known_pc_turn <= 1'b0;
  end

  always @ (posedge clk) begin
      if (!rst_n) begin
          gpio_out            <= 32'b0;
          internal_memory     <= 64'h1234_abcd_1337_4242;
          read_counter        <= 3'b0;
          read_known_io_turn  <= 1'b0;
          write_counter       <= 3'b0;
          write_known_io_turn <= 1'b0;
          write_known_pc_turn <= 1'b0;
      end 
      else if (do_read || read_counter[2] == 1'b1) begin
              if (do_read) gpio_out[9] <= 1'b0;

              read_counter[2] <= 1'b1;

              if (read_io_turn != read_known_io_turn) begin
                  gpio_out[7:0] <= internal_memory[7:0];
                  internal_memory <= internal_memory >> 8;
                  gpio_out[8] <= !gpio_out[8];

                  if ( read_counter[1:0] == 2'b11 ) begin
                      read_counter <= 3'b000;
                      gpio_out[9] <= 1'b1;
                  end
                  else begin
                      read_counter <= read_counter + 1;
                  end
              end

              read_known_io_turn <= read_io_turn;
          end
      else if (write_counter[2] == 1'b1) begin
          if (write_counter[1:0] == 2'b00) gpio_out[11] <= 1'b0;

          if (write_io_turn != write_known_io_turn) begin
              internal_memory <= { gpio_in[7:0], internal_memory[63:8] };
              gpio_out[10] <= !gpio_out[10];

              if ( write_counter[1:0] == 2'b11 ) begin
                  write_counter <= 3'b000;
                  gpio_out[11] <= 1'b1;
              end
              else begin
                  write_counter <= write_counter + 1;
              end
          end

          read_known_io_turn <= read_io_turn;
      end
      else begin
          if ( write_known_pc_turn != write_pc_turn ) begin
              write_counter <= 3'b100;
          end

          write_known_pc_turn <= write_pc_turn;
      end
  end
endmodule

`default_nettype wire
