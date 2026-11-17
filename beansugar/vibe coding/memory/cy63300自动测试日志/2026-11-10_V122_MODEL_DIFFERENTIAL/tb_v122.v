`timescale 1ns/1ps
module tb;
reg clk=0; always #5 clk=~clk;
reg rst_n=0; reg [31:0] addr=0, data=0; reg we=0;
wire [31:0] rd,starts,stops,acks,nacks; wire stuck; tri1 scl,sda;
integer se,te,pe; wire [7:0] payload;
i2c_behavioral_mmio dut(clk,rst_n,addr,data,we,rd,scl,sda,starts,stops,acks,nacks,stuck);
i2c_slave_bfm slave(rst_n,1'b1,scl,sda,se,te,pe,payload);
task wr(input [31:0] a,input [31:0] d); begin @(negedge clk); addr=a; data=d; we=1; @(negedge clk); we=0; end endtask
initial begin
repeat(5) @(negedge clk); rst_n=1;
wr(32'h0002180c,32'h20); wr(32'h00002810,2); wr(32'h00002814,2); wr(32'h00002820,1); wr(32'h00002828,2); wr(32'h00002800,13);
wr(32'h00002824,32'h3c); wr(32'h00002808,32'h00);
repeat(300) @(negedge clk);
$display("ONE_BYTE starts=%0d fifo=%0d state=%0d scl=%b sda=%b",starts,dut.fifo_count,dut.state,scl,sda);
if(starts!=0 || dut.fifo_count!=1) $fatal(1,"ONE_BYTE_UNEXPECTED");
rst_n=0; repeat(5) @(negedge clk); rst_n=1;
wr(32'h0002180c,32'h20); wr(32'h00002810,2); wr(32'h00002814,2); wr(32'h00002820,1); wr(32'h00002828,2); wr(32'h00002800,13);
wr(32'h00002808,32'h78); wr(32'h00002808,32'ha5);
repeat(2000) @(negedge clk);
$display("TWO_BYTES starts=%0d stops=%0d acks=%0d fifo=%0d payload=%02x",starts,stops,acks,dut.fifo_count,payload);
if(starts!=1 || stops!=1 || acks!=2 || payload!=8'ha5) $fatal(1,"TWO_BYTES_UNEXPECTED");
$display("PASS_MODEL_DIFFERENTIAL_ONLY"); $finish;
end
endmodule
