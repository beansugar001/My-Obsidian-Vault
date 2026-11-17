`timescale 1ns/1ps
module guard_trap_tb;
    reg clk=0, rst=0;
    always #5 clk=~clk;
    reg deny;
    reg [31:0] rom[0:511];
    wire [31:0] pc, addr, write_data, read_data;
    wire req, we;
    wire [31:0] inst = pc < 2048 ? rom[pc[10:2]] : 32'h00000013;
    wire [31:0] marker = dut.u_regs.regs[26];
    wire [31:0] cause = dut.u_csr_reg.mcause;
    integer requests=0, writes=0, reads=0, rejects=0;
    reg saw_handler=0;

    tinyriscv dut (
        .clk(clk), .rst(rst), .sim_store_ready(1'b1), .sim_deny_store(deny),
        .rib_ex_req_o(req), .rib_ex_we_o(we), .rib_ex_addr_o(addr),
        .rib_ex_data_i(read_data), .rib_ex_data_o(write_data),
        .rib_ex_tag_i(4'b0), .rib_pc_addr_o(pc), .rib_pc_data_i(inst),
        .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0), .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );
    ram scratch (
        .clk(clk), .rst(rst), .we_i(we), .addr_i(addr-32'h20000000),
        .data_i(write_data), .data_o(read_data), .tag_we_i(1'b0), .tag_i(4'b0)
    );

    always @(posedge clk) if (rst) begin
        if (dut.store_begin) requests <= requests+1;
        if (dut.store_reject) rejects <= rejects+1;
        if (pc == 32'h600) saw_handler <= 1;
        if (deny && (req || we)) $fatal(1,"Denied test issued a data request");
        if (we) writes <= writes+1;
        else if (req) reads <= reads+1;
    end

    initial begin
        deny=$test$plusargs("deny");
        $readmemh("firmware.hex",rom);
        scratch._ram[0]=32'h55667788;
        $dumpfile(deny ? "deny.vcd" : "allow.vcd");
        $dumpvars(1,guard_trap_tb);
        $dumpvars(1,dut);
        repeat(3) @(negedge clk);
        rst=1;
        repeat(800) begin
            @(posedge clk); #1;
            if (dut.hat_error || marker === 32'h3f) $fatal(1,"Unexpected failure");
            if (marker === 32'h60 || marker === 32'h61) begin
                if (requests !== 1) $fatal(1,"Expected one store request");
                if (deny) begin
                    if (marker !== 32'h61 || !saw_handler || cause !== 32'h5 ||
                        dut.u_regs.regs[18] !== 32'h5 || rejects !== 1 ||
                        writes !== 0 || reads !== 0 || scratch._ram[0] !== 32'h55667788)
                        $fatal(1,"Rejection mismatch marker=%h cause=%h writes=%0d",marker,cause,writes);
                    $display("PASS deny: writes=%0d reads=%0d rejects=%0d RAM=%h cause=%h handler=0x600",
                        writes,reads,rejects,scratch._ram[0],cause);
                end else begin
                    if (marker !== 32'h60 || saw_handler || cause !== 0 || rejects !== 0 ||
                        writes !== 1 || reads !== 1 || scratch._ram[0] !== 32'h1234abcd)
                        $fatal(1,"Allowed control mismatch");
                    $display("PASS allow: writes=%0d reads=%0d RAM=%h cause=%h",writes,reads,scratch._ram[0],cause);
                end
                $finish;
            end
        end
        $fatal(1,"Timeout: pc=%h cause=%h marker=%h",pc,cause,marker);
    end
endmodule
