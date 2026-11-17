`timescale 1ns/1ps
// CY63300 documentation-ADDRESS behavioral I2C mock -- NOT CY63300 I2C RTL.
// register base: I2C 0x40002800, PERI_CLKEN 0x4002180C (RIB strips upper nibble).
// Test dialect only: two TX_FIFO byte writes (address+W, then payload) launch a transfer.
// Real CY63300's FIFO/start/restart semantics MUST be checked using its actual IP RTL.
// Generates START, 8 address bits, ACK, 8 data bits, ACK, STOP on open-drain lines.
module i2c_behavioral_mmio (
    input wire clk, input wire rst_n,
    input wire [31:0] addr_i, input wire [31:0] wdata_i,
    input wire we_i, output wire [31:0] rdata_o,
    inout wire scl, inout wire sda,
    output reg [31:0] starts_o, output reg [31:0] stops_o,
    output reg [31:0] acks_o, output reg [31:0] nacks_o,
    output reg bus_stuck_o
);
    reg scl_drive_low, sda_drive_low;
    assign scl = scl_drive_low ? 1'b0 : 1'bz;
    assign sda = sda_drive_low ? 1'b0 : 1'bz;
    reg [31:0] peri_clk;
    reg [31:0] module_ctrl, clk_div0, clk_div1, mode_reg, addr_reg, master_ctrl;
    reg [7:0] address_byte, payload_byte;
    reg [1:0] fifo_count;
    reg [7:0] shifter;
    reg [2:0] bit_index;
    reg data_phase;
    localparam [3:0] ST_IDLE=0, ST_START=1, ST_LOW=2, ST_HIGH=3,
                     ST_ACK_LOW=4, ST_ACK_HIGH=5,
                     ST_STOP_LOW=6, ST_STOP_HIGH=7, ST_STOP_DONE=8,
                     ST_BIT_SETUP=9, ST_ACK_SETUP=10, ST_STOP_SETUP=11;
    reg [3:0] state;
    // V3.3 MOCK TIMING ONLY: hold each serialized FSM micro-step for a
    // programmable number of system clocks. Low-side steps use CLK_DIV0;
    // high-side steps use CLK_DIV1. This is NOT the CY63300 divider formula.
    reg [7:0] phase_wait;
    wire in_low_phase = (state == ST_LOW) || (state == ST_BIT_SETUP) ||
                        (state == ST_ACK_LOW) || (state == ST_ACK_SETUP) ||
                        (state == ST_STOP_LOW) || (state == ST_STOP_SETUP);
    wire [7:0] raw_step_div = in_low_phase ? clk_div0[7:0] : clk_div1[7:0];
    wire [7:0] step_div = raw_step_div == 8'd0 ? 8'd1 : raw_step_div;
    wire enabled = peri_clk[5] && module_ctrl[0] && module_ctrl[2] && mode_reg[0];
    wire in_i2c_range = addr_i >= 32'h00002800 && addr_i <= 32'h000028ff;
    wire [7:0] ofs = addr_i[7:0];
    // Decode directly from the full address and update the read output once.
    // Avoid zero-time address/data feedback with the reference RIB's default
    // output assignments. This preserves the original register read values.
    assign rdata_o =
        (addr_i == 32'h0002180c) ? peri_clk :
        (addr_i == 32'h00002800) ? (module_ctrl | 32'h2) :
        (addr_i == 32'h0000280c) ? {30'd0, 1'b1, (fifo_count == 0)} :
        (addr_i == 32'h00002810) ? clk_div0 :
        (addr_i == 32'h00002814) ? clk_div1 :
        (addr_i == 32'h00002820) ? mode_reg :
        (addr_i == 32'h00002824) ? addr_reg :
        (addr_i == 32'h00002828) ? master_ctrl :
        (addr_i == 32'h0000283c) ? {30'd0, (state != ST_IDLE), (state != ST_IDLE)} :
        32'h0;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            peri_clk<=0; module_ctrl<=0; clk_div0<=32'h20; clk_div1<=32'h30;
            mode_reg<=1;addr_reg<=32'h133;master_ctrl<=0;
            phase_wait<=0;
            fifo_count<=0;address_byte<=0;payload_byte<=0;
            shifter<=0;bit_index<=0;data_phase<=0;state<=ST_IDLE;
            scl_drive_low<=0;sda_drive_low<=0;
            starts_o<=0;stops_o<=0;acks_o<=0;nacks_o<=0;bus_stuck_o<=0;
        end else begin
            // Register writes from the original RIB slave-4 interface.
            if(we_i) begin
                if (addr_i == 32'h0002180c) peri_clk <= wdata_i;
                else if (in_i2c_range && peri_clk[5]) begin
                    case(ofs)
                        8'h00: begin module_ctrl <= wdata_i & 32'h0d;
                            if (!wdata_i[0]) fifo_count<=0;
                        end
                        8'h08: if(module_ctrl[2] && state==ST_IDLE && fifo_count < 2) begin
                            if(fifo_count==0) address_byte<=wdata_i[7:0];
                            else payload_byte<=wdata_i[7:0];
                            fifo_count<=fifo_count+1'b1;
                        end
                        8'h10: clk_div0<= wdata_i & 32'h00ffffff;
                        8'h14: clk_div1<= wdata_i & 32'h00ffffff;
                        8'h20: mode_reg<=wdata_i & 32'h1;
                        8'h24: addr_reg<=wdata_i & 32'h3ff;
                        8'h28: master_ctrl<=wdata_i & 32'h1f;
                    endcase
                end
            end
            if (state == ST_IDLE) phase_wait <= 8'd0;
            else if (phase_wait != 8'd0) phase_wait <= phase_wait - 8'd1;
            else phase_wait <= step_div - 8'd1;
            if (state == ST_IDLE || phase_wait == 8'd0) begin
            case(state)
                ST_IDLE: begin
                    scl_drive_low<=0;sda_drive_low<=0;
                    if(enabled && fifo_count==2) begin
                        fifo_count<=0;
                        if(scl !== 1'b1 || sda !== 1'b1) begin
                            bus_stuck_o<=1'b1;
                        end else begin
                            state<=ST_START;
                            shifter<=address_byte;
                            bit_index<=3'd7;
                            data_phase<=0;
                            bus_stuck_o<=0;
                        end
                    end
                end
                ST_START: begin
                    scl_drive_low<=0;sda_drive_low<=1;
                    starts_o<=starts_o+1;
                    state<=ST_LOW;
                end
                ST_LOW: begin
                    scl_drive_low<=1;
                    state<=ST_BIT_SETUP;
                end
                ST_BIT_SETUP: begin
                    sda_drive_low<=~shifter[bit_index];
                    state<=ST_HIGH;
                end
                ST_HIGH: begin
                    scl_drive_low<=0;
                    if (bit_index==0) state<=ST_ACK_LOW;
                    else begin bit_index<=bit_index-1'b1;state<=ST_LOW; end
                end
                ST_ACK_LOW: begin
                    scl_drive_low<=1;
                    state<=ST_ACK_SETUP;
                end
                ST_ACK_SETUP: begin
                    sda_drive_low<=0;
                    state<=ST_ACK_HIGH;
                end
                ST_ACK_HIGH: begin
                    scl_drive_low<=0;
                    if(sda === 1'b0) begin
                        acks_o<=acks_o+1;
                        if(!data_phase) begin
                            data_phase<=1;
                            shifter<=payload_byte;
                            bit_index<=3'd7;
                            state<=ST_LOW;
                        end else state<=ST_STOP_LOW;
                    end else begin
                        nacks_o<=nacks_o+1;
                        state<=ST_STOP_LOW;
                    end
                end
                ST_STOP_LOW: begin
                    scl_drive_low<=1;state<=ST_STOP_SETUP;
                end
                ST_STOP_SETUP: begin
                    sda_drive_low<=1;state<=ST_STOP_HIGH;
                end
                ST_STOP_HIGH: begin
                    scl_drive_low<=0;sda_drive_low<=1;state<=ST_STOP_DONE;
                end
                ST_STOP_DONE: begin
                    scl_drive_low<=0;sda_drive_low<=0;stops_o<=stops_o+1;
                    state<=ST_IDLE;
                end
                default: state<=ST_IDLE;
            endcase
            end // V3.3 configurable micro-step enable
        end
    end
endmodule
