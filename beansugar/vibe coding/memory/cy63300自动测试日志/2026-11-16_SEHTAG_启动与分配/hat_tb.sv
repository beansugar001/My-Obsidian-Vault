`timescale 1ns/1ps
module hat_tb;
reg clk=0, rst=0, issue=0;
always #5 clk=~clk;
wire [31:0] allocated;
wire valid, error;
wire [3:0] error_type;
mcu_memory_security dut(
 .clk(clk), .rst_n(rst), .enable_i(issue), .operation_i(3'b001),
 .addr_i(32'b0), .size_i(16'd32), .tag_i(4'd1), .stack_ptr_i(32'b0),
 .alloc_addr_o(allocated), .valid_o(valid), .error_o(error), .error_type_o(error_type),
 .ptr_query_addr_i(32'b0), .ptr_query_en_i(1'b0)
);
initial begin
 $dumpfile("hat.vcd");
 $dumpvars(0,hat_tb);
 repeat(3) @(negedge clk);
 rst=1;
 repeat(280) @(negedge clk);
 issue=1;
 @(negedge clk); issue=0;
 repeat(300) begin
  @(posedge clk); #1;
  if(error === 1) $fatal(1,"Allocation error=%h",error_type);
  if(valid === 1) begin
   if(allocated !== 32'h20000000) $fatal(1,"Unexpected address=%h",allocated);
   $display("PASS standalone HAT: 32 bytes allocated at %h",allocated);
   $finish;
  end
 end
 $fatal(1,"Allocation timed out");
end
endmodule
