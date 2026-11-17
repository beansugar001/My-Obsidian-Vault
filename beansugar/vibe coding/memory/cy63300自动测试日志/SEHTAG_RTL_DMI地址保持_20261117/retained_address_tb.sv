`timescale 1ns/1ps
`include "defines.v"
module retained_address_tb;
    localparam [31:0] PARK = 32'h2000f110;
    localparam [31:0] FIXED_A = 32'h2000f004;
    localparam [31:0] FIXED_B = 32'h2000f02c;
    localparam [31:0] FETCH = 32'h00108093;
    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;
    reg request = 0, response_ack = 0;
    reg [39:0] command = 0;
    wire request_ack, response, debug_req, debug_we, debug_halt, debug_reset, hold;
    wire [39:0] result;
    wire [31:0] debug_addr, debug_wdata, debug_rdata, instruction;
    wire [31:0] slave_addr, slave_wdata;
    wire slave_we;
    reg cpu_write = 0;
    reg [31:0] cpu_wdata = 0, parked_word = 32'h00000e8d;
    reg enforce_park = 0;
    integer hold_cycles = 0, debug_grants = 0;

    jtag_dm dm (
        .clk(clk), .rst_n(rst_n),
        .dm_ack_o(request_ack), .dtm_req_valid_i(request), .dtm_req_data_i(command),
        .dtm_ack_i(response_ack), .dm_resp_data_o(result), .dm_resp_valid_o(response),
        .dm_reg_we_o(), .dm_reg_addr_o(), .dm_reg_wdata_o(), .dm_reg_rdata_i(32'b0),
        .dm_mem_we_o(debug_we), .dm_mem_addr_o(debug_addr),
        .dm_mem_wdata_o(debug_wdata), .dm_mem_rdata_i(debug_rdata),
        .dm_op_req_o(debug_req), .dm_halt_req_o(debug_halt), .dm_reset_req_o(debug_reset)
    );

    wire [31:0] slave_rdata = slave_addr == {4'b0, PARK[27:0]} ? parked_word :
                              slave_addr == {4'b0, FIXED_A[27:0]} ? 32'h00000008 :
                              slave_addr == {4'b0, FIXED_B[27:0]} ? 32'h52547000 :
                              32'hdeadbeef;
    rib fabric (
        .clk(clk), .rst(rst_n),
        .m0_addr_i(PARK), .m0_data_i(cpu_wdata), .m0_data_o(), .m0_req_i(cpu_write), .m0_we_i(cpu_write),
        .m1_addr_i(32'h00000080), .m1_data_i(32'b0), .m1_data_o(instruction), .m1_req_i(1'b1), .m1_we_i(1'b0),
        .m2_addr_i(debug_addr), .m2_data_i(debug_wdata), .m2_data_o(debug_rdata), .m2_req_i(debug_req), .m2_we_i(debug_we),
        .m3_addr_i(32'b0), .m3_data_i(32'b0), .m3_data_o(), .m3_req_i(1'b0), .m3_we_i(1'b0),
        .s0_addr_o(), .s0_data_o(), .s0_data_i(FETCH), .s0_we_o(),
        .s1_addr_o(), .s1_data_o(), .s1_data_i(32'b0), .s1_we_o(),
        .s2_addr_o(slave_addr), .s2_data_o(slave_wdata), .s2_data_i(slave_rdata), .s2_we_o(slave_we),
        .s3_addr_o(), .s3_data_o(), .s3_data_i(32'b0), .s3_we_o(),
        .s4_addr_o(), .s4_data_o(), .s4_data_i(32'b0), .s4_we_o(),
        .s5_addr_o(), .s5_data_o(), .s5_data_i(32'b0), .s5_we_o(),
        .hold_flag_o(hold)
    );

    always @(posedge clk) if (rst_n) begin
        if (debug_we || debug_reset || debug_halt) $fatal(1, "Unexpected DM side effect");
        if (slave_we) begin
            if (!cpu_write || slave_addr != {4'b0, PARK[27:0]}) $fatal(1, "Unexpected test write");
            parked_word <= slave_wdata;
        end
        if (hold) hold_cycles <= hold_cycles + 1;
        if (debug_req && !cpu_write) begin
            debug_grants <= debug_grants + 1;
            if (!hold || instruction !== `INST_NOP) $fatal(1, "Debug request did not displace fetch");
            if (enforce_park && (debug_addr !== PARK || slave_addr !== {4'b0, PARK[27:0]}))
                $fatal(1, "Debug grant escaped retained address");
        end
    end

    task automatic dmi(input [1:0] op, input [5:0] addr, input [31:0] data, output [31:0] value);
        @(negedge clk);
        command = {addr, data, op};
        request = 1;
        wait (request_ack);
        @(negedge clk);
        request = 0;
        wait (response);
        @(negedge clk);
        if (result[1:0] !== 0) $fatal(1, "DMI error addr=%h", addr);
        value = result[33:2];
        response_ack = 1;
        wait (!response);
        @(negedge clk);
        response_ack = 0;
        wait (!request_ack);
        repeat (5) @(negedge clk);
    endtask

    task automatic cpu_publish(input [31:0] value);
        @(negedge clk);
        cpu_wdata = value;
        cpu_write = 1;
        @(negedge clk);
        cpu_write = 0;
    endtask

    task automatic expect_data(input [31:0] expected);
        reg [31:0] value;
        dmi(2'b01, 6'h3c, 0, value);
        if (value !== expected) $fatal(1, "SBDATA0 expected %h got %h", expected, value);
        $display("OBS SBDATA0=%h actual_debug_addr=%h", value, debug_addr);
    endtask

    reg [31:0] result_word;
    integer before_grants, before_holds;
    initial begin
        $dumpfile("retained_address.vcd");
        $dumpvars(1, retained_address_tb);
        repeat (4) @(negedge clk);
        rst_n = 1;
        repeat (4) @(negedge clk);
        if (hold || instruction !== FETCH) $fatal(1, "Undisturbed instruction fetch is not valid");

        dmi(2'b10, 6'h38, 32'h00140000, result_word);
        dmi(2'b10, 6'h39, PARK, result_word);
        expect_data(32'h00000e8d);
        dmi(2'b10, 6'h38, 32'h00040000, result_word);
        enforce_park = 1;
        before_grants = debug_grants;
        before_holds = hold_cycles;
        dmi(2'b10, 6'h39, FIXED_A, result_word);
        cpu_publish(32'h00000e94);
        dmi(2'b01, 6'h38, 0, result_word);
        if (result_word !== 32'h00040000 || dm.sbaddress0 !== FIXED_A)
            $fatal(1, "SBCS/SBADDRESS0 did not retain the programmed values");
        expect_data(32'h00000e94);
        dmi(2'b10, 6'h39, FIXED_B, result_word);
        cpu_publish(32'h00000e9f);
        if (dm.sbaddress0 !== FIXED_B) $fatal(1, "Second SBADDRESS0 update was not retained");
        expect_data(32'h00000e9f);
        if (debug_grants <= before_grants || hold_cycles <= before_holds)
            $fatal(1, "No arbitration effect with read trigger disabled");
        $display("PASS trigger off: requested addresses changed, port retained %h, debug_grants=%0d hold_cycles=%0d",
                 debug_addr, debug_grants-before_grants, hold_cycles-before_holds-2);

        before_grants = debug_grants;
        dmi(2'b01, 6'h11, 0, result_word);
        if (result_word !== 32'h00430c82 || debug_grants <= before_grants)
            $fatal(1, "DMSTATUS data or arbitration behavior unexpected");
        $display("PASS DMSTATUS read also acquired bus during response: debug_grants=%0d", debug_grants-before_grants);

        enforce_park = 0;
        dmi(2'b10, 6'h38, 32'h00140000, result_word);
        dmi(2'b10, 6'h39, FIXED_B, result_word);
        expect_data(32'h52547000);
        $display("PASS read-on-address enabled routes the requested fixed word");
        $finish;
    end

    initial begin
        #30000;
        $fatal(1, "DMI handshake timed out");
    end
endmodule
