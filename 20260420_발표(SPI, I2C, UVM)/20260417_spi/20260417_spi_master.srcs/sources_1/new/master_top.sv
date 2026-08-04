`timescale 1ns / 1ps

module master_top (
    //spi
    input logic clk,
    input logic rst,
    input logic start, // button
    
    output logic       sclk_m,
    output logic       mosi_m,
    output logic       cs_n_m,
    input  logic       miso_m,
    input  logic [7:0] tx_data_m,  // master
    output logic [7:0] rx_data_m,  // master

    // fnd
    output logic [3:0] fnd_digit,
    output logic [7:0] fnd_data
);

    logic w_start, busy;
    logic done_m;
    logic [7:0] w_rx_data_m;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_data_m <= 0;
        end else begin
            if (done_m) rx_data_m <= w_rx_data_m;
        end
    end

    btn_debounce U_BTN_DEBOUNCE (
        .clk  (clk),
        .reset(rst),
        .i_btn(start),
        .o_btn(w_start)
    );

    spi_master U_SPI_MASTER (
        .clk    (clk),
        .rst    (rst),
        .cpol   (1'b0),       // idle 0:Low, 1:high
        .cpha   (1'b0),       // first sampling, 0:first edge, 1:second edge
        .clk_div(8'd100),
        .tx_data(tx_data_m),
        .start  (w_start),
        .rx_data(w_rx_data_m),
        .done   (done_m),
        .busy   (busy),
        .sclk   (sclk_m),
        .mosi   (mosi_m),
        .miso   (miso_m),
        .cs_n   (cs_n_m)
    );

    fnd_controller U_FND (
        .clk      (clk),
        .reset    (rst),
        .tx_data  (tx_data_m),  // slave
        .rx_data  (rx_data_m),  // master
        .fnd_digit(fnd_digit),
        .fnd_data (fnd_data)
    );

endmodule

`timescale 1ns / 1ps

module spi_master (
    input  logic       clk,
    input  logic       rst,
    input  logic       cpol,     // idle 0:Low, 1:high
    input  logic       cpha,     // first sampling, 0:first edge, 1:second edge
    input  logic [7:0] clk_div,
    input  logic [7:0] tx_data,
    input  logic       start,
    output logic [7:0] rx_data,
    output logic       done,
    output logic       busy,
    output logic       sclk,
    output logic       mosi,
    input  logic       miso,
    output logic       cs_n
);
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START,
        DATA,
        STOP
    } spi_state_e;

    spi_state_e state;
    logic [7:0] div_cnt;
    logic half_tick;
    logic [7:0] tx_shift_reg, rx_shift_reg;
    logic [2:0] bit_cnt;  // 0-7
    logic step, sclk_r;

    assign sclk = sclk_r;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            div_cnt   <= 0;
            half_tick <= 1'b0;
        end else begin
            if (state == DATA) begin
                if (div_cnt == clk_div) begin
                    div_cnt   <= 0;
                    half_tick <= 1'b1;
                end else begin
                    div_cnt   <= div_cnt + 1;
                    half_tick <= 1'b0;
                end
            end else begin
                div_cnt   <= 0;
                half_tick <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= IDLE;
            mosi         <= 1'b1;
            cs_n         <= 1'b1;
            busy         <= 1'b0;
            done         <= 1'b0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            bit_cnt      <= 0;
            step         <= 1'b0;
            rx_data      <= 0;
            sclk_r       <= cpol;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    mosi   <= 1'b1;
                    cs_n   <= 1'b1;
                    sclk_r <= cpol;
                    if (start) begin
                        tx_shift_reg <= tx_data;
                        bit_cnt      <= 0;
                        step         <= 1'b0;
                        busy         <= 1'b1;
                        cs_n         <= 1'b0;
                        state        <= START;
                    end
                end
                START: begin
                    if (!cpha) begin
                        mosi <= tx_shift_reg[7];
                        tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                    end
                    state <= DATA;
                end
                DATA: begin
                    if (half_tick) begin
                        sclk_r <= ~sclk_r;
                        if (step == 0) begin 
                            step <= 1'b1;
                            if (!cpha) begin
                                rx_shift_reg <= {rx_shift_reg[6:0], miso};
                            end else begin
                                mosi         <= tx_shift_reg[7];
                                tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                            end
                        end else begin 
                            step <= 1'b0;
                            if (!cpha) begin
                                if (bit_cnt < 7) begin
                                    mosi         <= tx_shift_reg[7];
                                    tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                end
                            end else begin
                                rx_shift_reg <= {rx_shift_reg[6:0], miso};
                            end

                            if (bit_cnt == 7) begin
                                state <= STOP;
                                if (!cpha) begin
                                    rx_data <= rx_shift_reg;
                                end else begin
                                    rx_data <= {rx_shift_reg[6:0], miso};
                                end
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end
                end
                STOP: begin
                    sclk_r <= cpol;
                    cs_n   <= 1'b1;
                    done   <= 1'b1;
                    busy   <= 1'b0;
                    mosi   <= 1'b1;
                    state  <= IDLE;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

