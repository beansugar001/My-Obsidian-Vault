
`timescale 1ns/1ps
module top_decision_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 0;
    reg sampled = 0;
    wire req, we;
    wire [31:0] addr, data;
    reg [31:0] modeled_word = 32'h11223344;
    integer accepts = 0;

    tinyriscv dut (
        .clk(clk), .rst(rst), .rib_ex_addr_o(addr),
        .rib_ex_data_i(modeled_word), .rib_ex_data_o(data),
        .rib_ex_req_o(req), .rib_ex_we_o(we), .rib_ex_tag_i(4'b0),
        .rib_pc_data_i(32'h00000013), .jtag_reg_addr_i(5'b0),
        .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0),
        .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );

    always @(posedge clk) begin
        if (sampled && req && we) begin
            modeled_word <= data;
            accepts <= accepts + 1;
        end
    end

    initial begin
        $dumpfile("top_decision.vcd");
        $dumpvars(0, top_decision_tb);
        repeat (3) @(negedge clk);
        rst = 1;

        // Isolate top-level routing using a settled abstract protection decision.
        // The bundled checker and decode pipeline are outside this fixture's scope.
        force dut.safety_check_en = 1'b1;
        force dut.ie_is_security_inst = 1'b0;
        force dut.ie_reg1_tag_o = 1'b1;
        force dut.tcu_illegal_op = 1'b0;
        force dut.ie_op1_o = 32'h1000;
        force dut.ie_op2_o = 32'b0;
        force dut.ie_reg2_rdata_o = 32'h22334455;
        force dut.bnb_check_valid = 1'b1;
        force dut.ie_inst_o = 32'h0020a023;
        sampled = 1;
        @(posedge clk); #1;
        if ({req,we} !== 2'b11 || addr !== 32'h1000 ||
            accepts !== 1 || modeled_word !== 32'h22334455 ||
            dut.u_csr_reg.mcause !== 32'b0)
            $fatal(1,"allow: req/we=%b%b addr=%h accepts=%0d mem=%h mcause=%h",
                   req,we,addr,accepts,modeled_word,dut.u_csr_reg.mcause);
        $display("PASS settled allow reaches CPU bus and model accepts one write");

        @(negedge clk);
        force dut.ie_reg2_rdata_o = 32'h33445566;
        force dut.bnb_check_valid = 1'b0;
        repeat (2) begin
            @(posedge clk); #1;
            if ({req,we} !== 2'b00 || accepts !== 1 ||
                modeled_word !== 32'h22334455 || dut.u_csr_reg.mcause !== 32'h5)
                $fatal(1,"deny: req/we=%b%b accepts=%0d mem=%h mcause=%h",
                       req,we,accepts,modeled_word,dut.u_csr_reg.mcause);
        end
        $display("PASS settled deny suppresses CPU bus request and write; model unchanged; mcause=0x5");
        $finish;
    end
endmodule

