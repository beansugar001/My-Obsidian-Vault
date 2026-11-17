`timescale 1ns/1ps
module security_alloc_integration_tb;
    localparam [31:0] HEAP_BASE = 32'h20000000;
    localparam [31:0] DATA = 32'h1234abcd;
    // Same instruction fields used for the standalone handler in the repo fixture.
    localparam [31:0] ALLOC_WORD = {7'h0, 5'h0, 5'h0, 3'b001, 5'h1, 7'b0001011};
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg issue = 0;
    reg query = 0;
    reg [31:0] address = 0;
    reg write_enable = 0;
    wire [31:0] result, readback;
    wire [3:0] result_tag;
    wire valid, exception, freed;
    wire [3:0] exception_code;
    wire [15:0] generation;

    mcu_security_system security (
        .clk(clk), .rst_n(rst_n), .instruction_i(ALLOC_WORD),
        .instruction_valid_i(issue), .rs1_data_i(32'd32), .rs2_data_i(32'd1),
        .rs1_tag_i(4'd0), .rs2_tag_i(4'd0), .stack_ptr_i(32'd0),
        .result_o(result), .result_tag_o(result_tag), .result_valid_o(valid),
        .exception_o(exception), .exception_code_o(exception_code),
        .ptr_freed_o(freed), .ptr_gen_o(generation),
        .ptr_query_addr_i(address), .ptr_query_en_i(query)
    );

    // Scratch RAM represents the advertised heap range in this fixture only.
    ram scratch (
        .clk(clk), .rst(rst_n), .we_i(write_enable),
        .addr_i(address - HEAP_BASE), .data_i(DATA), .data_o(readback),
        .tag_we_i(1'b0), .tag_i(4'b0)
    );

    initial begin
        $dumpfile("security_alloc_integration.vcd");
        $dumpvars(1, security_alloc_integration_tb);
        $dumpvars(1, security.inst_handler);
        $dumpvars(1, security.mem_security);
        repeat (3) @(negedge clk);
        rst_n = 1;
        // The HAT reset FSM clears the entries before accepting commands.
        repeat (280) @(negedge clk);
        issue = 1;
        @(negedge clk); issue = 0;
        begin : await_alloc
            repeat (300) begin
                @(posedge clk); #1;
                if (exception === 1'b1)
                    $fatal(1, "Legal allocation: exception=%h", exception_code);
                if (valid === 1'b1) disable await_alloc;
            end
            $fatal(1, "Legal allocation timed out");
        end
        if (result !== HEAP_BASE || result_tag !== 4'h1 || exception !== 1'b0)
            $fatal(1, "Allocation result=%h tag=%h exception=%b", result, result_tag, exception);
        $display("PASS handler -> HAT -> response: addr=%h tag=%h", result, result_tag);

        @(negedge clk);
        address = result;
        query = 1;
        #1;
        if (freed !== 1'b0 || (^generation) === 1'bx || generation == 0)
            $fatal(1, "Registered object metadata: freed=%b generation=%h", freed, generation);
        $display("PASS live object metadata: freed=%b generation=%h", freed, generation);

        write_enable = 1;
        @(negedge clk); write_enable = 0;
        #1;
        if (readback !== DATA) $fatal(1, "Scratch word=%h", readback);
        $display("PASS testbench in-object access: addr=%h word=%h", address, readback);
        $finish;
    end
endmodule
