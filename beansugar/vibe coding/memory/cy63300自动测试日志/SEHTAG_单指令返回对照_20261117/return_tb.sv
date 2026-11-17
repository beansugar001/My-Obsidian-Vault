`timescale 1ns/1ps
module return_tb;
    localparam [31:0] BASE = 32'h2000f000;
    localparam [31:0] MATCH = 32'h53454000;
    reg clk = 0, rst = 0, repeat_indirect_case;
    always #5 clk = ~clk;
    reg [31:0] rom[0:127], words[0:12];
    wire [31:0] pc, address, data;
    wire req, we;
    wire [31:0] instruction = pc < 512 ? rom[pc[8:2]] : 32'h00000013;
    wire [31:0] read_value = address == BASE + 48 ? words[12] : 32'b0;
    integer i, reads = 0, direct_records = 0, indirect_records = 0, writes = 0, completed_writes;

    tinyriscv dut (
        .clk(clk), .rst(rst), .rib_ex_req_o(req), .rib_ex_we_o(we),
        .rib_ex_addr_o(address), .rib_ex_data_o(data), .rib_ex_data_i(read_value),
        .rib_ex_tag_i(4'b0), .rib_pc_addr_o(pc), .rib_pc_data_i(instruction),
        .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0), .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );

    always @(posedge clk) if (rst) begin
        if (dut.csr_we_o !== 0 || dut.safety_check_en !== 0)
            $fatal(1, "Unexpected CSR operation");
        if (req) begin
            if (address < BASE || address > BASE + 48 || address[1:0] != 0)
                $fatal(1, "Unexpected bus address %h", address);
            if (we) begin
                words[address[5:2]] <= data;
                writes <= writes + 1;
                if (address == BASE + 4) direct_records <= direct_records + 1;
                if (address == BASE + 16) indirect_records <= indirect_records + 1;
            end else begin
                if (address != BASE + 48) $fatal(1, "Unexpected load address %h", address);
                reads <= reads + 1;
            end
        end
    end

    initial begin
        repeat_indirect_case = $test$plusargs("repeat_indirect_case");
        for (i = 0; i < 13; i = i + 1) words[i] = 32'hdeadbeef;
        $readmemh("firmware.hex", rom);
        if (rom['hf4/4] !== 32'h03042283 || rom['h100/4] !== 32'h00929663 ||
            rom['h170/4] !== 32'hefdff06f)
            $fatal(1, "Unexpected comparison or return instruction");
        // Model re-entry by overriding the return target with 0xF0.
        if (repeat_indirect_case) rom['h170/4] = 32'hf81ff06f;
        repeat (3) @(negedge clk);
        rst = 1;
        repeat (900) begin
            @(negedge clk);
            if (repeat_indirect_case && indirect_records >= 3) begin
                if (direct_records !== 1 || words[8] !== 32'h52546000 ||
                    words[9] !== 32'h52545000 || words[10] !== 0 || words[11] !== 0 ||
                    words[4] <= 8)
                    $fatal(1, "Re-entry diagnostic was not distinguishable");
                $display("PASS modeled_reentry count=%0d before=%h after=%h done=%h",
                    words[4], words[9], words[10], words[11]);
                $finish;
            end
            if (!repeat_indirect_case && words[11] === 32'h52547000) begin
                if (words[0] !== 32'h52544000 || words[1] !== 8 || words[2] !== MATCH ||
                    words[3] !== 32'h4d415000 || words[4] !== 8 || words[5] !== MATCH ||
                    words[6] !== 32'h4d415000 || words[7] !== 32'h52545000 ||
                    words[8] !== 32'h52546000 || words[9] !== 32'h52545000 ||
                    words[10] !== 32'h52546000 || reads !== 16 ||
                    direct_records !== 1 || indirect_records !== 1)
                    $fatal(1, "Unexpected normal result: counts=%0d/%0d reads=%0d", words[1], words[4], reads);
                completed_writes = writes;
                repeat (70) @(negedge clk);
                if (writes != completed_writes || reads !== 16) $fatal(1, "Access after completion");
                $display("PASS direct=%0d/%h indirect=%0d/%h done=%h stable_cycles=70",
                    words[1], words[8], words[4], words[10], words[11]);
                $finish;
            end
        end
        $fatal(1, "Timeout pc=%h reads=%0d indirect_records=%0d", pc, reads, indirect_records);
    end
endmodule
