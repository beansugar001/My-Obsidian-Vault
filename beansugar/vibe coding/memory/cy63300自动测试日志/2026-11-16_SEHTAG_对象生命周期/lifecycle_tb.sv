
`timescale 1ns/1ps
module lifecycle_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 0;
    reg index_write = 0;
    reg metadata_write = 0;
    reg write_bound = 0;
    reg retire = 0;
    reg check_enable = 0;
    reg [15:0] request_generation = 0;
    wire decision, active, freed;
    wire [15:0] generation;
    wire [31:0] base, bound;

    // Exercise the cache's documented ports with synthetic metadata only.
    bnbcache dut (
        .clk(clk), .rst(rst), .index_addr_i(5'd1),
        .index_we_i(index_write), .index_value_i(3'd2), .index_addr_we_i(5'd1),
        .lookup_addr_i(3'd2), .lookup_base_o(base), .lookup_bound_o(bound),
        .lookup_we_i(metadata_write), .lookup_addr_we_i(3'd2),
        .lookup_base_i(32'h100), .lookup_bound_i(32'h11f),
        .lookup_ptr_id_i(32'd7), .bnb_lookup_wt(write_bound),
        .stack_push_i(1'b0), .stack_pop_i(1'b0), .stack_ptr_id_i(32'd0),
        .check_addr_i(32'h110), .check_en_i(check_enable), .check_valid_o(decision),
        .exec_index_addr_i(5'd1), .alloc_req_i(1'b0), .alloc_ptr_id_i(32'd0),
        .ptr_freed_i(retire), .ptr_gen_i(request_generation), .ptr_query_en_i(retire),
        .ptr_valid_o(active), .ptr_freed_o(freed), .ptr_gen_o(generation)
    );

    task register_object(input logic [15:0] expected_generation);
        begin
            @(negedge clk);
            metadata_write = 1;
            write_bound = 0;
            @(negedge clk);
            write_bound = 1;
            @(negedge clk);
            metadata_write = 0;
            #1;
            if ({active, freed} !== 2'b10 || generation !== expected_generation ||
                base !== 32'h100 || bound !== 32'h11f)
                $fatal(1, "registration state=%b%b gen=%h base=%h bound=%h",
                       active, freed, generation, base, bound);
        end
    endtask

    task assert_decision(input logic [15:0] gen, input logic allow, input string label_text);
        begin
            @(negedge clk);
            request_generation = gen;
            check_enable = 1;
            @(posedge clk); #1;
            if (decision !== allow)
                $fatal(1, "%s decision=%b expected=%b", label_text, decision, allow);
            $display("PASS %s active=%b freed=%b object_gen=%0d request_gen=%0d decision=%b",
                     label_text, active, freed, generation, gen, decision);
            @(negedge clk);
            check_enable = 0;
        end
    endtask

    initial begin
        $dumpfile("lifecycle.vcd");
        $dumpvars(0, lifecycle_tb);
        repeat (3) @(negedge clk);
        rst = 1;
        index_write = 1;
        @(negedge clk);
        index_write = 0;

        register_object(16'd1);
        assert_decision(16'd1, 1, "registered object accepted");

        @(negedge clk);
        retire = 1;
        @(negedge clk);
        retire = 0;
        #1;
        if ({active, freed} !== 2'b01 || generation !== 16'd1)
            $fatal(1, "retired state=%b%b gen=%h", active, freed, generation);
        assert_decision(16'd1, 0, "retired object rejected");

        register_object(16'd2);
        assert_decision(16'd1, 0, "previous generation rejected after registration");
        assert_decision(16'd2, 1, "current generation accepted after registration");
        $finish;
    end
endmodule

