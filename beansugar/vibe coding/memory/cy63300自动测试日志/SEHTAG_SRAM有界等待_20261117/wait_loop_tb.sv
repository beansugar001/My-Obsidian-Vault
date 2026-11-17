`timescale 1ns/1ps
module wait_loop_tb;
    localparam [31:0] BASE = 32'h2000f000;
    localparam [31:0] MATCH = 32'h53454000;
    localparam [31:0] MISS = 32'h13579000;
    reg clk = 0, rst = 0;
    always #5 clk = ~clk;
    reg [31:0] rom[0:127], words[0:12];
    wire [31:0] pc, address, data;
    wire req, we;
    wire [31:0] instruction = pc < 512 ? rom[pc[8:2]] : 32'h00000013;
    integer i, reads = 0;
    reg force_early_match;
    wire [31:0] read_value = address == BASE + 48
        ? ((force_early_match && reads == 0) ? MATCH : words[12])
        : 32'b0;
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
            if (we)
                words[address[5:2]] <= data;
            else begin
                if (address != BASE + 48) $fatal(1, "Unexpected load address %h", address);
                reads <= reads + 1;
            end
        end
    end

    initial begin
        force_early_match = $test$plusargs("force_early_match");
        for (i = 0; i < 13; i = i + 1) words[i] = 32'hdeadbeef;
        $readmemh("firmware.hex", rom);
        if (rom['hf4/4] !== 32'h03042283 || rom['hf8/4] !== 32'h00000013 ||
            rom['hfc/4] !== 32'h00000013 || rom['h100/4] !== 32'h00929663)
            $fatal(1, "LW, NOP and BNE words differ from single-branch baseline");
        repeat (3) @(negedge clk);
        rst = 1;
        repeat (900) begin
            @(negedge clk);
            if (words[11] === 32'h4c576000) begin
                if (words[0] !== 32'h4c575000 || words[4] !== 8 ||
                    words[5] !== MATCH || words[6] !== 32'h4d415000 ||
                    words[7] !== MATCH || words[8] !== MISS ||
                    words[9] !== 32 || words[10] !== 7 || words[12] !== MATCH ||
                    words[1] !== (force_early_match ? 32'd1 : 32'd32) ||
                    words[2] !== (force_early_match ? MATCH : MISS) ||
                    words[3] !== (force_early_match ? 32'h4d415000 : 32'h4c494000) ||
                    reads !== (force_early_match ? 9 : 40))
                    $fatal(1, "Unexpected output counts=%0d/%0d reasons=%h/%h reads=%0d",
                        words[1], words[4], words[3], words[6], reads);
                $display("PASS early_match_model=%b constant=%0d/%h/%h changed=%0d/%h/%h loads=%0d",
                    force_early_match, words[1], words[2], words[3],
                    words[4], words[5], words[6], reads);
                $finish;
            end
        end
        $fatal(1, "Timeout pc=%h done=%h", pc, words[11]);
    end
endmodule
