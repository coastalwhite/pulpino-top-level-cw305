/* 
ChipWhisperer Artix Target - Example of connections between example registers
and rest of system.

Copyright (c) 2020, NewAE Technology Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted without restriction. Note that modules within
the project may have additional restrictions, please carefully inspect
additional licenses.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

The views and conclusions contained in the software and documentation are those
of the authors and should not be interpreted as representing official policies,
either expressed or implied, of NewAE Technology Inc.
*/

`default_nettype none
`timescale 1ns / 1ps
`include "cw305_defines.v"

module cw305_reg_pulpino #(
   parameter pADDR_WIDTH = 21,
   parameter pBYTECNT_SIZE = 7,
   parameter pPT_WIDTH = 128,
   parameter pCT_WIDTH = 128,
   parameter pCRYPT_TYPE = 2,
   parameter pCRYPT_REV = 4,
   parameter pIDENTIFY = 8'h2e
)(

// Interface to cw305_usb_pulpino_fe:
   input  wire                                  usb_clk,
   input  wire                                  crypto_clk,
   input  wire                                  reset_i,
   input  wire [pADDR_WIDTH-pBYTECNT_SIZE-1:0]  reg_address,     // Address of register
   input  wire [pBYTECNT_SIZE-1:0]              reg_bytecnt,  // Current byte count
   output reg  [7:0]                            read_data,       //
   input  wire [7:0]                            write_data,      //
   input  wire                                  reg_read,        // Read flag. One clock cycle AFTER this flag is high
                                                                 // valid data must be present on the read_data bus
   input  wire                                  reg_write,       // Write flag. When high on rising edge valid data is
                                                                 // present on write_data
   input  wire                                  reg_addrvalid,   // Address valid flag

   // from top:
   input  wire                                  exttrigger_in,

   // register inputs:
   input  wire [31:0]                  			I_pulpino_to_usb,
   input  wire [31:0]                  			I_pulpino_to_ext_flags,

   // register outputs:
   output reg  [31:0]                  			O_usb_to_pulpino,
   output reg  [31:0]                  			O_ext_to_pulpino_flags,

   output reg                                   O_usb_to_pulpino_read

);

   reg  [7:0]                   reg_read_data;

   reg [1:0]                    do_read_counter;

   initial O_usb_to_pulpino_read <= 1'b0;
   always @ (posedge crypto_clk) begin
       if ( do_read_counter == 2'b00 )
           O_usb_to_pulpino_read <= 1'b0;
       else
           O_usb_to_pulpino_read <= 1'b1;
   end

   //////////////////////////////////
   // read logic:
   //////////////////////////////////

   always @(*) begin
      if (reg_addrvalid && reg_read) begin
         case (reg_address)
            `REG_EXT_PULPINO_DATA:      reg_read_data = O_usb_to_pulpino[reg_bytecnt*8 +: 8];
            `REG_PULPINO_EXT_DATA:      reg_read_data = I_pulpino_to_usb[reg_bytecnt*8 +: 8];
            `REG_PULPINO_EXT_FLAGS:     reg_read_data = I_pulpino_to_ext_flags[reg_bytecnt*8 +: 8];
            `REG_EXT_PULPINO_FLAGS:     reg_read_data = O_ext_to_pulpino_flags[reg_bytecnt*8 +: 8];
            default:                    reg_read_data = 0;
         endcase
      end
      else
         reg_read_data = 0;
   end

   // Register output read data to ease timing. If you need read data one clock
   // cycle earlier, simply remove this stage:
   always @(posedge usb_clk)
      read_data <= reg_read_data;

   //////////////////////////////////
   // write logic (USB clock domain):
   //////////////////////////////////
   always @(posedge usb_clk) begin
      if (reset_i) begin
		 O_usb_to_pulpino <= 32'b0;
		 O_ext_to_pulpino_flags <= 32'b0;
      end

      else begin
         if (reg_addrvalid && reg_write) begin
            case (reg_address)
			   `REG_EXT_PULPINO_DATA:   O_usb_to_pulpino[reg_bytecnt*8 +: 8] <= write_data;
			   `REG_EXT_PULPINO_FLAGS:  O_ext_to_pulpino_flags[reg_bytecnt*8 +: 8] <= write_data;
            endcase
         end
         if ( (reg_addrvalid && reg_write && (reg_address == `REG_EXT_PULPINO_DATA)) )
             do_read_counter <= 2'b11;
         else begin
             if ( do_read_counter != 2'b00 )
                 do_read_counter <= do_read_counter - 1;
         end
      end
   end

endmodule

`default_nettype wire
