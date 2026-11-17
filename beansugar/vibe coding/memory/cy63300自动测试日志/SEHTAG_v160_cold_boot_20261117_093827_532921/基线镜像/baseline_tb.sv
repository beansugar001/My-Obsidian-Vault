`timescale 1ns/1ps
module baseline_tb;
    localparam [31:0] BASE = 32'h2000f000;
    reg clk = 0, rst = 0;
    always #5 clk = ~clk;
    reg [31:0] rom[0:127], memory[0:5];
    wire [31:0] pc, address, data;
    wire req, we;
    wire [31:0] instruction = pc < 512 ? rom[pc[8:2]] : 32'h00000013;
    wire [31:0] read_data = address == BASE + 20 ? memory[5] : 32'h0;
    integer writes = 0, reads = 0, i;

    tinyriscv dut (
        .clk(clk), .rst(rst), .rib_ex_req_o(req), .rib_ex_we_o(we),
        .rib_ex_addr_o(address), .rib_ex_data_o(data), .rib_ex_data_i(read_data),
        .rib_ex_tag_i(4'b0), .rib_pc_addr_o(pc), .rib_pc_data_i(instruction),
        .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0), .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );

    always @(posedge clk) if (rst) begin
        if (dut.safety_check_en !== 0 || dut.csr_we_o !== 0)
            $fatal(1, "Unexpected CSR transaction or safety enable");
        if (req) begin
            if (address < BASE || address > BASE + 20 || address[1:0] != 0)
                $fatal(1, "Unexpected address %h", address);
            if (we) begin
                memory[address[4:2]] <= data;
                writes <= writes + 1;
            end else begin
                if (address !== BASE + 20) $fatal(1, "Unexpected read address %h", address);
                reads <= reads + 1;
            end
        end
    end

    initial begin
        for (i = 0; i < 6; i = i + 1) memory[i] = 32'hdeadbeef;
        $readmemh("firmware.hex", rom);
        repeat (3) @(negedge clk);
        rst = 1;
        repeat (120) begin
            @(posedge clk); #1;
            if (memory[4] === 32'h5345fa11)
                $fatal(1, "Firmware reports baseline failure: word1=%h word2=%h", memory[1], memory[2]);
            if (memory[4] === 32'h5345600d) begin
                if (memory[0] !== 32'h53454231 || memory[1] !== 32'h13579bdf ||
                    memory[2] !== 32'h2468ace0 || writes !== 7 || reads !== 2)
                    $fatal(1, "Baseline acceptance mismatch: writes=%0d reads=%0d", writes, reads);
                $display("PASS mailbox=%h readbacks=%h/%h writes=%0d reads=%0d done=%h",
                    memory[0], memory[1], memory[2], writes, reads, memory[4]);
                $finish;
            end
        end
        $fatal(1, "Timeout: pc=%h", pc);
    end
endmodule
