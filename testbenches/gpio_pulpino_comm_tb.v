`timescale 1ns / 1ps

module usb_pulpino_channel_tb();
    reg reset_i;
    
    reg [31:0] usb_to_pulpino_reg;
    wire [7:0] usb_to_pulpino_data;
    reg usb_to_pulpino_read_reg;
    
    wire [31:0] pulpino_to_usb_reg;
    reg [7:0] pulpino_to_usb_data;

    wire usb_read_flicker;
    wire usb_write_flicker;

    reg pulpino_read_flicker;
    reg pulpino_write_flicker;
    
    reg clk;
    
    usb_pulpino_channel inst (
        .reset_i                       (reset_i),

        // USB -> Pulpino
        .usb_to_pulpino_reg            (usb_to_pulpino_reg),
        .usb_to_pulpino_data           (usb_to_pulpino_data),
        .usb_to_pulpino_read_reg       (usb_to_pulpino_read_reg),

        // Pulpino -> USB
        .pulpino_to_usb_reg            (pulpino_to_usb_reg),
        .pulpino_to_usb_data           (pulpino_to_usb_data),
    
        .usb_read_flicker              (usb_read_flicker),
        .usb_write_flicker             (usb_write_flicker),

        .pulpino_read_flicker          (pulpino_read_flicker),
        .pulpino_write_flicker         (pulpino_write_flicker),
    
        .clk                           (clk)
    );
    
    always #5 clk = ~clk;
    
    initial begin
        #0
        clk        <= 1'b0;
        reset_i    <= 1'b1;

        usb_to_pulpino_reg <= 32'b00;
        usb_to_pulpino_read_reg <= 1'b0;
    
        pulpino_to_usb_data <= 8'b0;

        pulpino_read_flicker <= 1'b0;
        pulpino_write_flicker <= 1'b0;
    
        #10
        reset_i   <= 1'b0;
        
        // READ
        usb_to_pulpino_read_reg <= 1'b1;
        usb_to_pulpino_reg <= 32'h1234_ABCD;

        #10
        usb_to_pulpino_read_reg <= 1'b0;
        
        #10
        pulpino_read_flicker <= ~pulpino_read_flicker;
        
        #20
        pulpino_read_flicker <= ~pulpino_read_flicker;

        #25
        pulpino_read_flicker <= ~pulpino_read_flicker;

        #10
        pulpino_read_flicker <= ~pulpino_read_flicker;
        
        #15
        // READ
        usb_to_pulpino_read_reg <= 1'b1;
        usb_to_pulpino_reg <= 32'hFFCC_DD_AA;

        #10
        usb_to_pulpino_read_reg <= 1'b0;
        
        #10
        pulpino_read_flicker <= ~pulpino_read_flicker;
        
        #20
        pulpino_read_flicker <= ~pulpino_read_flicker;

        #25
        pulpino_read_flicker <= ~pulpino_read_flicker;

        #40
        pulpino_read_flicker <= ~pulpino_read_flicker;
        
        // WRITE
        #20
        pulpino_to_usb_data <= 8'hcd;
        pulpino_write_flicker <= ~pulpino_write_flicker;

        #20
        pulpino_to_usb_data <= 8'hab;
        pulpino_write_flicker <= ~pulpino_write_flicker;

        #20
        pulpino_to_usb_data <= 8'h34;
        pulpino_write_flicker <= ~pulpino_write_flicker;

        #20
        pulpino_to_usb_data <= 8'h12;
        pulpino_write_flicker <= ~pulpino_write_flicker;

        #20
        pulpino_to_usb_data <= 8'h00;
    end
endmodule