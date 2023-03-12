`default_nettype none
`timescale 1ns / 1ps

module usb_pulpino_channel (
    input  wire          reset_i,

    // USB -> Pulpino
    input  wire [31:0]   usb_to_pulpino_reg,
    output wire [7:0]    usb_to_pulpino_data,
	input wire			 usb_to_pulpino_read_reg, // Read the Ext register?

    // Pulpino -> USB
    output reg [31:0]    pulpino_to_usb_reg,
    input  wire [7:0]    pulpino_to_usb_data,

	output reg  		 usb_read_flicker,
	output reg 			 usb_write_flicker,

	input wire			 pulpino_read_flicker,
	input wire			 pulpino_write_flicker,

    input  wire          clk
);
    reg [31:0]           int_usb_to_pulpino_reg;

    reg                  known_pulpino_read_flicker;
    reg                  known_pulpino_write_flicker;

	reg					 usb_to_pulpino_has_read;

	reg [1:0]			 usb_to_pulpino_byte_counter;

    assign usb_to_pulpino_data  = int_usb_to_pulpino_reg[7:0];

    initial begin
        int_usb_to_pulpino_reg      <= 32'b0;
        pulpino_to_usb_reg          <= 32'b0;

		usb_read_flicker            <= 1'b0;
		usb_write_flicker           <= 1'b0;

		known_pulpino_read_flicker  <= 1'b0;
		known_pulpino_write_flicker <= 1'b0;

		usb_to_pulpino_has_read     <= 1'b0;
	    usb_to_pulpino_byte_counter <= 2'b0;
    end

	// USB -> Pulpino
    always @ (posedge clk) begin
        if (reset_i) begin
			int_usb_to_pulpino_reg      <= 32'b0;

			usb_write_flicker           <= 1'b0;
			known_pulpino_read_flicker  <= 1'b0;

			usb_to_pulpino_has_read     <= 1'b0;
			usb_to_pulpino_byte_counter <= 2'b0;
        end
        else begin
			// Read USB register. Start the Write to Pulpino
			if (usb_to_pulpino_read_reg == 1'b1) begin
				if (usb_to_pulpino_has_read == 1'b0) begin
					usb_to_pulpino_has_read <= 1'b1;
					int_usb_to_pulpino_reg <= usb_to_pulpino_reg;
					usb_write_flicker <= ~usb_write_flicker;
				end
            end
            else begin
				usb_to_pulpino_has_read <= 1'b0;

				// Byte by byte write to pulpino
				if (pulpino_read_flicker != known_pulpino_read_flicker) begin
					int_usb_to_pulpino_reg <= int_usb_to_pulpino_reg >> 8;
					usb_to_pulpino_byte_counter <= usb_to_pulpino_byte_counter + 1;

					// Don't flicker if we are on the last byte
					if (usb_to_pulpino_byte_counter != 2'b11) begin
						usb_write_flicker <= ~usb_write_flicker;
					end
                    known_pulpino_read_flicker <= pulpino_read_flicker;
				end
			end
		end
	end

	// Pulpino -> USB
    always @ (posedge clk) begin
        if (reset_i) begin
			pulpino_to_usb_reg          <= 32'b0;
			usb_read_flicker            <= 1'b0;
			known_pulpino_write_flicker <= 1'b0;
        end
        else begin
			if (pulpino_write_flicker != known_pulpino_write_flicker) begin
				pulpino_to_usb_reg <= { pulpino_to_usb_data, pulpino_to_usb_reg[31:8] };
				usb_read_flicker <= !usb_read_flicker;
                known_pulpino_write_flicker <= pulpino_write_flicker;
			end
		end
	end
endmodule

`default_nettype wire
