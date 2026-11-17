`timescale 1ns/1ps
module gpio_marker_tb;
    localparam [31:0] BASE = 32'h2000f000;
    localparam [31:0] CLKEN = 32'h4002180c;
    localparam [31:0] ODR = 32'h40000200;
    localparam [31:0] DIR = 32'h40000204;
    localparam [31:0] OSOD = 32'h40000258;
    localparam [31:0] AFR2 = 32'h4000026c;
    localparam [31:0] PUPD = 32'h4000025c;
    localparam [31:0] AFR = 32'h40000268;
    localparam [20:0] REPLAY_OFFSET = 21'h1fff4c;
    localparam [31:0] REPLAY_JUMP = {
        REPLAY_OFFSET[20], REPLAY_OFFSET[10:1], REPLAY_OFFSET[11], REPLAY_OFFSET[19:12], 5'b0, 7'h6f
    };
    reg clk = 0, rst = 0;
    always #5 clk = ~clk;
    reg [31:0] gpio_clk = 32'h80000, gpio_odr = 32'h2b, gpio_dir = 32'h12;
    reg [31:0] gpio_afr = 32'h81b, gpio_osod = 32'hcd;
    reg [31:0] gpio_afr2 = 32'h21f, gpio_pupd = 32'h143;
    reg [31:0] rom[0:127], words[0:68];
    wire [31:0] pc, address, data;
    wire req, we;
    reg [31:0] read_data;
    wire [31:0] instruction = pc < 512 ? rom[pc[8:2]] : 32'h00000013;
    wire [1:0] sink = gpio_dir[1:0] & gpio_osod[1:0] & ~gpio_odr[1:0];
    wire [1:0] released_high = ~gpio_dir[1:0] & gpio_pupd[7:6];
    reg observed_both_high = 0;
    integer i, post_done_records = 0;
    reg observed_done_pin = 0, observed_repeat_pin = 0, replay;

    always @* begin
        case (address)
            CLKEN: read_data = gpio_clk;
            ODR:   read_data = gpio_odr;
            DIR:   read_data = gpio_dir;
            OSOD:  read_data = gpio_osod;
            AFR:   read_data = gpio_afr;
            AFR2:  read_data = gpio_afr2;
            PUPD:  read_data = gpio_pupd;
            default: read_data = address == BASE + 48 ? words[12] : 32'b0;
        endcase
    end

    tinyriscv dut (
        .clk(clk), .rst(rst), .rib_ex_req_o(req), .rib_ex_we_o(we),
        .rib_ex_addr_o(address), .rib_ex_data_o(data), .rib_ex_data_i(read_data),
        .rib_pc_addr_o(pc), .rib_pc_data_i(instruction),
        .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0), .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );

    always @(posedge clk) if (rst) begin
        if (dut.ex_csr_we_o) $fatal(1, "Unexpected CSR write");
        if (released_high == 2'b11)
            observed_both_high <= 1;
        if (sink[0]) begin
            if (!observed_both_high) $fatal(1, "Both pins must be released before DONE");
            if (words[11] !== 32'h52547000) $fatal(1, "Done pin before mailbox completion");
            observed_done_pin <= 1;
        end
        if (sink[1]) begin
            if (!observed_done_pin || post_done_records == 0)
                $fatal(1, "Late-record pin without a late record");
            observed_repeat_pin <= 1;
        end
        if (req && we) begin
            case (address)
                CLKEN: gpio_clk <= data;
                ODR:   gpio_odr <= data;
                DIR:   gpio_dir <= data;
                OSOD:  gpio_osod <= data;
                AFR:   gpio_afr <= data;
                AFR2:  gpio_afr2 <= data;
                PUPD:  gpio_pupd <= data;
                default: begin
                    if (address < BASE || address > BASE + 272 || address[1:0] != 0)
                        $fatal(1, "Unexpected write address %h", address);
                    words[(address - BASE) >> 2] <= data;
                    if (observed_done_pin && address == BASE + 16)
                        post_done_records <= post_done_records + 1;
                end
            endcase
        end
    end

    initial begin
        replay = $test$plusargs("replay");
        for (i = 0; i < 69; i = i + 1) words[i] = 0;
        $readmemh("firmware.hex", rom);
        if (rom['h1d8/4] !== 32'h0000006f) $fatal(1, "Expected self-jump at terminal");
        if (replay) rom['h1d8/4] = REPLAY_JUMP;
        repeat (4) @(negedge clk);
        rst = 1;
        repeat (400) @(negedge clk);
        if (!observed_done_pin || words[1] !== 8 || words[4] !== 8 || words[68] !== 8 ||
            gpio_clk !== 32'h80001 || gpio_dir !== (replay ? 32'h13 : 32'h11) ||
            gpio_afr !== 32'h800 || gpio_afr2 !== 32'h210 || gpio_pupd !== 32'h1c0 ||
            gpio_osod !== 32'h0f || gpio_odr !== 32'h28)
            $fatal(1, "Unexpected initialization or baseline result: clk=%h af=%h dir=%h od=%h counts=%h/%h",
                gpio_clk, gpio_afr, gpio_dir, gpio_osod, words[1], words[4]);
        if (replay ? (!observed_repeat_pin || post_done_records == 0) :
                     (observed_repeat_pin || post_done_records != 0))
            $fatal(1, "Late record marker did not match test scenario");
        $display("PASS replay=%b done_low=%b repeat_low=%b saw_both_released_high=%b post_done_records=%0d",
                 replay, sink[0], sink[1], observed_both_high, post_done_records);
        $finish;
    end
endmodule
