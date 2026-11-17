`timescale 1ns/1ps
module boot_tb;
reg clk=0, rst=0;
always #5 clk=~clk;
reg [31:0] rom[0:127];
wire [31:0] pc;
wire [31:0] inst = pc < 512 ? rom[pc[8:2]] : 32'h00000013;
wire req;
tinyriscv dut (
 .clk(clk), .rst(rst), .rib_ex_req_o(req), .rib_ex_data_i(32'b0),
 .rib_ex_tag_i(4'b0), .rib_pc_addr_o(pc), .rib_pc_data_i(inst),
 .jtag_reg_addr_i(5'b0), .jtag_reg_data_i(32'b0), .jtag_reg_we_i(1'b0),
 .rib_hold_flag_i(1'b0), .jtag_halt_flag_i(1'b0), .jtag_reset_flag_i(1'b0), .int_i(8'b0)
);
initial begin
 $readmemh("firmware.hex",rom);
 $dumpfile("boot.vcd");
 $dumpvars(0,boot_tb);
 repeat(3) @(negedge clk);
 rst=1;
 repeat(100) begin
  @(posedge clk); #1;
  if(req !== 0) $fatal(1,"Unexpected data bus request");
  if(dut.u_regs.regs[26] === 32'h3f) $fatal(1,"Firmware CSR readback failed");
  if(dut.u_regs.regs[26] === 32'h60) begin
   if(dut.u_regs.regs[8] !== 0 || dut.u_regs.regs[9] !== 1 ||
      dut.safety_check_en !== 1 || dut.u_csr_reg.mcause !== 0)
    $fatal(1,"Incorrect CSR state");
   $display("PASS natural boot: CSR initial=0 final=1, enable=1, mcause=0, marker=0x60");
   $finish;
  end
 end
 $fatal(1,"Timeout pc=%h",pc);
end
endmodule
