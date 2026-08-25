`timescale 1ns / 1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

interface spi_if (
    input logic clk,
    input logic rst
);
    // Control/Data Signals
    logic       start;
    logic [7:0] tx_data_m;
    logic [7:0] rx_data_m;
    logic [7:0] tx_data_s;
    logic [7:0] rx_data_s;
    logic       done_m;
    logic       done_s;
    logic       busy_m;

    // Config Signals (Randomized)
    logic       cpol;
    logic       cpha;

    // SPI Physical Lines
    logic       sclk;
    logic       mosi;
    logic       miso;
    logic       cs_n;

    clocking drv_cb @(posedge clk);
        default input #1step output #0;
        output start, tx_data_m, tx_data_s, cpol, cpha;
        input rx_data_m, rx_data_s, done_m, done_s, busy_m;
        input sclk, mosi, miso, cs_n;
    endclocking

    clocking mon_cb @(posedge clk);
        default input #1step output #0;
        input start, tx_data_m, tx_data_s, cpol, cpha;
        input rx_data_m, rx_data_s, done_m, done_s, busy_m;
        input sclk, mosi, miso, cs_n;
    endclocking
endinterface

class spi_seq_item extends uvm_sequence_item;
    `uvm_object_utils(spi_seq_item)

    rand logic [7:0] tx_data_m;
    rand logic [7:0] tx_data_s;
    rand logic       cpol;
    rand logic       cpha;

    logic      [7:0] rx_data_m;
    logic      [7:0] rx_data_s;

    constraint mode0 {
        cpol == 1'b0;
        cpha == 1'b0;
    }

    function new(string name = "spi_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "MODE:%0d | M_TX:0x%h, S_TX:0x%h | M_RX:0x%h, S_RX:0x%h",
            {
                cpol, cpha
            },
            tx_data_m,
            tx_data_s,
            rx_data_m,
            rx_data_s
        );
    endfunction
endclass

class spi_rand_seq extends uvm_sequence #(spi_seq_item);
    `uvm_object_utils(spi_rand_seq)
    int num_trans = 100;

    function new(string name = "spi_rand_seq");
        super.new(name);
    endfunction

    task body();
        spi_seq_item item;
        repeat (num_trans) begin
            item = spi_seq_item::type_id::create("item");
            start_item(item);
            if (!item.randomize()) `uvm_fatal("SEQ", "Randomization failed")
            `uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM)
            finish_item(item);
        end
    endtask
endclass

// --- DRIVER ---
class spi_driver extends uvm_driver #(spi_seq_item);
    `uvm_component_utils(spi_driver)
    virtual spi_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "spi interface를 config db에서 찾을 수 없음.")
        end
    endfunction

    task run_phase(uvm_phase phase);
        spi_seq_item item;
        vif.start <= 0;

        wait (vif.rst == 0);
        repeat (10) @(vif.drv_cb);

        forever begin
            seq_item_port.get_next_item(item);

            vif.cpol      <= item.cpol;
            vif.cpha      <= item.cpha;
            vif.tx_data_m <= item.tx_data_m;
            vif.tx_data_s <= item.tx_data_s;

            repeat (5) @(vif.drv_cb);

            vif.start <= 1'b1;
            @(vif.drv_cb);
            vif.start <= 1'b0;

            wait (vif.drv_cb.done_m === 1'b1);

            repeat (10) @(vif.drv_cb);

            item.rx_data_m = vif.drv_cb.rx_data_m;
            item.rx_data_s = vif.drv_cb.rx_data_s;

            seq_item_port.item_done();
        end
    endtask
endclass

// --- MONITOR ---
class spi_monitor extends uvm_monitor;
    `uvm_component_utils(spi_monitor)
    uvm_analysis_port #(spi_seq_item) ap;
    virtual spi_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
        if (!uvm_config_db#(virtual spi_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "spi interface를 config_db에서 찾을 수 없음.")
        end
    endfunction

    task run_phase(uvm_phase phase);
        spi_seq_item item;
        forever begin
            @(vif.mon_cb);
            if (vif.mon_cb.done_m) begin
                //@(vif.mon_cb); 
                item           = spi_seq_item::type_id::create("item");
                item.cpol      = vif.mon_cb.cpol;
                item.cpha      = vif.mon_cb.cpha;
                item.tx_data_m = vif.mon_cb.tx_data_m;
                `uvm_info(get_type_name(), $sformatf("[Master_TX] tx_data_m = 0x%02h",
                                                     item.tx_data_m), UVM_HIGH)
                item.tx_data_s = vif.mon_cb.tx_data_s;
                `uvm_info(get_type_name(), $sformatf("[Slave_TX] tx_data_s = 0x%02h",
                                                     item.tx_data_s), UVM_HIGH)
                item.rx_data_m = vif.mon_cb.rx_data_m;
                `uvm_info(get_type_name(), $sformatf("[Master_RX] rx_data_m = 0x%02h",
                                                     item.rx_data_m), UVM_HIGH)
                item.rx_data_s = vif.mon_cb.rx_data_s;
                `uvm_info(get_type_name(), $sformatf("[Slave_RX] rx_data_s = 0x%02h",
                                                     item.rx_data_s), UVM_HIGH)
                ap.write(item);
            end
        end
    endtask
endclass

// --- SCOREBOARD ---
class spi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(spi_scoreboard)
    uvm_analysis_imp #(spi_seq_item, spi_scoreboard) ap_imp;
    
    int pass_cnt_m2s = 0;
    int fail_cnt_m2s = 0;
    int pass_cnt_s2m = 0;
    int fail_cnt_s2m = 0;
    // 이전에 들어온 Master TX 데이터를 저장하는 변수
    logic [7:0] prev_tx_data_m = 8'h00;
    bit first_trans = 1;  // 첫 번째 전송은 비교에서 제외

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap_imp = new("ap_imp", this);
    endfunction

    function void write(spi_seq_item t);
        // 1. Master -> Slave (M_TX vs S_RX) 검증
        if (first_trans) begin
            // 첫 번째 전송은 Slave에 데이터가 아직 안 쌓였으므로 비교 패스
            `uvm_info("SCB_M2S", "First transaction: skipping comparison", UVM_LOW)
            first_trans = 0;
        end else begin
            // 현재의 S_RX를 이전의 M_TX와 비교
            if (t.rx_data_s !== prev_tx_data_m) begin
                fail_cnt_m2s++;
                `uvm_error("SCB_M2S", $sformatf("Mismatch! Prev_M_TX(0x%h) -> Curr_S_RX(0x%h)",
                                                prev_tx_data_m, t.rx_data_s))
            end else begin
                pass_cnt_m2s++;
                `uvm_info("SCB_M2S", $sformatf(
                          "Match! M_TX(0x%h) == S_RX(0x%h)", prev_tx_data_m, t.rx_data_s), UVM_MEDIUM)
            end
        end

        // 현재 M_TX를 저장해서 다음 트랜잭션 때 S_RX와 비교
        prev_tx_data_m = t.tx_data_m;

        // 2. Slave -> Master (S_TX vs M_RX) 검증
        if (t.tx_data_s !== t.rx_data_m) begin
            fail_cnt_s2m++;
            `uvm_error("SCB_S2M", $sformatf("Mismatch! S_TX(0x%h) -> M_RX(0x%h) [Mode:%0b]",
                                            t.tx_data_s, t.rx_data_m, {t.cpol, t.cpha}))
        end else begin
            pass_cnt_s2m++;
            `uvm_info("SCB_S2M", $sformatf(
                      "Match! S_TX(0x%h) -> M_RX(0x%h) [Mode:%0b]",
                      t.tx_data_s,
                      t.rx_data_m,
                      {
                          t.cpol, t.cpha
                      }
                      ), UVM_MEDIUM)
        end
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "\n", UVM_LOW)
        `uvm_info(get_type_name(), " =========================================", UVM_LOW)
        `uvm_info(get_type_name(), "        SPI SCOREBOARD SUMMARY            ", UVM_LOW)
        `uvm_info(get_type_name(), " =========================================", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  "  [Master->Slave]  Pass: %0d, Fail: %0d", pass_cnt_m2s, fail_cnt_m2s), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  "  [Slave->Master]  Pass: %0d, Fail: %0d", pass_cnt_s2m, fail_cnt_s2m), UVM_LOW)
        `uvm_info(get_type_name(), " -----------------------------------------", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  "  Total Successful Transfers: %0d", pass_cnt_m2s + pass_cnt_s2m), UVM_LOW)
        `uvm_info(get_type_name(), " =========================================", UVM_LOW)

        if (fail_cnt_m2s > 0 || fail_cnt_s2m > 0) begin
            `uvm_error(get_type_name(), "Test Result: FAILED (Check mismatches above)")
        end else begin
            `uvm_info(get_type_name(), "Test Result: PASSED", UVM_LOW)
        end
        `uvm_info(get_type_name(), "\n", UVM_LOW)
    endfunction
endclass

class spi_agent extends uvm_agent;
    `uvm_component_utils(spi_agent)
    spi_driver drv;
    spi_monitor mon;
    uvm_sequencer #(spi_seq_item) sqr;
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        drv = spi_driver::type_id::create("drv", this);
        mon = spi_monitor::type_id::create("mon", this);
        sqr = uvm_sequencer#(spi_seq_item)::type_id::create("sqr", this);
    endfunction
    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass

class spi_coverage extends uvm_subscriber #(spi_seq_item);
    `uvm_component_utils(spi_coverage)

    spi_seq_item t_item;

    covergroup cg_spi;
        // CPOL, CPHA
        cp_cpol: coverpoint t_item.cpol {
            bins mode0 = {1'b0}; illegal_bins others = {1'b1};
        }
        cp_cpha: coverpoint t_item.cpha {bins mode0 = {1'b0}; illegal_bins others = {1'b1};}

        // Data (Master 기준)
        cp_tx_data: coverpoint t_item.tx_data_m {
            bins zero = {8'h00}; bins max = {8'hff}; bins others = {[8'h01 : 8'hfe]};
        }

        cx_mode_data: cross cp_cpol, cp_cpha, cp_tx_data;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_spi = new();
    endfunction

    function void write(spi_seq_item t);
        this.t_item = t;
        cg_spi.sample();
    endfunction

    // 요청하신 상세 리포트 형식
    virtual function void report_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "\n", UVM_LOW)
        `uvm_info(get_type_name(), " ===== SPI Coverage Summary =====", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  Overall Coverage : %.1f%%", cg_spi.get_coverage()),
                  UVM_LOW)
        `uvm_info(get_type_name(), " ---------------------------------", UVM_LOW)

        `uvm_info(get_type_name(), $sformatf(
                  "  CPOL Coverage    : %.1f%%", cg_spi.cp_cpol.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  "  CPHA Coverage    : %.1f%%", cg_spi.cp_cpha.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  "  TX Data Coverage : %.1f%%", cg_spi.cp_tx_data.get_coverage()), UVM_LOW)

        `uvm_info(get_type_name(), " ---------------------------------", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf(
                  "  Cross(Mode, Data): %.1f%%", cg_spi.cx_mode_data.get_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), " =================================", UVM_LOW)
        `uvm_info(get_type_name(), "\n", UVM_LOW)
    endfunction
endclass

class spi_env extends uvm_env;
    `uvm_component_utils(spi_env)

    spi_agent    agt;
    spi_scoreboard scb;
    spi_coverage cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = spi_agent::type_id::create("agt", this);
        scb = spi_scoreboard::type_id::create("scb", this);
        cov = spi_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        // 모니터에서 나온 데이터를 스코어보드와 커버리지 양쪽으로 쏴줌
        agt.mon.ap.connect(scb.ap_imp);
        agt.mon.ap.connect(cov.analysis_export);
    endfunction
endclass
class spi_rand_test extends uvm_test;
    `uvm_component_utils(spi_rand_test)
    spi_env env;
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        env = spi_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
        spi_rand_seq seq = spi_rand_seq::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(env.agt.sqr);
        phase.drop_objection(this);
    endtask

endclass
module tb_spi_uvm;
    logic clk, rst;
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        #20 rst = 0;
    end

    spi_if s_if (
        clk,
        rst
    );

    // 루프백 DUT 연결 부분
    spi_loopback dut (
        .clk(clk),
        .rst(rst),
        .cpol(s_if.cpol),
        .cpha(s_if.cpha),
        .clk_div(8'd5),
        .start(s_if.start),
        .tx_data_m(s_if.tx_data_m),
        .rx_data_m(s_if.rx_data_m),
        .done_m(s_if.done_m),
        .busy_m(s_if.busy_m),
        .tx_data_s(s_if.tx_data_s),
        .rx_data_s(s_if.rx_data_s),
        .done_s(s_if.done_s),
        .sclk(s_if.sclk),
        .mosi(s_if.mosi),
        .miso(s_if.miso),
        .cs_n(s_if.cs_n)
    );

    initial begin
        uvm_config_db#(virtual spi_if)::set(null, "*", "vif", s_if);
        run_test("spi_rand_test");
    end

    initial begin
        $fsdbDumpfile("novas.fsdb");
        $fsdbDumpvars(0, tb_spi_uvm, "+all");
    end
endmodule
