`timescale 1ns/1ps
module checked_commit_tb;
    reg clk=0, rst_n=0;
    always #5 clk=~clk;
    reg request_valid=0, decision_valid=0, decision_allow=0, commit_ready=1;
    reg [7:0] request_id=0, decision_id=0;
    reg [31:0] request_data=0;
    wire request_ready, commit_valid, reject;
    wire [31:0] commit_data;
    integer commits=0, rejects=0;
    reg [31:0] scratch=32'h12345678;
    checked_commit dut (.*);

    always @(posedge clk) if (rst_n) begin
        if (commit_valid && commit_ready) begin
            commits <= commits+1;
            scratch <= commit_data;
        end
        if (reject) rejects <= rejects+1;
    end

    task request(input [7:0] id, input [31:0] data);
        begin
            @(negedge clk);
            if (request_ready !== 1) $fatal(1,"request slot unavailable");
            request_id=id; request_data=data; request_valid=1;
            @(negedge clk); request_valid=0;
        end
    endtask

    task decision(input [7:0] id, input allow);
        begin
            @(negedge clk);
            decision_id=id; decision_allow=allow; decision_valid=1;
            @(negedge clk); decision_valid=0;
        end
    endtask

    task wait_no_commit(input integer cycles, input integer expected);
        begin
            repeat(cycles) begin
                @(posedge clk); #1;
                if (commit_valid !== 0 || commits !== expected)
                    $fatal(1,"commit before a matching allow");
            end
        end
    endtask

    initial begin
        $dumpfile("commit.vcd");
        $dumpvars(0,checked_commit_tb);
        repeat(3) @(negedge clk);
        rst_n=1;
        request(8'd1,32'h11111111);
        wait_no_commit(5,0);
        if (scratch !== 32'h12345678) $fatal(1,"pending request changed memory");
        $display("PASS five pending cycles do not commit");
        decision(8'd9,1);
        wait_no_commit(2,0);
        $display("PASS unrelated decision does not release the request");
        decision(8'd1,1);
        @(posedge clk); #1;
        if (commits !== 1 || scratch !== 32'h11111111) $fatal(1,"permit did not commit once");
        wait_no_commit(3,1);
        $display("PASS matching permit commits exactly once");

        request(8'd2,32'h22222222);
        wait_no_commit(2,1);
        decision(8'd2,0);
        @(posedge clk); #1;
        if (rejects !== 1 || scratch !== 32'h11111111 || commits !== 1)
            $fatal(1,"deny result mismatch");
        $display("PASS deny produces one reject and no write");

        request(8'd3,32'h33333333);
        commit_ready=0;
        decision(8'd3,1);
        repeat(3) begin
            @(posedge clk); #1;
            if (commit_valid !== 1 || commit_data !== 32'h33333333 || commits !== 1)
                $fatal(1,"unstable pending transfer under backpressure");
        end
        @(negedge clk); commit_ready=1;
        @(posedge clk); #1;
        if (commits !== 2 || scratch !== 32'h33333333) $fatal(1,"buffered request lost");
        wait_no_commit(2,2);
        $display("PASS downstream backpressure preserves data and prevents duplicate writes");

        request(8'd4,32'h44444444);
        @(negedge clk); rst_n=0;
        @(negedge clk); rst_n=1;
        decision(8'd4,1);
        wait_no_commit(2,2);
        if (scratch !== 32'h33333333 || request_ready !== 1)
            $fatal(1,"reset did not clear the pending request");
        $display("PASS reset clears a pending request");
        $finish;
    end
endmodule
