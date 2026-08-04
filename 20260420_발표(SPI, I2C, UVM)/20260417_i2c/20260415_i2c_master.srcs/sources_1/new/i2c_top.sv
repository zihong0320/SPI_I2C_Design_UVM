`timescale 1ns / 1ps

module master_top (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] tx_data_m,
    input  logic [3:0] btn,      //[0]: Start, [1]: Write, [2]: Read, [3]: Stop
    output logic [7:0] rx_data_m,
    output logic [3:0] fnd_digit,
    output logic [7:0] fnd_data,

    output  logic scl,
    inout  wire sda
);
    logic cmd_start, cmd_write, cmd_read, cmd_stop;
   
    logic rx_done_m;

    btn_debounce U_BTN_DEBOUNCE_START (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn[0]),
        .o_btn(cmd_start)
    );

    btn_debounce U_BTN_DEBOUNCE_WRITE (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn[1]),
        .o_btn(cmd_write)
    );

    btn_debounce U_BTN_DEBOUNCE_READ (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn[2]),
        .o_btn(cmd_read)
    );

    btn_debounce U_BTN_DEBOUNCE_STOP (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn[3]),
        .o_btn(cmd_stop)
    );

    I2C_Master U_I2C_M (
        .clk(clk),
        .rst(rst),
        .cmd_start(cmd_start),
        .cmd_write(cmd_write),
        .cmd_read(cmd_read),
        .cmd_stop(cmd_stop),
        .tx_data(tx_data_m),
        .ack_in(1'b0),     // from slave to master, 0: ack, 1: nack
        .rx_data(rx_data_m),
        .done(rx_done_m),
        .ack_out(),    // from master to slave, 0: ack, 1: nack
        .busy(),
        .scl(scl),
        .sda(sda)
    );

    fnd_controller U_FND_CTRL (
        .clk(clk),
        .reset(rst),
        .tx_data(tx_data_m),
        .rx_data(rx_data_m),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );
endmodule
