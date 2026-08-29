`timescale 1ns / 1ps

module spi_master (
    input  logic       clk,
    input  logic       rst,
    input  logic       cpol,     // idle 0:Low, 1:high
    input  logic       cpha,     // first sampling, 0:first edge, 1:second edge
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
    
    logic half_tick;
    logic [6:0] div_cnt;

    logic step;
    logic [2:0] bit_cnt;

    logic [7:0] tx_shift_reg, rx_shift_reg;


    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_e;

    state_e state;

    always_ff @(posedge clk, posedge rst) begin
        if(rst) begin
            div_cnt   <= 0;
            half_tick <= 1'b0;
        end
        else begin
            if(state == DATA) begin
                if(div_cnt == 100) begin
                    div_cnt   <= 0;
                    half_tick <= 1'b1;
                end
                else begin
                    div_cnt   <= div_cnt + 1'b1;
                    half_tick <= 1'b0;
                end
            end
            else begin
                div_cnt   <= 0;
                half_tick <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk, posedge rst) begin
        if(rst) begin
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            busy         <= 1'b0;
            done         <= 1'b0;
            step         <= 1'b0;
            bit_cnt      <= 0;
            cs_n         <= 1'b1;
            mosi         <= 1'b1;
            sclk         <= cpol;
            state        <= IDLE;
        end
        else begin
            case (state)
                IDLE : begin
                    cs_n <= 1'b1;
                    mosi <= 1'b1;
                    sclk <= cpol;
                    done <= 1'b0;
                    if(start) begin
                        tx_shift_reg <= tx_data;
                        busy         <= 1'b1;
                        step         <= 1'b0;
                        bit_cnt      <= 0;
                        cs_n         <= 1'b0;
                        state        <= START;
                    end
                end
                START : begin
                    mosi <= tx_shift_reg[7];
                    tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                    state <= DATA;
                end
                DATA : begin
                    if(half_tick) begin
                        sclk <= ~sclk; // SCLK 토글

                        if(!step) begin
                            // 1st Edge (상승 에지): MISO 데이터 샘플링 (Read)
                            step <= 1'b1;
                            rx_shift_reg <= {rx_shift_reg[6:0], miso};
                        end else begin
                            // 2nd Edge (하강 에지): 다음 비트 Shift (Write)
                            step <= 1'b0;
                            if(bit_cnt == 7) begin
                                state <= STOP; // 8비트(16 번의 half_tick) 완료 후 STOP으로 이동
                            end else begin
                                bit_cnt      <= bit_cnt + 1'b1;
                                mosi         <= tx_shift_reg[7];
                                tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                            end
                        end
                    end
                end
                STOP : begin
                    sclk    <= cpol;
                    cs_n    <= 1'b1;
                    done    <= 1'b1;
                    busy    <= 1'b0;
                    mosi    <= 1'b1;
                    rx_data <= rx_shift_reg;
                    state   <= IDLE;
                end
                default:  state <= IDLE;
            endcase
        end
    end
endmodule