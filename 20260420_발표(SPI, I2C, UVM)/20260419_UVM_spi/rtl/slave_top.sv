`timescale 1ns / 1ps

module spi_slave_top (
    input logic clk,
    input logic rst,
    input logic sclk,
    input logic cpol,  // idle 0:Low, 1:high
    input logic cpha,  // first sampling, 0:first edge, 1:second edge
    input logic [7:0] tx_data,
    input logic cs_n,
    input logic mosi,
    output logic miso,
    output logic [7:0] rx_data,
    output logic done
);
    logic [7:0] w_rx_data;

    spi_slave U_SPI_SLAVE (
        .clk    (clk),
        .rst    (rst),
        .sclk   (sclk),
        .cpol   (cpol),     // idle 0:Low, 1:high
        .cpha   (cpha),     // first sampling, 0:first edge, 1:second edge
        .tx_data(tx_data),
        .cs_n   (cs_n),
        .mosi   (mosi),
        .miso   (miso),
        .rx_data(w_rx_data),
        .done   (done)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_data <= 0;
        end else begin
            if (done) rx_data <= w_rx_data;
        end
    end
endmodule

`timescale 1ns / 1ps

module spi_slave (
    input  logic       clk,
    input  logic       rst,
    input  logic       sclk,
    input  logic       cpol,     // idle 0:Low, 1:high
    input  logic       cpha,     // first sampling, 0:first edge, 1:second edge
    input  logic [7:0] tx_data,
    input  logic       cs_n,
    input  logic       mosi,
    output logic       miso,
    output logic [7:0] rx_data,
    output logic       done
);
    typedef enum logic {
        IDLE = 1'b0,
        DATA
    } spi_slv_state_e;

    spi_slv_state_e state;

    logic [7:0] tx_shift_reg, rx_shift_reg;
    logic [2:0] bit_cnt;

    logic [1:0] sclk_sync;
    logic sclk_rising, sclk_falling;

    always_ff @(posedge clk) begin
        sclk_sync <= {sclk_sync[0], sclk};
    end

    assign sclk_rising  = (sclk_sync == 2'b01);
    assign sclk_falling = (sclk_sync == 2'b10);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= IDLE;
            miso         <= 1'b1;
            rx_data      <= 0;
            done         <= 1'b0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            bit_cnt      <= 0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    miso <= 1'b1;
                    if (!cs_n) begin
                        state <= DATA;
                        tx_shift_reg <= tx_data;
                        rx_shift_reg <= 8'd0;
                        bit_cnt <= 0;

                        miso <= tx_data[7];
                    end
                end
                DATA: begin
                    if (sclk_rising) begin
                        rx_shift_reg <= {rx_shift_reg[6:0], mosi};
                    end
                    
                    if (sclk_falling) begin
                        if (bit_cnt == 7) begin
                            rx_data <= rx_shift_reg;
                            done    <= 1'b1;
                            state   <= IDLE;
                        end else begin
                
                            bit_cnt      <= bit_cnt + 1;
                            tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                            miso         <= tx_shift_reg[6];
                        end
                    end else if (cs_n) begin
                        // sclk 
                        state <= IDLE;
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
