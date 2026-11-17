
`timescale 1ns/1ps
`include "defines.v"
module csr_enable_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = `RstEnable;
    reg write_enable = 0;
    wire enabled;
    wire [31:0] value;

    csr_reg dut (
        .clk(clk), .rst(rst), .we_i(write_enable),
        .raddr_i({20'h0, `CSR_SAFETY_CTRL}),
        .waddr_i({20'h0, `CSR_SAFETY_CTRL}), .data_i(32'h1),
        .clint_we_i(1'b0), .clint_raddr_i(32'b0), .clint_waddr_i(32'b0),
        .clint_data_i(32'b0), .alloc_new_ptr_i(1'b0), .data_o(value), .safety_check_en_o(enabled)
    );

    initial begin
        $dumpfile("csr_enable.vcd");
        $dumpvars(0, csr_enable_tb);
        @(posedge clk); #1;
        if ({value, enabled} !== 33'b0) $fatal(1, "Reset state");
        $display("PASS reset: CSR=0x%08h enable=%b", value, enabled);
        @(negedge clk); rst = `RstDisable; write_enable = 1;
        @(posedge clk); #1;
        @(negedge clk); write_enable = 0;
        @(posedge clk); #1;
        if (value !== 32'h1 || enabled !== 1'b1) $fatal(1, "Enable state");
        $display("PASS enabled: CSR=0x%08h enable=%b", value, enabled);
        $finish;
    end
endmodule

