`timescale 1ns/1ps
module native_legal_tb;
    reg clk=0, rst=0;
    always #5 clk=~clk;
    reg [31:0] rom[0:511];
    wire [31:0] pc, addr, data;
    wire req, we;
    wire [31:0] inst = pc < 2048 ? rom[pc[10:2]] : 32'h00000013;
    reg [31:0] scratch = 32'h0;
    integer stores=0, reads=0, allocs=0, writebacks=0;

    tinyriscv dut (
        .clk(clk), .rst(rst), .rib_ex_req_o(req), .rib_ex_we_o(we),
        .rib_ex_addr_o(addr), .rib_ex_data_i(scratch), .rib_ex_data_o(data),
        .rib_ex_tag_i(4'b0), .rib_pc_addr_o(pc), .rib_pc_data_i(inst),
        .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0), .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );

    always @(posedge clk) if (rst) begin
        if (dut.alloc_start) allocs <= allocs+1;
        if (dut.alloc_return) writebacks <= writebacks+1;
        if (req) begin
            if (addr !== 32'h20000000 ||
                {dut.safety_check_en, dut.bnb_check_en,
                 dut.bnb_index_valid, dut.bnb_check_valid} !== 4'b1111)
                $fatal(1,"Unexpected request or metadata decision at addr=%h",addr);
            if (we) begin
                stores <= stores+1;
                scratch <= data;
            end else reads <= reads+1;
        end
    end

    initial begin
        $readmemh("firmware.hex",rom);
        $dumpfile("native_legal.vcd");
        $dumpvars(1,native_legal_tb);
        $dumpvars(1,dut);
        repeat (3) @(negedge clk);
        rst=1;
        repeat (800) begin
            @(posedge clk); #1;
            if (dut.hat_error === 1'b1) $fatal(1,"HAT error %h",dut.hat_error_type);
            if (dut.u_csr_reg.mcause !== 0) $fatal(1,"Trap cause %h",dut.u_csr_reg.mcause);
            if (dut.u_regs.regs[26] === 32'h3f) $fatal(1,"CPU readback mismatch");
            if (dut.u_regs.regs[26] === 32'h60) begin
                if (allocs !== 1 || writebacks !== 1 || stores !== 1 || reads !== 1 ||
                    scratch !== 32'h1234abcd || dut.u_regs.regs[19] !== 32'h1234abcd ||
                    dut.u_regs.regs[10] !== 32'h20000000 || dut.u_regs.ext_tags[10] !== 4'h8 ||
                    dut.u_bnbcache.bnb_lookup_base[0] !== 32'h20000000 ||
                    dut.u_bnbcache.bnb_lookup_bound[0] !== 32'h2000001f)
                    $fatal(1,"Counts or data mismatch allocs=%0d wb=%0d wr=%0d rd=%0d",allocs,writebacks,stores,reads);
                $display("PASS CPU boot -> allocation -> pointer writeback -> one checked-path store/load; value=%h",scratch);
                $finish;
            end
        end
        $fatal(1,"Timeout pc=%h alloc_state=%0d allocs=%0d wr=%0d rd=%0d",pc,dut.alloc_state,allocs,stores,reads);
    end
endmodule
