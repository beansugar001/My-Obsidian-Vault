`timescale 1ns/1ps
module armed_probe_tb;
    localparam [31:0] BASE = 32'h2000f000;
    localparam [31:0] TOKEN = 32'h53454152;
    reg clk = 0, rst = 0, valid_trigger_issued = 0, previous_enable = 0;
    always #5 clk = ~clk;
    reg [31:0] rom[0:127], mailbox[0:5];
    wire [31:0] pc, address, data;
    wire req, we;
    wire [31:0] instruction = pc < 512 ? rom[pc[8:2]] : 32'h00000013;
    wire [31:0] read_data = address == BASE + 20 ? mailbox[5] : 32'b0;
    integer rises = 0, falls = 0, writes_803 = 0, i;

    tinyriscv dut (
        .clk(clk), .rst(rst), .rib_ex_req_o(req), .rib_ex_we_o(we),
        .rib_ex_addr_o(address), .rib_ex_data_o(data), .rib_ex_data_i(read_data),
        .rib_ex_tag_i(4'b0), .rib_pc_addr_o(pc), .rib_pc_data_i(instruction),
        .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0), .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );

    always @(posedge clk) if (rst) begin
        if (!valid_trigger_issued && (dut.csr_we_o !== 0 || dut.safety_check_en !== 0))
            $fatal(1, "CSR write or enable before valid token");
        if (dut.csr_we_o && dut.csr_waddr_o == 32'h803) writes_803 <= writes_803 + 1;
        if (dut.safety_check_en && !previous_enable) rises <= rises + 1;
        if (!dut.safety_check_en && previous_enable) falls <= falls + 1;
        previous_enable <= dut.safety_check_en;
        if (req) begin
            if (dut.safety_check_en !== 0 || address < BASE || address > BASE + 20 || address[1:0] != 0)
                $fatal(1, "Unexpected memory access addr=%h safety=%b", address, dut.safety_check_en);
            if (we) mailbox[address[4:2]] <= data;
            else if (address != BASE + 20) $fatal(1, "Unexpected read addr=%h", address);
        end
    end

    initial begin
        for (i = 0; i < 6; i = i + 1) mailbox[i] = 32'hdeadbeef;
        mailbox[5] = TOKEN; // A stale token must be cleared on boot.
        if ($test$plusargs("zero_control")) force dut.u_csr_reg.safety_ctrl = 32'b0;
        $readmemh("firmware.hex", rom);
        repeat (3) @(negedge clk);
        rst = 1;
        repeat (55) @(negedge clk);
        if (mailbox[0] !== 32'h53454833 || mailbox[4] !== 0 || mailbox[5] !== 0)
            $fatal(1, "Boot did not clear stale token and publish waiting state");
        mailbox[5] = TOKEN ^ 32'h1;
        repeat (30) @(negedge clk);
        if (mailbox[4] !== 0 || writes_803 != 0)
            $fatal(1, "Incorrect token triggered execution");
        $display("PASS stale and incorrect tokens did not activate CSR");
        if ($test$plusargs("unarmed")) $finish;

        valid_trigger_issued = 1;
        mailbox[5] = TOKEN;
        repeat (170) begin
            @(negedge clk);
            if (dut.u_regs.regs[26] === 32'h3e || dut.u_regs.regs[26] === 32'h3f)
                $fatal(1, "Probe stopped before completion: pc=%h", pc);
            if (mailbox[4] === 32'h5345600d || mailbox[4] === 32'h5345fa11) begin
                if ($test$plusargs("zero_control")) begin
                    if (mailbox[1] !== 0 || mailbox[2] !== 0 || mailbox[3] !== 0 ||
                        mailbox[4] !== 32'h5345fa11 || rises != 0 || falls != 0)
                        $fatal(1, "Incorrect result under forced-zero control");
                end else if (mailbox[1] !== 0 || mailbox[2] !== 1 || mailbox[3] !== 0 ||
                             mailbox[4] !== 32'h5345600d || rises != 1 || falls != 1)
                    $fatal(1, "CSR did not change and restore");
                if (mailbox[5] !== 0 || writes_803 != 5)
                    $fatal(1, "Trigger not consumed or unexpected CSR writes");
                repeat (25) @(negedge clk);
                if (writes_803 != 5) $fatal(1, "Unexpected re-entry");
                $display("PASS CSR=%h/%h/%h result=%h edges=%0d/%0d",
                    mailbox[1], mailbox[2], mailbox[3], mailbox[4], rises, falls);
                $finish;
            end
        end
        $fatal(1, "Probe timed out: pc=%h state=%h", pc, mailbox[4]);
    end
endmodule
