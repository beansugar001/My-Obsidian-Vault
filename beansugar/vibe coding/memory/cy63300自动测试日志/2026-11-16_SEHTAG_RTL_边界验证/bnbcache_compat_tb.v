`timescale 1ns/1ps
`include "defines.v"

module bnbcache_compat_tb;
    reg lookup_write_bound = 0;


    reg clk;
    reg rst;


    reg [4:0] index_addr_i;
    reg index_we_i;
    reg [2:0] index_value_i;
    reg [4:0] index_addr_we_i;
    wire [2:0] index_value_o;
    wire index_valid_o;


    reg [2:0] lookup_addr_i;
    reg lookup_we_i;
    reg [2:0] lookup_addr_we_i;
    reg [`RegBus] lookup_base_i;
    reg [`RegBus] lookup_bound_i;
    reg [`RegBus] lookup_ptr_id_i;
    wire [`RegBus] lookup_base_o;
    wire [`RegBus] lookup_bound_o;
    wire [`RegBus] lookup_ptr_id_o;
    wire lookup_valid_o;


    reg stack_push_i;
    reg stack_pop_i;
    reg [`RegBus] stack_ptr_id_i;
    wire [`RegBus] stack_ptr_id_o;


    reg [`RegBus] check_addr_i;
    reg check_en_i;
    wire check_valid_o;


    bnbcache uut (
        .clk(clk),
        .rst(rst),

        .index_addr_i(index_addr_i),
        .index_value_o(index_value_o),
        .index_valid_o(index_valid_o),
        .index_we_i(index_we_i),
        .index_value_i(index_value_i),
        .index_addr_we_i(index_addr_we_i),

        .lookup_addr_i(lookup_addr_i),
        .lookup_base_o(lookup_base_o),
        .lookup_bound_o(lookup_bound_o),
        .lookup_ptr_id_o(lookup_ptr_id_o),
        .lookup_valid_o(lookup_valid_o),
        .lookup_we_i(lookup_we_i),
        .lookup_addr_we_i(lookup_addr_we_i),
        .lookup_base_i(lookup_base_i),
        .lookup_bound_i(lookup_bound_i),
        .lookup_ptr_id_i(lookup_ptr_id_i),
        .bnb_lookup_wt(lookup_write_bound),
        .exec_index_addr_i(5'd0),
        .alloc_req_i(1'b0),
        .alloc_ptr_id_i(32'd0),
        .ptr_freed_i(1'b0),
        .ptr_gen_i(16'd0),
        .ptr_query_en_i(1'b0),

        .stack_push_i(stack_push_i),
        .stack_pop_i(stack_pop_i),
        .stack_ptr_id_i(stack_ptr_id_i),
        .stack_ptr_id_o(stack_ptr_id_o),

        .check_addr_i(check_addr_i),
        .check_en_i(check_en_i),
        .check_valid_o(check_valid_o)
    );


    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    initial begin

        rst = `RstEnable;
        index_addr_i = 0;
        index_we_i = `WriteDisable;
        index_value_i = 0;
        index_addr_we_i = 0;
        lookup_addr_i = 0;
        lookup_we_i = `WriteDisable;
        lookup_addr_we_i = 0;
        lookup_base_i = 0;
        lookup_bound_i = 0;
        lookup_ptr_id_i = 0;
        stack_push_i = `False;
        stack_pop_i = `False;
        stack_ptr_id_i = 0;
        check_addr_i = 0;
        check_en_i = `False;


        #20;
        rst = `RstDisable;
        #10;


        $display("Test 1: Write to BnBIndex table");
        index_we_i = `WriteEnable;
        index_addr_we_i = 5'd1;
        index_value_i = 3'd2;
        #10;
        index_we_i = `WriteDisable;


        $display("Test 2: Read from BnBIndex table");
        index_addr_i = 5'd1;
        #10;
        if (index_value_o == 3'd2 && index_valid_o == `True) begin
            $display("  PASS: Index table read correct value");
        end else begin
            $display("  FAIL: Index table read incorrect value. Got: value=%d, valid=%d", index_value_o, index_valid_o);
        end


        $display("Test 3: Write to BnBLookUp table");
        lookup_we_i = `WriteEnable;
        lookup_addr_we_i = 3'd2;
        lookup_base_i = 32'h1000_0000;
        lookup_bound_i = 32'h1000_00FF;
        lookup_ptr_id_i = 32'd123;
        #10;
        lookup_write_bound = 1;
        #10;
        lookup_we_i = `WriteDisable;


        $display("Test 4: Read from BnBLookUp table");
        lookup_addr_i = 3'd2;
        #10;
        if (lookup_base_o == 32'h1000_0000 && lookup_bound_o == 32'h1000_00FF &&
            lookup_ptr_id_o == 32'd123 && lookup_valid_o == `True) begin
            $display("  PASS: Lookup table read correct values");
        end else begin
            $display("  FAIL: Lookup table read incorrect values. Got: base=%h, bound=%h, ptr_id=%d, valid=%d",
                     lookup_base_o, lookup_bound_o, lookup_ptr_id_o, lookup_valid_o);
        end


        $display("Test 5: Valid memory access check");
        check_en_i = `True;
        index_addr_i = 5'd1;
        check_addr_i = 32'h1000_0080;
        #10;
        if (check_valid_o == `True) begin
            $display("  PASS: Valid address check passed");
        end else begin
            $display("  FAIL: Valid address check failed");
        end


        $display("Test 6: Invalid memory access check (below base)");
        check_addr_i = 32'h0FFF_FFFF;
        #10;
        if (check_valid_o == `False) begin
            $display("  PASS: Invalid address check (below base) passed");
        end else begin
            $display("  FAIL: Invalid address check (below base) failed");
        end


        $display("Test 7: Invalid memory access check (above bound)");
        check_addr_i = 32'h1000_0100;
        #10;
        if (check_valid_o == `False) begin
            $display("  PASS: Invalid address check (above bound) passed");
        end else begin
            $display("  FAIL: Invalid address check (above bound) failed");
        end


        $display("Test 8: Push to BnBStack");
        stack_push_i = `True;
        stack_ptr_id_i = 32'd456;
        #10;
        stack_push_i = `False;
        #10;
        if (stack_ptr_id_o == 32'd456) begin
            $display("  PASS: Stack push succeeded");
        end else begin
            $display("  FAIL: Stack push failed. Got: ptr_id=%d", stack_ptr_id_o);
        end


        $display("Test 9: Push another value to BnBStack");
        stack_push_i = `True;
        stack_ptr_id_i = 32'd789;
        #10;
        stack_push_i = `False;
        #10;
        if (stack_ptr_id_o == 32'd789) begin
            $display("  PASS: Second stack push succeeded");
        end else begin
            $display("  FAIL: Second stack push failed. Got: ptr_id=%d", stack_ptr_id_o);
        end


        $display("Test 10: Pop from BnBStack");
        stack_pop_i = `True;
        #10;
        stack_pop_i = `False;
        #10;
        if (stack_ptr_id_o == 32'd456) begin
            $display("  PASS: Stack pop succeeded");
        end else begin
            $display("  FAIL: Stack pop failed. Got: ptr_id=%d", stack_ptr_id_o);
        end


        $display("Test 11: Reading from ZeroReg");
        index_addr_i = `ZeroReg;
        #10;
        if (index_valid_o == `False) begin
            $display("  PASS: ZeroReg always returns invalid");
        end else begin
            $display("  FAIL: ZeroReg should return invalid");
        end


        $display("Test 12: Reading from invalid lookup entry");
        lookup_addr_i = 3'd1;
        #10;
        if (lookup_valid_o == `False) begin
            $display("  PASS: Invalid lookup entry returns invalid");
        end else begin
            $display("  FAIL: Invalid lookup entry should return invalid");
        end


        $display("Test 13: Stack underflow check");

        stack_pop_i = `True;
        #10;
        stack_pop_i = `False;
        #10;

        stack_pop_i = `True;
        #10;
        stack_pop_i = `False;
        #10;
        if (stack_ptr_id_o == `ZeroWord) begin
            $display("  PASS: Stack underflow handled correctly");
        end else begin
            $display("  FAIL: Stack underflow not handled correctly. Got: ptr_id=%d", stack_ptr_id_o);
        end

        $display("All tests completed");
        #100;
        $finish;
    end


    initial begin
        $dumpfile("bnbcache_compat.vcd");
        $dumpvars(0, bnbcache_compat_tb);
    end

endmodule
