
`timescale 1ns/1ps
`include "defines.v"
module ex_policy_tb;
    reg valid = 1;
    reg writing = 0;
    reg clk = 0;
    always #5 clk = ~clk;

    wire req, we, reg_we, csr_we, jump, check_en;
    wire [31:0] wdata, reg_data, csr_addr, csr_data, jump_addr;
    reg [31:0] model_word = 32'h12345678;
    reg capture_write = 0;
    always @(posedge clk)
        if (capture_write && req && we) model_word <= wdata;

    // Decode ordinary word load/store; model only the checker's decision.
    ex dut (
        .rst(1'b1), .inst_i(writing ? 32'h0020a023 : 32'h0000a183),
        .inst_addr_i(32'h100), .reg_we_i(!writing), .reg_waddr_i(5'd3),
        .reg1_rdata_i(32'h1000), .reg2_rdata_i(32'h87654321),
        .csr_we_i(1'b0), .csr_waddr_i(32'b0), .csr_rdata_i(32'b0),
        .int_assert_i(1'b0), .int_addr_i(32'b0),
        .op1_i(32'h1000), .op2_i(32'b0), .op1_jump_i(32'b0), .op2_jump_i(32'b0),
        .mem_rdata_i(model_word), .div_ready_i(1'b0), .div_result_i(32'b0),
        .div_busy_i(1'b0), .div_reg_waddr_i(5'b0),
        .mem_req_o(req), .mem_we_o(we), .mem_wdata_o(wdata),
        .reg_we_o(reg_we), .reg_wdata_o(reg_data),
        .csr_we_o(csr_we), .csr_waddr_o(csr_addr), .csr_wdata_o(csr_data),
        .csr_mtvec_i(32'h200), .safety_check_en_i(1'b1),
        .jump_flag_o(jump), .jump_addr_o(jump_addr), .reg1_tag_i(1'b1), .reg2_tag_i(1'b0),
        .bnb_check_valid_i(valid), .bnb_check_en_o(check_en), .seu_ready_i(1'b0),
        .seu_result_i(32'b0), .is_security_inst_i(1'b0), .tcu_result_i(model_word),
        .tcu_result_tag_i(1'b0), .tcu_illegal_op_i(1'b0), .reg1_sec_level_i(2'b0),
        .reg2_sec_level_i(2'b0), .reg1_trust_i(1'b0), .reg2_trust_i(1'b0),
        .tcu_result_sec_level_i(2'b0), .tcu_result_trust_i(1'b0)
    );

    task verify_denied;
        begin
            if ({req,we,reg_we,csr_we,jump,check_en} !== 6'b000111 ||
                csr_addr !== 32'h342 || csr_data !== 32'h5 || jump_addr !== 32'h200)
                $fatal(1,"Denied request: req=%b we=%b reg_we=%b csr=%h:%h jump=%h",
                       req,we,reg_we,csr_addr,csr_data,jump_addr);
        end
    endtask

    initial begin
        $dumpfile("ex_policy.vcd");
        $dumpvars(0,ex_policy_tb);
        #1;
        if ({req,we,reg_we,csr_we,check_en} !== 5'b10101 || reg_data !== 32'h12345678)
            $fatal(1,"Valid load failed");
        $display("PASS valid load");

        valid = 0;
        #1;
        verify_denied;
        $display("PASS rejected read disables request/register write and reports cause 0x5");

        writing = 1;
        capture_write = 1;
        #1;
        verify_denied;
        @(posedge clk); #1;
        if (model_word !== 32'h12345678) $fatal(1,"Rejected store changed model word");
        $display("PASS rejected write suppresses request/write enable; model word unchanged");

        @(negedge clk);
        valid = 1;
        #1;
        if ({req,we,reg_we,csr_we,check_en} !== 5'b11001) $fatal(1,"Valid store signals");
        @(posedge clk); #1;
        if (model_word !== 32'h87654321) $fatal(1,"Accepted store did not update model");
        $display("PASS valid store updates model word");
        $finish;
    end
endmodule

