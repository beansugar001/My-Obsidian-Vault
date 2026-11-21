`timescale 1ns/1ps
// Report-only model for the v2 board diagnostic: what happens once safety_check_en=1.
module tb_stack_v2;
    localparam [31:0] RAM_BASE = 32'h2000_0000;
    localparam [31:0] RAM_LAST = 32'h2001_ffff;

    reg clk = 0, rst = 0;
    always #5 clk = ~clk;

    reg [31:0] rom [0:127];
    reg [31:0] sram [0:32767];

    wire [31:0] pc, address, value;
    wire req, we;
    wire ram_sel = (address >= RAM_BASE) && (address <= RAM_LAST) && (address[1:0] == 2'b0);
    wire [31:0] data_in = ram_sel ? sram[address[16:2]] : 32'b0;
    wire [31:0] instruction = pc < 512 ? rom[pc[8:2]] : 32'h00000013;

    tinyriscv dut (
        .clk(clk), .rst(rst), .rib_ex_req_o(req), .rib_ex_we_o(we),
        .rib_ex_addr_o(address), .rib_ex_data_i(data_in), .rib_ex_data_o(value),
        .rib_ex_tag_i(4'b0), .rib_pc_addr_o(pc), .rib_pc_data_i(instruction),
        .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0),
        .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );

    reg poison_on_bus = 0, illegal = 0;
    always @(posedge clk) if (rst && req) begin
        if (ram_sel) begin
            if (we) sram[address[16:2]] <= value;
        end else begin
            illegal <= 1'b1;
            $display("ILLEGAL_ADDR %h we=%b", address, we);
        end
        if (we && value == 32'h5555aaaa) poison_on_bus <= 1'b1;
    end

    integer i;
    initial begin
        for (i = 0; i < 32768; i = i + 1) sram[i] = 32'h0;
        for (i = 0; i < 128; i = i + 1) rom[i] = 32'h00000013;
        sram[(32'h2001fee8 - RAM_BASE) >> 2] = 32'hbbbbbbbb;   // poisoned slot
        $readmemh("firmware.hex", rom);
        repeat (4) @(negedge clk);
        rst = 1;
        for (i = 0; i < 8000; i = i + 1) @(negedge clk);

        $display("RES r0=%08h r1=%08h r2=%08h r3=%08h r4=%08h r5=%08h r6=%08h r7=%08h r8=%08h r9=%08h r10=%08h r11=%08h",
            sram[(32'h2000f100-RAM_BASE)/4+0], sram[(32'h2000f100-RAM_BASE)/4+1],
            sram[(32'h2000f100-RAM_BASE)/4+2], sram[(32'h2000f100-RAM_BASE)/4+3],
            sram[(32'h2000f100-RAM_BASE)/4+4], sram[(32'h2000f100-RAM_BASE)/4+5],
            sram[(32'h2000f100-RAM_BASE)/4+6], sram[(32'h2000f100-RAM_BASE)/4+7],
            sram[(32'h2000f100-RAM_BASE)/4+8], sram[(32'h2000f100-RAM_BASE)/4+9],
            sram[(32'h2000f100-RAM_BASE)/4+10], sram[(32'h2000f100-RAM_BASE)/4+11]);
        $display("MBX w0=%08h w1=%08h w2=%08h w14=%08h w15=%08h",
            sram[(32'h2000f000-RAM_BASE)/4], sram[(32'h2000f004-RAM_BASE)/4],
            sram[(32'h2000f008-RAM_BASE)/4], sram[(32'h2000f038-RAM_BASE)/4],
            sram[(32'h2000f03c-RAM_BASE)/4]);
        $display("STA frame8=%08h poison_on_bus=%0d illegal=%0d",
            sram[(32'h2001fee8-RAM_BASE)/4], poison_on_bus, illegal);
        if (illegal) $fatal(1, "access outside the model");
        $finish;
    end
endmodule
