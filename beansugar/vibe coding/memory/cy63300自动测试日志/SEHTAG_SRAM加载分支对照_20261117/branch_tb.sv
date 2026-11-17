`timescale 1ns/1ps
module branch_tb;
    localparam [31:0] BASE = 32'h2000f000;
    reg clk = 0, rst = 0;
    always #5 clk = ~clk;
    reg [31:0] rom[0:127], words[0:12];
    wire [31:0] pc, address, data;
    wire req, we;
    wire [31:0] instruction = pc < 512 ? rom[pc[8:2]] : 32'h00000013;
    integer i, writes = 0, reads = 0;
    reg alter_short_load;
    wire [31:0] read_value = address == BASE + 48
        ? ((alter_short_load && reads == 0) ? 32'h53454000 : words[12])
        : 32'h0;
    tinyriscv dut (
        .clk(clk), .rst(rst), .rib_ex_req_o(req), .rib_ex_we_o(we),
        .rib_ex_addr_o(address), .rib_ex_data_o(data), .rib_ex_data_i(read_value),
        .rib_ex_tag_i(4'b0), .rib_pc_addr_o(pc), .rib_pc_data_i(instruction),
        .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0), .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );

    always @(posedge clk) if (rst) begin
        if (dut.csr_we_o !== 0 || dut.safety_check_en !== 0)
            $fatal(1, "Unexpected CSR activity");
        if (req) begin
            if (address < BASE || address > BASE + 48 || address[1:0] != 0)
                $fatal(1, "Unexpected data address %h", address);
            if (we) begin
                words[address[5:2]] <= data;
                writes <= writes + 1;
            end else begin
                if (address != BASE + 48) $fatal(1, "Unexpected load address");
                reads <= reads + 1;
            end
        end
    end

    initial begin
        alter_short_load = $test$plusargs("alter_short_load");
        for (i = 0; i < 13; i = i + 1) words[i] = 32'hdeadbeef;
        $readmemh("firmware.hex", rom);
        if (rom['hd0/4] !== rom['hf4/4] || rom['hd0/4][6:0] !== 7'h03 ||
            rom['h100/4][14:12] !== 3'h1 || rom['h100/4][6:0] !== 7'h63)
            $fatal(1, "Expected LW sites and shared BNE");
        repeat (3) @(negedge clk);
        rst = 1;
        repeat (180) begin
            @(negedge clk);
            if (words[9] === 32'h4c426000) begin
                if (words[0] !== 32'h4c425000 || words[1] !== 32'h13579000 ||
                    words[2] !== 32'h54414000 || words[5] !== 32'h13579000 ||
                    words[6] !== 32'h54414000 || words[7] !== 32'h53454000 ||
                    words[8] !== 32'h13579000 || words[12] !== 32'h13579000 ||
                    words[3] !== (alter_short_load ? 32'h53454000 : 32'h13579000) ||
                    words[4] !== (alter_short_load ? 32'h4e4f0000 : 32'h54414000) ||
                    reads !== 2 || writes !== 12)
                    $fatal(1, "Unexpected output short=%h/%h reads=%0d writes=%0d",
                        words[3], words[4], reads, writes);
                repeat (20) @(negedge clk);
                if (reads !== 2 || writes !== 12) $fatal(1, "Unexpected additional data requests");
                $display("PASS model_alters_short_load=%b reg=%h/%h short=%h/%h paced=%h/%h",
                    alter_short_load, words[1], words[2], words[3], words[4], words[5], words[6]);
                $finish;
            end
        end
        $fatal(1, "Timeout pc=%h done=%h", pc, words[9]);
    end
endmodule
