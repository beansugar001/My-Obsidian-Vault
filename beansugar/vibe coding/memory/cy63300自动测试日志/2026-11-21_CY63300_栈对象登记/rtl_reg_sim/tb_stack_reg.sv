`timescale 1ns/1ps
// Report-only memory model for the three-case registration probe.
module tb_stack_reg;
    localparam [31:0] RAM_BASE = 32'h2000_0000;
    localparam [31:0] RAM_LAST = 32'h2001_ffff;
    localparam [31:0] PLM_BASE = 32'h7000_0000;
    localparam [31:0] PLM_LAST = 32'h7000_000f;

    reg clk = 0, rst = 0;
    always #5 clk = ~clk;

    reg [31:0] rom [0:127];
    reg [31:0] sram [0:32767];
    reg [31:0] plm [0:3];

    wire [31:0] pc, address, value;
    wire req, we;
    wire ram_sel = (address >= RAM_BASE) && (address <= RAM_LAST) && (address[1:0] == 2'b0);
    wire plm_sel = (address >= PLM_BASE) && (address <= PLM_LAST) && (address[1:0] == 2'b0);
    wire [31:0] data_in = ram_sel ? sram[address[16:2]] : plm_sel ? plm[address[3:2]] : 32'b0;
    wire [31:0] instruction = pc < 512 ? rom[pc[8:2]] : 32'h00000013;

    tinyriscv dut (
        .clk(clk), .rst(rst), .rib_ex_req_o(req), .rib_ex_we_o(we),
        .rib_ex_addr_o(address), .rib_ex_data_i(data_in), .rib_ex_data_o(value),
        .rib_ex_tag_i(4'b0), .rib_pc_addr_o(pc), .rib_pc_data_i(instruction),
        .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
        .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0),
        .jtag_reset_flag_i(1'b0), .int_i(8'b0)
    );

    reg oob1111 = 0, oob2222 = 0, illegal = 0;
    always @(posedge clk) if (rst && req) begin
        if (ram_sel) begin
            if (we) sram[address[16:2]] <= value;
        end else if (plm_sel) begin
            if (we) plm[address[3:2]] <= value;
        end else begin
            illegal <= 1'b1;
            $display("ILLEGAL_ADDR %h we=%b", address, we);
        end
        if (we && value == 32'hcafe1111 && address == 32'h2001ff08) oob1111 <= 1'b1;
        if (we && value == 32'hcafe2222 && address == 32'h2001feec) oob2222 <= 1'b1;
    end

    integer i;
    initial begin
        for (i = 0; i < 32768; i = i + 1) sram[i] = 32'h0;
        for (i = 0; i < 128; i = i + 1) rom[i] = 32'h00000013;
        for (i = 0; i < 4; i = i + 1) plm[i] = 32'h0;
        sram[(32'h2001ff08 - RAM_BASE) >> 2] = 32'ha5a5a5a5;
        $readmemh("firmware_reg.hex", rom);
        repeat (4) @(negedge clk);
        rst = 1;
        for (i = 0; i < 8000; i = i + 1) @(negedge clk);

        $display("RESULT r0=%08h r1=%08h r2=%08h r3=%08h r4=%08h r5=%08h r6=%08h r7=%08h",
            sram[(32'h2000f100-RAM_BASE)/4+0], sram[(32'h2000f100-RAM_BASE)/4+1],
            sram[(32'h2000f100-RAM_BASE)/4+2], sram[(32'h2000f100-RAM_BASE)/4+3],
            sram[(32'h2000f100-RAM_BASE)/4+4], sram[(32'h2000f100-RAM_BASE)/4+5],
            sram[(32'h2000f100-RAM_BASE)/4+6], sram[(32'h2000f100-RAM_BASE)/4+7]);
        $display("RESULT r8=%08h r9=%08h r10=%08h r11=%08h r12=%08h r13=%08h r14=%08h r15=%08h",
            sram[(32'h2000f100-RAM_BASE)/4+8], sram[(32'h2000f100-RAM_BASE)/4+9],
            sram[(32'h2000f100-RAM_BASE)/4+10], sram[(32'h2000f100-RAM_BASE)/4+11],
            sram[(32'h2000f100-RAM_BASE)/4+12], sram[(32'h2000f100-RAM_BASE)/4+13],
            sram[(32'h2000f100-RAM_BASE)/4+14], sram[(32'h2000f100-RAM_BASE)/4+15]);
        $display("RESULT r16=%08h r17=%08h",
            sram[(32'h2000f100-RAM_BASE)/4+16], sram[(32'h2000f100-RAM_BASE)/4+17]);
        $display("PLM %08h %08h %08h %08h", plm[0], plm[1], plm[2], plm[3]);
        $display("MEM oob_slot=%08h frame8=%08h frame12=%08h",
            sram[(32'h2001ff08-RAM_BASE)/4], sram[(32'h2001fee8-RAM_BASE)/4],
            sram[(32'h2001feec-RAM_BASE)/4]);
        $display("BUS oob1111_on_bus=%0d oob2222_on_bus=%0d illegal_addr=%0d",
            oob1111, oob2222, illegal);
        if (illegal) $fatal(1, "access outside the memory model");
        $finish;
    end
endmodule
