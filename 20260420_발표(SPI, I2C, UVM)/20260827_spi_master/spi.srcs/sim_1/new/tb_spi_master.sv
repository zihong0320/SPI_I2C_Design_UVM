`timescale 1ns / 1ps
module tb_spi_master();

    logic       clk;
    logic       rst;
    logic       cpol;
    logic       cpha;
    logic [7:0] tx_data;
    logic       start;
    logic [7:0] rx_data;
    logic       done;
    logic       busy;
    logic       sclk;
    logic       mosi;
    logic       miso;
    logic       cs_n;


    spi_master dut(
        .clk    (clk),
        .rst    (rst),
        .cpol   (cpol),     // idle 0:Low, 1:high
        .cpha   (cpha),     // first sampling, 0:first edge, 1:second edge
        .tx_data(tx_data),
        .start  (start),
        .rx_data(rx_data),
        .done   (done),
        .busy   (busy),
        .sclk   (sclk),
        .mosi   (mosi),
        .miso   (miso),
        .cs_n   (cs_n)
    );

    always #5 clk = ~clk;

    // -------------------------------------------------------------
    // Virtual Slave Model (Mode 0: SCLK 하강 에지마다 MISO 데이터 교체)
    // -------------------------------------------------------------
    logic [7:0] slave_tx_data;
    logic [2:0] slave_bit_cnt;

    // CS_N이 LOW일 때 첫 비트(MSB) 즉시 출력, SCLK 하강 에지마다 다음 비트 전송
    assign miso = (!cs_n) ? slave_tx_data[slave_bit_cnt] : 1'b0;

    always_ff @(negedge sclk or posedge cs_n) begin
        if (cs_n) begin
            slave_bit_cnt <= 3'd7;
        end else begin
            if (slave_bit_cnt > 0)
                slave_bit_cnt <= slave_bit_cnt - 1'b1;
        end
    end

    initial begin
        clk = 0;
        rst = 1;
        cpol = 0;
        cpha = 0;
        tx_data = 0;
        slave_tx_data = 0;
        start = 0;

        #20;
        rst = 0;

        #20;

        // TEST
        tx_data       = 8'hA5;
        slave_tx_data = 8'h3C;

        start = 1;
        #10;
        start = 0;

        @(posedge done);
        #100;

        // TEST
        tx_data       = 8'h11;
        slave_tx_data = 8'h99;

        start = 1;
        #10;
        start = 0;

        @(posedge done);
        #1000;

        $finish;
    end 
endmodule
