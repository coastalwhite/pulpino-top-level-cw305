`default_nettype none
`timescale 1ns / 1ps

module usb_pulpino_channel (
    input  wire          reset_i,

    // USB -> Pulpino
    input  wire [31:0]   usb_to_pulpino_reg,
    output wire [7:0]    usb_to_pulpino_data,

    // Pulpino -> USB
    output reg [31:0]    pulpino_to_usb_reg,
    input  wire [7:0]    pulpino_to_usb_data,

	output wire  		 usb_read_flicker,
	output wire 	     usb_write_flicker,

	input wire			 pulpino_read_flicker,
	input wire			 pulpino_write_flicker,

    input  wire          clk
);
    
    reg [31:0] next_pulpino_to_usb_reg;
    
    reg [1:0] write_state;
    reg [1:0] next_write_state;
    reg [1:0] read_state;
    reg [1:0] next_read_state;
    
    assign usb_write_flicker = ~write_state[0];
    assign usb_read_flicker  =  read_state[0];
    
    // A multiplexer over usb_to_pulpino_reg with write_state as its selector
    assign usb_to_pulpino_data = (
        write_state[1] ? (
            write_state[0] ? usb_to_pulpino_reg[31:24] : usb_to_pulpino_reg[23:16]
        ) : (
            write_state[0] ? usb_to_pulpino_reg[15:8] : usb_to_pulpino_reg[7:0]
        )
    );
    
    always @ (posedge clk, posedge reset_i) begin
        if (reset_i) begin
            pulpino_to_usb_reg <= 32'b0;
            
            write_state        <= 2'b00;
            read_state         <= 2'b00;
        end
        else begin
            pulpino_to_usb_reg <= next_pulpino_to_usb_reg;
            
            write_state        <= next_write_state;
            read_state         <= next_read_state;
        end
    end

	// USB -> Pulpino
    always @ (write_state, pulpino_read_flicker) begin
        next_write_state = write_state;

        if (pulpino_read_flicker == ~write_state[0])
            next_write_state = write_state + 1;
	end

	// Pulpino -> USB
    always @ (read_state, pulpino_write_flicker, pulpino_to_usb_data, pulpino_to_usb_reg) begin
        next_pulpino_to_usb_reg = pulpino_to_usb_reg;
        next_read_state = read_state;

        if (pulpino_write_flicker == ~read_state[0]) begin
            // Shift right pulpino_to_usb_reg by 8, shift in new data
            next_pulpino_to_usb_reg = {
                pulpino_to_usb_data,
                pulpino_to_usb_reg[31:8]
            };
            
            next_read_state = read_state + 1;
        end
	end
endmodule

`default_nettype wire
