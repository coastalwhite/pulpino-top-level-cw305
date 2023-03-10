`timescale 1ns / 1ps

module dummy_pulpino_tb();
    reg reset_i;

    reg [31:0] read_data;
    wire [7:0] gpio_data_in;
    wire [1:0] data_in_io_turn;
    reg [1:0] data_in_pulpino_turn;
    
    wire data_in_done;
    
    reg do_read;
    
    wire [31:0] write_data;
    reg [7:0] gpio_data_out;
    wire data_out_io_turn;
    reg [1:0] data_out_pulpino_turn;
    
    wire data_out_done;
    
    reg clk;
    reg write_turn;

    wire [31:0] gpio_dir;
    wire [31:0] gpio_in;

    assign gpio_in[7:0] = gpio_data_in;
    assign gpio_in[9:8] = data_in_io_turn;
    assign gpio_in[11:10] = data_out_io_turn;
    assign gpio_in[12] = data_in_done;
    assign gpio_in[13] = data_out_done;
    assign gpio_in[14] = write_turn;
    assign gpio_in[31:15] = 17'b0;

    assign gpio_out[7:0] = gpio_data_out;
    assign gpio_out[9:8] = data_in_pulpino_turn;
    assign gpio_out[11:10] = data_out_pulpino_turn;
    assign gpio_out[12] = read_turn;
    assign gpio_in[31:13] = 19'b0;

    assign gpio_dir = 32'b0;

   gpio_pulpino_comm inst (
        .reset_i                       (reset_i),

        // USB -> Pulpino
        .read_data                     (read_data),
        .gpio_data_in                  (gpio_data_in),
        .data_in_io_turn               (data_in_io_turn),
        .data_in_pulpino_turn          (data_in_pulpino_turn),

        .data_in_done                  (data_in_done),

        .do_read                       (do_read),

        // Pulpino -> USB
        .write_data                    (write_data),
        .gpio_data_out                 (gpio_data_out),
        .data_out_io_turn              (data_out_io_turn),
        .data_out_pulpino_turn         (data_out_pulpino_turn),
    
        .data_out_done                 (data_out_done),
    
        .clk                           (clk)
    );

    dummy_pulpino pulp (
        .clk                           (clk),
        .rst_n                         (!reset_i),

        //input wire fetch_enable_i,

        .spi_clk_i                     (1'b0),
        .spi_cs_i                      (1'b0),
        .spi_mode_o                    (),
        .spi_sdo0_o                    (),
        .spi_sdo1_o                    (),
        .spi_sdo2_o                    (),
        .spi_sdo3_o                    (),
        .spi_sdi0_i                    (1'b0),
        .spi_sdi1_i                    (1'b0),
        .spi_sdi2_i                    (1'b0),
        .spi_sdi3_i                    (1'b0),

        .spi_master_clk_o              (),
        .spi_master_csn0_o             (),
        .spi_master_csn1_o             (),
        .spi_master_sdo0_o             (),
        .spi_master_sdi0_i             (1'b0),

        // Interface UART
        .uart_tx                       (),
        .uart_rx                       (1'b0),
        .uart_rts                      (),
        .uart_dtr                      (),
        .uart_cts                      (1'b0),
        .uart_dsr                      (1'b0),

        .scl_i                         (1'b0),
        .scl_o                         (),
        .scl_oen_o                     (),
        .sda_i                         (1'b0),
        .sda_o                         (),
        .sda_oen_o                     (),

        // GPIO PORT
        .gpio_dir                      (gpio_dir),
        .gpio_in                       (gpio_in),
        .gpio_out                      (gpio_out),

        // Debug PORT
        .tck_i                         (1'b0),
        .trstn_i                       (1'b0),
        .tms_i                         (1'b0),
        .tdi_i                         (1'b0),
        .tdo_o                         ()
    );
    
    always #5 clk = ~clk;
    
    initial begin
        #0
        clk        <= 1'b0;
        reset_i    <= 1'b1;
        data_in_pulpino_turn <= 2'b00;
        data_out_pulpino_turn <= 2'b00;
        write_turn <= 1'b0;

        #10
        reset_i   <= 1'b0;
        
        // READ
        write_turn <= 1'b0;
    end
endmodule