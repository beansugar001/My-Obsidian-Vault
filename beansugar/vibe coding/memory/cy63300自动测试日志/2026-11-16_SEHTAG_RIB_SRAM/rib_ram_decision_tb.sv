
`timescale 1ns/1ps
module rib_ram_decision_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 0;
    reg sampled = 0;
    wire req, we;
    wire [31:0] addr, data;
    wire [31:0] bus_read, ram_addr, ram_data, ram_read;
    wire [3:0] cpu_write_tag, cpu_read_tag, ram_write_tag, ram_read_tag;
    wire ram_we, ram_tag_we, cpu_tag_we, bus_hold;
    integer accepts = 0;

    tinyriscv dut (
        .clk(clk), .rst(rst), .rib_ex_addr_o(addr),
        .rib_ex_data_i(bus_read), .rib_ex_data_o(data),
        .rib_ex_req_o(req), .rib_ex_we_o(we), .rib_ex_tag_i(cpu_read_tag),
        .rib_ex_tag_o(cpu_write_tag), .rib_ex_tag_we_o(cpu_tag_we),
        .rib_pc_data_i(32'h00000013), .jtag_reg_addr_i(5'b0),
        .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(bus_hold), .jtag_halt_flag_i(1'b0),
        .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );

    rib bus (
        .clk(clk), .rst(rst),
        .m0_addr_i(addr), .m0_data_i(data), .m0_data_o(bus_read),
        .m0_req_i(req), .m0_we_i(we),
        .m0_tag_i(cpu_write_tag), .m0_tag_o(cpu_read_tag), .m0_tag_we_i(cpu_tag_we),
        .m1_addr_i(32'b0), .m1_data_i(32'b0), .m1_req_i(1'b0), .m1_we_i(1'b0),
        .m2_addr_i(32'b0), .m2_data_i(32'b0), .m2_req_i(1'b0), .m2_we_i(1'b0),
        .m3_addr_i(32'b0), .m3_data_i(32'b0), .m3_req_i(1'b0), .m3_we_i(1'b0),
        .s0_data_i(32'b0), .s2_data_i(32'b0), .s3_data_i(32'b0), .s4_data_i(32'b0),
        .s5_data_i(32'b0), .s6_data_i(32'b0),
        .s1_addr_o(ram_addr), .s1_data_o(ram_data), .s1_we_o(ram_we), .s1_data_i(ram_read),
        .s1_tag_o(ram_write_tag), .s1_tag_i(ram_read_tag), .s1_tag_we_o(ram_tag_we),
        .hold_flag_o(bus_hold)
    );

    ram memory (
        .clk(clk), .rst(rst), .we_i(ram_we), .addr_i(ram_addr),
        .data_i(ram_data), .data_o(ram_read),
        .tag_we_i(ram_tag_we), .tag_i(ram_write_tag), .tag_o(ram_read_tag)
    );

    always @(posedge clk) begin
        if (sampled && ram_we) accepts <= accepts + 1;
    end

    initial begin
        $dumpfile("rib_ram_decision.vcd");
        $dumpvars(0, rib_ram_decision_tb);
        repeat (3) @(negedge clk);
        rst = 1;

        // Isolate top-level routing using a settled abstract protection decision.
        // The bundled checker and decode pipeline are outside this fixture's scope.
        force dut.safety_check_en = 1'b1;
        force dut.ie_is_security_inst = 1'b0;
        force dut.ie_reg1_tag_o = 1'b1;
        force dut.tcu_illegal_op = 1'b0;
        force dut.ie_op1_o = 32'h10000000;
        force dut.ie_op2_o = 32'b0;
        force dut.ie_reg2_rdata_o = 32'h22334455;
        force dut.bnb_check_valid = 1'b1;
        force dut.ie_inst_o = 32'h0020a023;
        sampled = 1;
        @(posedge clk); #1;
        if ({req,we,ram_we} !== 3'b111 || addr !== 32'h10000000 ||
            accepts !== 1 || memory._ram[0] !== 32'h22334455 ||
            dut.u_csr_reg.mcause !== 32'b0)
            $fatal(1,"allow: req/we=%b%b addr=%h accepts=%0d mem=%h mcause=%h",
                   req,we,addr,accepts,memory._ram[0],dut.u_csr_reg.mcause);
        $display("PASS settled allow reaches SRAM through RIB and commits exactly one write");

        @(negedge clk);
        force dut.ie_reg2_rdata_o = 32'h33445566;
        force dut.bnb_check_valid = 1'b0;
        repeat (2) begin
            @(posedge clk); #1;
            if ({req,we,ram_we} !== 3'b000 || accepts !== 1 ||
                memory._ram[0] !== 32'h22334455 || dut.u_csr_reg.mcause !== 32'h5)
                $fatal(1,"deny: req/we=%b%b accepts=%0d mem=%h mcause=%h",
                       req,we,accepts,memory._ram[0],dut.u_csr_reg.mcause);
        end
        $display("PASS settled deny suppresses SRAM write enable; SRAM unchanged; mcause=0x5");
        $finish;
    end
endmodule

