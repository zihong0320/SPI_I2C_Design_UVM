`timescale 1ns / 1ps

module fnd_controller (
    input        clk,
    input        reset,
    input  [7:0] tx_data,
    input  [7:0] rx_data,
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);
    wire [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000, w_mux_4x1_out;
    wire [1:0] w_digit_sel;
    wire w_1khz;

    digit_splitter U_DIGIT_SPL (
        .tx_data   (tx_data),
        .rx_data(rx_data),
        .digit_1   (w_digit_1),    // 0~9 -> 4bit
        .digit_10  (w_digit_10),   // 0~9 -> 4bit
        .digit_100 (w_digit_100),  // 0~9 -> 4bit
        .digit_1000(w_digit_1000)  // 0~9 -> 4bit
    );

    clk_div U_CLK_DIV (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_1khz)
    );

    counter_4 U_COUNTER_4 (
        .clk(w_1khz),
        .reset(reset),
        .digit_sel(w_digit_sel)
    );

    decoder_2x4 U_DECODER_2x4 (
        .digit_sel(w_digit_sel),
        .fnd_digit(fnd_digit)
    );

    mux_4x1 U_Mux_4x1 (
        .sel(w_digit_sel),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000),
        .mux_out(w_mux_4x1_out)
    );

    bcd U_BCD (
        .bcd(w_mux_4x1_out),
        .fnd_data(fnd_data)
    );

endmodule

module clk_div (
    input      clk,
    input      reset,
    output reg o_1khz
);
    //reg [16:0] counter_r;
    reg [$clog2(100_000):0] counter_r;


    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0;
            o_1khz    <= 1'b0;
        end else begin
            if (counter_r == 99_999) begin
                counter_r <= 0;
                o_1khz    <= 1'b1;
                //o_1khz <= ~o_1khz; -> duty ratio가 1:1
            end else begin
                counter_r <= counter_r + 1;
                o_1khz    <= 1'b0;
            end
        end
    end

endmodule

module counter_4 (
    input        clk,
    input        reset,
    output [1:0] digit_sel
);

    reg [1:0] counter_r;

    assign digit_sel = counter_r;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            //init counter_r
            counter_r <= 0;
        end else begin
            //to do
            counter_r <= counter_r + 1;
        end
    end

endmodule

module decoder_2x4 (
    input      [1:0] digit_sel,
    output reg [3:0] fnd_digit
);

    always @(*) begin
        case (digit_sel)
            2'b00: fnd_digit = 4'b1110;
            2'b01: fnd_digit = 4'b1101;
            2'b10: fnd_digit = 4'b1011;
            2'b11: fnd_digit = 4'b0111;
        endcase
    end

endmodule

module mux_4x1 (
    input      [1:0] sel,
    input      [3:0] digit_1,
    input      [3:0] digit_10,
    input      [3:0] digit_100,
    input      [3:0] digit_1000,
    output reg [3:0] mux_out
);

    always @(*) begin
        case (sel)
            2'b00: mux_out = digit_1;
            2'b01: mux_out = digit_10;
            2'b10: mux_out = digit_100;
            2'b11: mux_out = digit_1000;
        endcase
    end

endmodule

module digit_splitter (
    input  [7:0] tx_data,
    input  [7:0] rx_data,
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);
    assign digit_1    = rx_data[3:0];
    assign digit_10   = rx_data[7:4];
    assign digit_100  = tx_data[3:0];
    assign digit_1000 = tx_data[7:4];

endmodule


module bcd (
    input      [3:0] bcd,
    output reg [7:0] fnd_data
);

    always @(bcd) begin
        case (bcd)
            4'd0:    fnd_data = 8'hC0;
            4'd1:    fnd_data = 8'hF9;
            4'd2:    fnd_data = 8'hA4;
            4'd3:    fnd_data = 8'hB0;
            4'd4:    fnd_data = 8'h99;
            4'd5:    fnd_data = 8'h92;
            4'd6:    fnd_data = 8'h82;
            4'd7:    fnd_data = 8'hF8;
            4'd8:    fnd_data = 8'h80;
            4'd9:    fnd_data = 8'h90;
            4'hA:    fnd_data = 8'h88;  // A
            4'hB:    fnd_data = 8'h83;  // b
            4'hC:    fnd_data = 8'hC6;  // C
            4'hD:    fnd_data = 8'hA1;  // d
            4'hE:    fnd_data = 8'h86;  // E
            4'hF:    fnd_data = 8'h8E;  // F
            default: fnd_data = 8'hFF;
        endcase
    end

endmodule
