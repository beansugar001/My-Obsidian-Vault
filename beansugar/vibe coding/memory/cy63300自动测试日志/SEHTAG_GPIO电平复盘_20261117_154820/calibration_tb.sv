`timescale 1ns/1ps
module calibration_tb;
    reg clk = 0, rst = 0;
    always #5 clk = ~clk;
    reg [31:0] rom[0:127];
    reg [31:0] clk_en = 32'h80000, dir = 32'h12, odr = 32'h2b;
    reg [31:0] afr1 = 32'h81b, afr2 = 32'h21f, osod = 32'hcd, pupd = 32'h143;
    wire req, we;
    wire [31:0] pc, address, data;
    reg [31:0] read_data;
    integer writes = 0;
    wire c0_low = dir[0] && osod[0] && !odr[0];
    wire c1_high = !dir[1] && pupd[7];

    always @* begin
        case (address)
            32'h4002180c: read_data = clk_en;
            32'h40000204: read_data = dir;
            32'h40000200: read_data = odr;
            32'h40000268: read_data = afr1;
            32'h4000026c: read_data = afr2;
            32'h40000258: read_data = osod;
            32'h4000025c: read_data = pupd;
            default: read_data = 0;
        endcase
    end
    tinyriscv dut (
        .clk(clk), .rst(rst), .rib_ex_req_o(req), .rib_ex_we_o(we),
        .rib_ex_addr_o(address), .rib_ex_data_o(data), .rib_ex_data_i(read_data),
        .rib_pc_addr_o(pc), .rib_pc_data_i(pc < 512 ? rom[pc[8:2]] : 32'h00000013),
        .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0), .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );

    always @(posedge clk) if (rst && req && we) begin
        writes <= writes + 1;
        case (address)
            32'h4002180c: clk_en <= data;
            32'h40000204: dir <= data;
            32'h40000200: odr <= data;
            32'h40000268: afr1 <= data;
            32'h4000026c: afr2 <= data;
            32'h40000258: osod <= data;
            32'h4000025c: pupd <= data;
            default: $fatal(1, "Unexpected address %h", address);
        endcase
    end

    initial begin
        $readmemh("firmware.hex", rom);
        repeat (4) @(negedge clk);
        rst = 1;
        repeat (160) @(negedge clk);
        if (clk_en !== 32'h80001 || dir !== 32'h11 || odr !== 32'h28 ||
            afr1 !== 32'h800 || afr2 !== 32'h210 || osod !== 32'h0f || pupd !== 32'h180 ||
            !c0_low || !c1_high || writes !== 8)
            $fatal(1, "Calibration mismatch: clk=%h dir=%h odr=%h af=%h/%h osod=%h pupd=%h writes=%0d",
                clk_en, dir, odr, afr1, afr2, osod, pupd, writes);
        $display("PASS GPIO model C0=low C1=high writes=%0d; no changes after initialization", writes);
        $finish;
    end
endmodule
