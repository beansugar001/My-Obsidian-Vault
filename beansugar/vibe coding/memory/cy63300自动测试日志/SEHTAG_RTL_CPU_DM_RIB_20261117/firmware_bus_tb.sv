`timescale 1ns/1ps
`include "defines.v"
module firmware_bus_tb;
    localparam [31:0] BASE = 32'h2000f000;
    localparam [31:0] DONE_PC = 32'h00000084;
    localparam [31:0] DONE_MAGIC = 32'h52547000;
    reg clk = 0, rst_n = 0, request = 0, response_ack = 0;
    always #5 clk = ~clk;
    reg [39:0] command = 0;
    wire request_ack, response, debug_req, debug_we, debug_halt, debug_reset, hold;
    wire reg_we, cpu_req, cpu_we, ram_we;
    wire [4:0] debug_reg_addr;
    wire [39:0] result;
    wire [31:0] debug_addr, debug_wdata, debug_rdata, debug_reg_write, debug_reg_read;
    wire [31:0] cpu_addr, cpu_wdata, cpu_rdata, pc, instruction;
    wire [31:0] rom_addr, ram_addr, ram_wdata;
    reg [31:0] rom [0:127], words [0:68];
    wire [31:0] rom_data = rom_addr < 512 ? rom[rom_addr[8:2]] : `INST_NOP;
    wire [31:0] ram_data = ram_addr >= BASE[27:0] && ram_addr <= BASE[27:0] + 272
                       ? words[(ram_addr - BASE[27:0]) >> 2] : 32'b0;

    jtag_dm dm (
        .clk(clk), .rst_n(rst_n), .dm_ack_o(request_ack),
        .dtm_req_valid_i(request), .dtm_req_data_i(command),
        .dtm_ack_i(response_ack), .dm_resp_data_o(result), .dm_resp_valid_o(response),
        .dm_reg_we_o(reg_we), .dm_reg_addr_o(debug_reg_addr), .dm_reg_wdata_o(debug_reg_write),
        .dm_reg_rdata_i(debug_reg_read), .dm_mem_we_o(debug_we), .dm_mem_addr_o(debug_addr),
        .dm_mem_wdata_o(debug_wdata), .dm_mem_rdata_i(debug_rdata), .dm_op_req_o(debug_req),
        .dm_halt_req_o(debug_halt), .dm_reset_req_o(debug_reset)
    );
    tinyriscv cpu (
        .clk(clk), .rst(rst_n), .rib_ex_addr_o(cpu_addr), .rib_ex_data_i(cpu_rdata),
        .rib_ex_data_o(cpu_wdata), .rib_ex_req_o(cpu_req), .rib_ex_we_o(cpu_we),
        .rib_pc_addr_o(pc), .rib_pc_data_i(instruction), .jtag_reg_addr_i(debug_reg_addr),
        .jtag_reg_data_i(debug_reg_write), .jtag_reg_we_i(reg_we), .jtag_reg_data_o(debug_reg_read),
        .rib_hold_flag_i(hold), .jtag_halt_flag_i(debug_halt), .jtag_reset_flag_i(debug_reset),
        .int_i(8'b0)
    );
    rib fabric (
        .clk(clk), .rst(rst_n),
        .m0_addr_i(cpu_addr), .m0_data_i(cpu_wdata), .m0_data_o(cpu_rdata), .m0_req_i(cpu_req), .m0_we_i(cpu_we),
        .m1_addr_i(pc), .m1_data_i(32'b0), .m1_data_o(instruction), .m1_req_i(1'b1), .m1_we_i(1'b0),
        .m2_addr_i(debug_addr), .m2_data_i(debug_wdata), .m2_data_o(debug_rdata), .m2_req_i(debug_req), .m2_we_i(debug_we),
        .m3_addr_i(32'b0), .m3_data_i(32'b0), .m3_data_o(), .m3_req_i(1'b0), .m3_we_i(1'b0),
        .s0_addr_o(rom_addr), .s0_data_o(), .s0_data_i(rom_data), .s0_we_o(),
        .s1_addr_o(), .s1_data_o(), .s1_data_i(32'b0), .s1_we_o(),
        .s2_addr_o(ram_addr), .s2_data_o(ram_wdata), .s2_data_i(ram_data), .s2_we_o(ram_we),
        .s3_addr_o(), .s3_data_o(), .s3_data_i(32'b0), .s3_we_o(),
        .s4_addr_o(), .s4_data_o(), .s4_data_i(32'b0), .s4_we_o(),
        .s5_addr_o(), .s5_data_o(), .s5_data_i(32'b0), .s5_we_o(),
        .hold_flag_o(hold)
    );

    integer i, cycle = 0, completed_at = -1;
    integer dmi_requests = 0, debug_holds = 0, debug_holds_after = 0;
    integer first_writes = 0, second_writes = 0, mirror_writes = 0;
    integer post_done_writes = 0, post_done_count_writes = 0;
    integer fetch_outside_terminal_window = 0, execute_outside_terminal = 0;
    integer delay_cycles = 0;
    string mode = "none", phase = "overlap";

    always @(posedge clk) if (rst_n) begin
        cycle <= cycle + 1;
        if (debug_we || debug_halt || debug_reset || reg_we) $fatal(1, "Unexpected debug side effect");
        if (debug_req && !cpu_req) begin
            if (!hold || instruction !== `INST_NOP) $fatal(1, "Debug grant did not hold fetch");
            debug_holds <= debug_holds + 1;
            if (completed_at >= 0) debug_holds_after <= debug_holds_after + 1;
        end
        if (completed_at >= 0 && cycle > completed_at + 8) begin
            if (pc !== DONE_PC && pc !== DONE_PC + 4 && pc !== DONE_PC + 8)
                fetch_outside_terminal_window <= fetch_outside_terminal_window + 1;
            if (cpu.ie_inst_o !== `INST_NOP && cpu.ie_inst_addr_o !== DONE_PC)
                execute_outside_terminal <= execute_outside_terminal + 1;
        end
        if (ram_we) begin
            if (ram_addr < BASE[27:0] || ram_addr > BASE[27:0] + 272 || ram_addr[1:0] != 0)
                $fatal(1, "Unexpected write at %h", ram_addr);
            words[(ram_addr - BASE[27:0]) >> 2] <= ram_wdata;
            if (completed_at >= 0) post_done_writes <= post_done_writes + 1;
            case (ram_addr)
                32'h0000f004: first_writes <= first_writes + 1;
                32'h0000f010: second_writes <= second_writes + 1;
                32'h0000f110: mirror_writes <= mirror_writes + 1;
                32'h0000f02c: if (ram_wdata == DONE_MAGIC && completed_at < 0)
                    completed_at <= cycle;
            endcase
            if (completed_at >= 0 && (ram_addr == 32'h0000f010 || ram_addr == 32'h0000f110))
                post_done_count_writes <= post_done_count_writes + 1;
        end
    end

    task automatic dmi(input [1:0] op, input [5:0] addr, input [31:0] data, output [31:0] value);
        @(negedge clk);
        command = {addr, data, op};
        request = 1;
        wait (request_ack);
        @(negedge clk);
        request = 0;
        wait (response);
        @(negedge clk);
        if (result[1:0] !== 0) $fatal(1, "DMI error at %h", addr);
        value = result[33:2];
        dmi_requests = dmi_requests + 1;
        response_ack = 1;
        wait (!response);
        @(negedge clk);
        response_ack = 0;
        wait (!request_ack);
        repeat (5) @(negedge clk);
    endtask

    reg [31:0] reply;
    integer j;
    initial begin
        if ($value$plusargs("mode=%s", mode)) begin end
        if ($value$plusargs("phase=%s", phase)) begin end
        if ($value$plusargs("delay=%d", delay_cycles)) begin end
        if (mode != "none" && mode != "dmstatus" && mode != "sba") $fatal(1, "Invalid mode");
        if (phase != "overlap" && phase != "after") $fatal(1, "Invalid phase");
        for (i = 0; i < 69; i = i + 1) words[i] = 32'b0;
        $readmemh("firmware.hex", rom);
        if ($test$plusargs("wave")) begin
            $dumpfile("cpu_dm_rib.vcd");
            $dumpvars(1, firmware_bus_tb);
        end
        repeat (4) @(negedge clk);
        rst_n = 1;
        if (mode != "none") begin
            if (phase == "after") wait (completed_at >= 0);
            else repeat (12) @(negedge clk);
            repeat (delay_cycles) @(negedge clk);
            if (mode == "sba") dmi(2'b10, 6'h38, 32'h00140000, reply);
            for (j = 0; j < 16; j = j + 1) begin
                if (mode == "dmstatus") begin
                    dmi(2'b01, 6'h11, 0, reply);
                    if (reply !== 32'h00430c82) $fatal(1, "DMSTATUS mismatch %h", reply);
                end else begin
                    dmi(2'b10, 6'h39, j % 2 == 0 ? 32'h2000f004 : 32'h2000f02c, reply);
                    dmi(2'b01, 6'h3c, 0, reply);
                    if (phase == "after" && reply !== (j % 2 == 0 ? 32'd8 : DONE_MAGIC))
                        $fatal(1, "Fixed SRAM read mismatch %h", reply);
                end
            end
        end
    end

    initial begin
        repeat (4800) @(negedge clk);
        $display("RESULT mode=%s phase=%s offset=%0d done_cycle=%0d pc=%08h first=%0d second=%0d mirror=%0d first_stores=%0d second_stores=%0d mirror_stores=%0d post_stores=%0d post_count_stores=%0d dmi_requests=%0d debug_holds=%0d debug_holds_after=%0d fetch_outside_terminal=%0d execute_outside_terminal=%0d",
            mode, phase, delay_cycles, completed_at, pc, words[1], words[4], words[68],
            first_writes, second_writes, mirror_writes, post_done_writes, post_done_count_writes,
            dmi_requests, debug_holds, debug_holds_after, fetch_outside_terminal_window, execute_outside_terminal);
        $finish;
    end
endmodule
