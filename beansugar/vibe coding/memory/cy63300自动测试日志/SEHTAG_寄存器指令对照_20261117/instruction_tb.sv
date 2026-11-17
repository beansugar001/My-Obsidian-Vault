`timescale 1ns/1ps
module instruction_tb;
    localparam [31:0] BASE = 32'h2000f000;
    reg clk = 0, rst = 0;
    always #5 clk = ~clk;
    reg [31:0] rom[0:127], words[0:9];
    wire [31:0] pc, address, data;
    wire req, we;
    wire [31:0] instruction = pc < 512 ? rom[pc[8:2]] : 32'h00000013;
    integer i, writes = 0;
    reg duplicate_add;
    reg [31:0] expected_matched;
    tinyriscv dut (
        .clk(clk), .rst(rst), .rib_ex_req_o(req), .rib_ex_we_o(we),
        .rib_ex_addr_o(address), .rib_ex_data_o(data), .rib_ex_data_i(32'b0),
        .rib_ex_tag_i(4'b0), .rib_pc_addr_o(pc), .rib_pc_data_i(instruction),
        .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0), .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );

    always @(posedge clk) if (rst) begin
        if (dut.csr_we_o !== 0 || dut.safety_check_en !== 0)
            $fatal(1, "Unexpected CSR operation");
        if (req) begin
            if (we !== 1 || address < BASE || address > BASE + 36 || address[1:0] != 0)
                $fatal(1, "Unexpected data bus access addr=%h write=%b", address, we);
            words[address[5:2]] <= data;
            writes <= writes + 1;
        end
    end

    initial begin
        for (i = 0; i < 10; i = i + 1) words[i] = 32'hdeadbeef;
        $readmemh("firmware.hex", rom);
        if (rom['h94/4] !== 32'h57416337 || rom['h98/4] !== 32'h00d30313 ||
            rom['h9c/4] !== 32'h00000013)
            $fatal(1, "Matched instructions did not land at 0x94, 0x98, 0x9c");
        duplicate_add = $test$plusargs("duplicate_add");
        if (duplicate_add) rom['h9c/4] = rom['h98/4];
        expected_matched = duplicate_add ? 32'h5741601a : 32'h5741600d;
        repeat (3) @(negedge clk);
        rst = 1;
        repeat (130) begin
            @(negedge clk);
            if (words[9] === 32'h53457000) begin
                if (words[0] !== 32'h57416000 || words[1] !== 32'h5741600d ||
                    words[2] !== 32'h57416000 || words[3] !== 32'h57416000 ||
                    words[4] !== 32'h5741601d || words[5] !== 32'h11111000 ||
                    words[6] !== 32'h22222000 || words[7] !== expected_matched ||
                    words[8] !== 32'h2d5a7000 || writes !== 11)
                    $fatal(1, "Unexpected output: matched=%h writes=%0d", words[7], writes);
                repeat (20) @(negedge clk);
                if (writes !== 11) $fatal(1, "Unexpected additional stores");
                $display("PASS duplicate_model=%b independent=%h spaced_inplace=%h equal_case=%h unequal_case=%h matched=%h fixed=%h",
                    duplicate_add, words[1], words[4], words[5], words[6], words[7], words[8]);
                $finish;
            end
        end
        $fatal(1, "Timeout pc=%h stage=%h", pc, words[9]);
    end
endmodule
