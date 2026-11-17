`timescale 1ns/1ps
module guarded_cpu_tb;
    reg clk=0, rst=0;
    always #5 clk=~clk;
    reg [31:0] rom[0:511];
    wire [31:0] pc, addr, write_data, read_data;
    wire req, we;
    wire [31:0] inst = pc < 2048 ? rom[pc[10:2]] : 32'h00000013;
    integer accepted=0, requests=0, checked_wait=0, downstream_wait=0, reads=0;
    reg monitor_stall=0;
    reg [31:0] held_pc;
    wire downstream_ready = downstream_wait == 3;

    tinyriscv dut (
        .clk(clk), .rst(rst), .sim_store_ready(downstream_ready),
        .rib_ex_req_o(req), .rib_ex_we_o(we),
        .rib_ex_addr_o(addr), .rib_ex_data_i(read_data), .rib_ex_data_o(write_data),
        .rib_ex_tag_i(4'b0), .rib_pc_addr_o(pc), .rib_pc_data_i(inst),
        .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0), .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );
    ram scratch (
        .clk(clk), .rst(rst), .we_i(we), .addr_i(addr - 32'h20000000),
        .data_i(write_data), .data_o(read_data), .tag_we_i(1'b0), .tag_i(4'b0)
    );

    always @(posedge clk) if (rst) begin
        if (dut.store_begin) begin
            requests <= requests+1;
            held_pc <= pc;
            monitor_stall <= 1;
            if ({req,we} !== 0 || scratch._ram[0] !== 32'h55667788)
                $fatal(1,"SRAM changed during request capture");
        end
        if (monitor_stall && !dut.store_done && pc !== held_pc)
            $fatal(1,"pipeline advanced during protected store");
        if (dut.store_waiting && !dut.store_commit_valid) begin
            checked_wait <= checked_wait+1;
            if ({req,we} !== 0 || scratch._ram[0] !== 32'h55667788)
                $fatal(1,"SRAM changed before decision");
        end
        if (dut.store_commit_valid && !downstream_ready) begin
            downstream_wait <= downstream_wait+1;
            if ({req,we} !== 0 || scratch._ram[0] !== 32'h55667788)
                $fatal(1,"SRAM changed under backpressure");
        end
        if (we) begin
            if (!req || !dut.store_done || !dut.store_allow ||
                addr !== 32'h20000000 || write_data !== 32'h1234abcd)
                $fatal(1,"Unexpected SRAM write");
            accepted <= accepted+1;
            monitor_stall <= 0;
        end else if (req) begin
            if (addr !== 32'h20000000) $fatal(1,"Unexpected read address");
            reads <= reads+1;
        end
    end

    initial begin
        $readmemh("firmware.hex",rom);
        scratch._ram[0] = 32'h55667788;
        $dumpfile("cpu_wait.vcd");
        $dumpvars(1,guarded_cpu_tb);
        $dumpvars(1,dut);
        repeat (3) @(negedge clk);
        rst=1;
        repeat (800) begin
            @(posedge clk); #1;
            if (dut.store_reject || dut.hat_error || dut.u_csr_reg.mcause !== 0)
                $fatal(1,"Legal test produced a rejection or trap");
            if (dut.u_regs.regs[26] === 32'h3f) $fatal(1,"CPU readback mismatch");
            if (dut.u_regs.regs[26] === 32'h60) begin
                if (requests !== 1 || accepted !== 1 || reads !== 1 ||
                    checked_wait !== 3 || downstream_wait !== 3 ||
                    scratch._ram[0] !== 32'h1234abcd || dut.u_regs.regs[19] !== 32'h1234abcd)
                    $fatal(1,"Mismatch requests=%0d writes=%0d reads=%0d check=%0d ready=%0d",
                        requests,accepted,reads,checked_wait,downstream_wait);
                $display("PASS check_wait=%0d downstream_wait=%0d commits=%0d reads=%0d RAM=%h mcause=%h",
                    checked_wait,downstream_wait,accepted,reads,scratch._ram[0],dut.u_csr_reg.mcause);
                $finish;
            end
        end
        $fatal(1,"Timeout pc=%h",pc);
    end
endmodule
