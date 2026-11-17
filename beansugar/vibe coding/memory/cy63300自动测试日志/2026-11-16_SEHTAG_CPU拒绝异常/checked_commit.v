`timescale 1ns/1ps
module checked_commit (
    input wire clk, rst_n,
    input wire request_valid,
    output wire request_ready,
    input wire [7:0] request_id,
    input wire [31:0] request_data,
    input wire decision_valid, decision_allow,
    input wire [7:0] decision_id,
    output wire commit_valid,
    input wire commit_ready,
    output reg [31:0] commit_data,
    output reg reject
);
    localparam IDLE=2'd0, WAIT_CHECK=2'd1, APPROVED=2'd2;
    reg [1:0] state;
    reg [7:0] active_id;

    assign request_ready = rst_n && state == IDLE;
    assign commit_valid = rst_n && state == APPROVED;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            active_id <= 0;
            commit_data <= 0;
            reject <= 0;
        end else begin
            reject <= 0;
            case (state)
                IDLE: if (request_valid && request_ready) begin
                    active_id <= request_id;
                    commit_data <= request_data;
                    state <= WAIT_CHECK;
                end
                WAIT_CHECK: if (decision_valid && decision_id == active_id) begin
                    if (decision_allow) state <= APPROVED;
                    else begin
                        reject <= 1;
                        state <= IDLE;
                    end
                end
                APPROVED: if (commit_valid && commit_ready) state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
