`timescale 1ns/1ps
module wait_tb;
    localparam [31:0] BASE = 32'h2000f000;
    localparam [31:0] TOKEN = 32'h53454152;
    reg clk = 0, rst = 0;
    always #5 clk = ~clk;
    reg [31:0] rom[0:127], words[0:7];
    wire [31:0] pc, address, data;
    wire req, we;
    wire [31:0] instruction = pc < 512 ? rom[pc[8:2]] : 32'h00000013;
    wire [31:0] read_data = $test$plusargs("first_read_match") ? TOKEN : words[5];
    integer i, writes = 0, final_writes;

    tinyriscv dut (
        .clk(clk), .rst(rst), .rib_ex_req_o(req), .rib_ex_we_o(we),
        .rib_ex_addr_o(address), .rib_ex_data_o(data), .rib_ex_data_i(read_data),
        .rib_ex_tag_i(4'b0), .rib_pc_addr_o(pc), .rib_pc_data_i(instruction),
        .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0), .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );

    always @(posedge clk) if (rst) begin
        if (dut.csr_we_o !== 0 || dut.safety_check_en !== 0)
            $fatal(1, "Unexpected CSR access or enable");
        if (req) begin
            if (address < BASE || address > BASE + 28 || address[1:0] != 0)
                $fatal(1, "Unexpected bus address %h", address);
            if (we) begin
                words[address[4:2]] <= data;
                writes <= writes + 1;
            end else if (address != BASE + 20) $fatal(1, "Unexpected read %h", address);
        end
    end

    initial begin
        for (i = 0; i < 8; i = i + 1) words[i] = 32'hdeadbeef;
        words[5] = TOKEN; // Stale SRAM from before boot.
        $readmemh("firmware.hex", rom);
        if ($test$plusargs("first_branch_fallthrough")) rom[13] = 32'h00000013;
        repeat (3) @(negedge clk);
        rst = 1;
        repeat (70) @(negedge clk);
        if (words[0] !== 32'h57414931 || words[2] !== TOKEN || words[5] !== 0)
            $fatal(1, "Invalid magic, compare value or cleared token");

        if ($test$plusargs("first_read_match")) begin
            if (words[1] !== TOKEN || words[3] !== TOKEN || words[6] !== 1 || words[7] !== 0 ||
                words[4] !== 32'h5741600d)
                $fatal(1, "First-read match was not identified");
        end else if ($test$plusargs("first_branch_fallthrough")) begin
            if (words[1] !== 0 || words[3] !== 0 || words[6] !== 1 || words[7] !== TOKEN ||
                words[4] !== 32'h5741fa11)
                $fatal(1, "Injected branch fallthrough was not identified");
        end else begin
            if (words[4] !== 32'h57410001 || words[1] !== 0)
                $fatal(1, "Failed to wait after boot");
            words[5] = TOKEN ^ 32'h1;
            repeat (40) @(negedge clk);
            if (words[4] !== 32'h57410001 || words[5] !== (TOKEN ^ 32'h1))
                $fatal(1, "Wrong value did not stay waiting");
            words[5] = TOKEN;
            repeat (70) @(negedge clk);
            if (words[4] !== 32'h5741600d || words[3] !== TOKEN ||
                words[6] !== 2 || words[7] !== 0 || words[5] !== 0)
                $fatal(1, "Correct token was not consumed from the wait path");
        end
        final_writes = writes;
        repeat (30) @(negedge clk);
        if (writes != final_writes) $fatal(1, "Unexpected repeat execution");
        $display("PASS first=%h compare=%h exit=%h route=%0d xor=%h status=%h",
            words[1], words[2], words[3], words[6], words[7], words[4]);
        $finish;
    end
endmodule
