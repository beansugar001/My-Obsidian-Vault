`timescale 1ns/1ps
// 7-bit address-only + one-data-byte ACK device. Not an actual OLED model.
module i2c_slave_bfm (
    input wire rst_n, input wire enabled_i,
    input wire scl, inout wire sda,
    output integer start_events,
    output integer stop_events,
    output integer payload_events,
    output reg [7:0] last_payload
);
    reg pull_sda=0;
    assign sda = pull_sda ? 1'b0 : 1'bz;
    integer bits_seen=0;
    reg [7:0] shift=0;
    reg active=0, data_phase=0, matched=0;
    initial begin
        start_events=0;stop_events=0;payload_events=0;last_payload=0;
    end
    always @(negedge sda) begin
        if(rst_n && scl === 1'b1) begin
            active=1;bits_seen=0;shift=0;data_phase=0;matched=0;
            start_events=start_events+1;
        end
    end
    always @(posedge sda) begin
        if(rst_n && scl === 1'b1 && active) begin
            active=0;pull_sda=0;stop_events=stop_events+1;
        end
    end
    always @(posedge scl) begin
        if (rst_n && active) begin
            if(bits_seen<8) begin
                shift={shift[6:0],sda};
                bits_seen=bits_seen+1;
            end else begin
                // Ninth pulse is ACK. Record received byte only after a valid address.
                if(!data_phase) begin
                    matched=(shift==8'h78);
                    data_phase=1;
                end else if(matched && enabled_i) begin
                    payload_events=payload_events+1;
                    last_payload=shift;
                end
                bits_seen=0;
                shift=0;
            end
        end
    end
    always @(negedge scl) begin
        if(rst_n && active) begin
            if(bits_seen==8 && enabled_i && ((!data_phase && shift==8'h78) || (data_phase && matched)))
                pull_sda=1;
            else pull_sda=0;
        end else pull_sda=0;
    end
endmodule
