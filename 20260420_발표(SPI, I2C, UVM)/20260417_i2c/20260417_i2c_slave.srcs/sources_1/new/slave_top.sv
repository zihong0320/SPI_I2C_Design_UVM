`timescale 1ns / 1ps

module slave_top (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] tx_data_s,
    output logic [7:0] rx_data_s,
    output logic [7:0] fnd_data,
    output logic [3:0] fnd_digit,

    input  logic       scl,
    inout  wire       sda
);
    logic rx_done_s;

    I2C_SLAVE U_I2C_S (
        .clk(clk),
        .rst(rst),
        .tx_data(tx_data_s),
        .rx_data(rx_data_s),
        .rx_done(rx_done_s),
        .scl(scl),
        .sda(sda)
    );

    fnd_controller U_FND_CTRL (
        .clk(clk),
        .reset(rst),
        .tx_data(tx_data_s),
        .rx_data(rx_data_s),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );

endmodule


module I2C_SLAVE (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] tx_data,
    output logic [7:0] rx_data,
    output logic       rx_done,

    // external i2c port
    input logic scl,
    inout logic sda
);
    logic sda_i, sda_o;

    assign sda_i = sda;
    assign sda   = sda_o ? 1'bz : 1'b0;

    i2c_slave u_i2c_slave (
        .*,
        .sda_i(sda_i),
        .sda_o(sda_o)
    );

endmodule


module i2c_slave (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] tx_data,
    output logic [7:0] rx_data,
    output logic       rx_done,

    // external i2c port
    input  logic scl,
    input  logic sda_i,
    output logic sda_o
);
    parameter SLAVE_ADDR = 7'd100;

    typedef enum logic [2:0] {
        IDLE = 3'b00,
        GET_ADDR,
        SEND_ACK,
        WRITE,
        READ,
        READ_ACK
    } i2c_slv_state_e;

    i2c_slv_state_e state;

    logic [7:0] rx_shift_reg;
    logic [3:0] bit_cnt;
    logic       is_read;

    logic [1:0] sync_scl, sync_sda_i;

    logic rising_scl, falling_scl;
    logic rising_sda_i, falling_sda_i;

    assign rising_scl    = {sync_scl == 2'b01};
    assign falling_scl   = {sync_scl == 2'b10};

    assign rising_sda_i  = {sync_sda_i == 2'b01};
    assign falling_sda_i = {sync_sda_i == 2'b10};

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sync_scl   <= 0;
            sync_sda_i <= 0;
        end else begin
            sync_scl   <= {sync_scl[0], scl};
            sync_sda_i <= {sync_sda_i[0], sda_i};
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= IDLE;
            rx_shift_reg <= 0;
            bit_cnt      <= 0;
            sda_o        <= 1; // High-Z
            rx_data      <= 0;
            rx_done      <= 0;
            is_read      <= 0;
        end else begin
            rx_done <= 1'b0;

            case (state)
                IDLE: begin
                    bit_cnt <= 0;
                    sda_o   <= 1;
                    if (sync_scl[1] && falling_sda_i) begin
                        state <= GET_ADDR;
                    end
                end

                GET_ADDR: begin
                    if (rising_scl) begin
                        rx_shift_reg <= {rx_shift_reg[6:0], sync_sda_i[1]};
                        bit_cnt      <= bit_cnt + 1;
                    end
                    
                    if (bit_cnt == 8 && falling_scl) begin
                        bit_cnt <= 0;
                        if (rx_shift_reg[7:1] == SLAVE_ADDR) begin
                            is_read <= rx_shift_reg[0];
                            sda_o   <= 1'b0;
                            state   <= SEND_ACK;
                        end else begin
                            state   <= IDLE;
                        end
                    end
                end

                SEND_ACK: begin
                    if (falling_scl) begin
                        if (is_read) begin
                            state <= READ;
                            bit_cnt <= 1;
                            sda_o <= tx_data[6];
                        end else begin
                            state <= WRITE;
                            bit_cnt <= 0;
                            sda_o <= 1'b1;
                        end
                    end
                end

                WRITE: begin
                    if (rising_scl) begin
                        rx_shift_reg <= {rx_shift_reg[6:0], sync_sda_i[1]};
                        bit_cnt      <= bit_cnt + 1;
                    end

                    if (bit_cnt == 8 && falling_scl) begin
                        rx_data  <= rx_shift_reg;
                        rx_done  <= 1'b1;
                        bit_cnt  <= 0;
                        sda_o    <= 1'b0;
                        state    <= SEND_ACK;
                    end
                    
                    if (sync_scl[1] && rising_sda_i) state <= IDLE;
                end

                READ: begin
                    if (falling_scl) begin
                        if (bit_cnt < 8) begin
                            sda_o   <= tx_data[7 - bit_cnt];
                            bit_cnt <= bit_cnt + 1;
                        end else begin
                            sda_o   <= 1'b1;
                            //bit_cnt <= 0;
                            state   <= READ_ACK;
                        end
                    end
                end

                READ_ACK: begin
                    if (falling_scl) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
            
            if (sync_scl[1] && rising_sda_i) state <= IDLE;
        end
    end
endmodule