`timescale 1ns/1ps
module csr_toggle_tb;
    reg clk = 0, rst = 0;
    always #5 clk = ~clk;
    reg [31:0] rom[0:127];
    reg [31:0] mailbox[0:4];
    wire [31:0] pc, address, data;
    wire req, we;
    wire [31:0] instruction = pc < 512 ? rom[pc[8:2]] : 32'h00000013;
    integer rises = 0, falls = 0, stores = 0, csr_writes = 0, i;
    reg previous_enable = 0;
    reg zero_control;
    tinyriscv dut (
        .clk(clk), .rst(rst), .rib_ex_req_o(req), .rib_ex_we_o(we),
        .rib_ex_addr_o(address), .rib_ex_data_o(data), .rib_ex_data_i(32'b0),
        .rib_ex_tag_i(4'b0), .rib_pc_addr_o(pc), .rib_pc_data_i(instruction),
        .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0), .jtag_reset_flag_i(1'b0),
        .int_i(8'b0)
    );

    always @(posedge clk) if (rst) begin
        if (dut.safety_check_en !== 1'b0 && dut.safety_check_en !== 1'b1)
            $fatal(1, "Unknown safety enable");
        if (dut.safety_check_en && !previous_enable) rises <= rises + 1;
        if (!dut.safety_check_en && previous_enable) falls <= falls + 1;
        previous_enable <= dut.safety_check_en;
        if (dut.csr_we_o && dut.csr_waddr_o == 32'h803) begin
            csr_writes <= csr_writes + 1;
            $display("CSR request pc=%h data=%h", pc, dut.csr_wdata_o);
        end

        if (req) begin
            if (dut.safety_check_en !== 0 || we !== 1 ||
                address < 32'h2000f000 || address > 32'h2000f010 || address[1:0] != 0)
                $fatal(1, "Unexpected data bus access: addr=%h we=%b safety=%b",
                    address, we, dut.safety_check_en);
            mailbox[address[4:2]] <= data;
            stores <= stores + 1;
        end
    end

    initial begin
        zero_control = $test$plusargs("zero_control");
        // Force only the reference model's CSR storage for the negative control.
        if (zero_control) force dut.u_csr_reg.safety_ctrl = 32'h00000000;
        for (i = 0; i < 5; i = i + 1) mailbox[i] = 32'hdeadbeef;
        $readmemh("firmware.hex", rom);
        $dumpfile(zero_control ? "zero_control.vcd" : "reference.vcd");
        $dumpvars(1, csr_toggle_tb);
        $dumpvars(1, dut);
        repeat (3) @(negedge clk);
        rst = 1;

        repeat (160) begin
            @(posedge clk); #1;
            if (dut.u_regs.regs[26] === 32'h3f || dut.u_regs.regs[26] === 32'h3e)
                $fatal(1, "Probe stopped: marker=%h pc=%h mcause=%h",
                    dut.u_regs.regs[26], pc, dut.u_csr_reg.mcause);
            if (mailbox[4] === 32'h5345600d || mailbox[4] === 32'h5345fa11) begin
                if (mailbox[0] !== 32'h53454832 || mailbox[1] !== 0 ||
                    mailbox[3] !== 0 || stores !== 6 || csr_writes !== 5)
                    $fatal(1, "Unexpected mailbox or request count: stores=%0d CSR writes=%0d",
                        stores, csr_writes);
                if (zero_control) begin
                    if (mailbox[2] !== 0 || mailbox[4] !== 32'h5345fa11 ||
                        rises !== 0 || falls !== 0)
                        $fatal(1, "Constant-zero negative control was not rejected");
                end else begin
                    if (mailbox[2] !== 1 || mailbox[4] !== 32'h5345600d ||
                        rises !== 1 || falls !== 1)
                        $fatal(1, "Reference CSR failed to toggle and restore");
                end
                $display("PASS zero_control=%b CSR=%h -> %h -> %h enable_edges=%0d/%0d result=%h",
                    zero_control, mailbox[1], mailbox[2], mailbox[3], rises, falls, mailbox[4]);
                $finish;
            end
        end
        $fatal(1, "Timeout: pc=%h result=%h", pc, mailbox[4]);
    end
endmodule
