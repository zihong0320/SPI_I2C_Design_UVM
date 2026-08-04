module spi_loopback (
    input logic clk,
    input logic rst,

    // SPI Configuration
    input logic       cpol,    // Clock Polarity
    input logic       cpha,    // Clock Phase
    input logic [7:0] clk_div, // Master용 시계 분주 설정

    // Master Side
    input  logic       start,      // Master 전송 시작 버튼
    input  logic [7:0] tx_data_m,  // Master가 보낼 데이터
    output logic [7:0] rx_data_m,  // Master가 Slave로부터 받은 데이터
    output logic       done_m,     // Master 전송 완료 플래그
    output logic       busy_m,     // Master 동작 중 플래그

    // Slave Side
    input  logic [7:0] tx_data_s,  // Slave가 보낼 데이터
    output logic [7:0] rx_data_s,  // Slave가 Master로부터 받은 데이터
    output logic       done_s,     // Slave 수신 완료 플래그

    // SPI Physical Interface (UVM Monitor/Virtual Interface 연결용)
    output logic sclk,
    output logic mosi,
    output logic cs_n,
    output logic miso
);

    spi_master U_SPI_MASTER (
        .clk    (clk),
        .rst    (rst),
        .cpol   (cpol),     // idle 0:Low, 1:high
        .cpha   (cpha),     // first sampling, 0:first edge, 1:second edge
        .clk_div(clk_div),
        .tx_data(tx_data_m),
        .start  (start),
        .rx_data(rx_data_m),
        .done   (done_m),
        .busy   (busy_m),
        .sclk   (sclk),
        .mosi   (mosi),
        .miso   (miso),
        .cs_n   (cs_n)
    );

    spi_slave_top U_SPI_SLAVE (
        .clk    (clk),
        .rst    (rst),
        .sclk   (sclk),
        .cpol   (cpol),
        .cpha   (cpha),
        .tx_data(tx_data_s),
        .cs_n   (cs_n),
        .mosi   (mosi),
        .miso   (miso),
        .rx_data(rx_data_s),
        .done   (done_s)
    );
endmodule
