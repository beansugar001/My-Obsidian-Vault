from pathlib import Path
import sys

cpu = Path("sim_cpu.v")
rtl = cpu.read_text()

def replace_one(old, new):
    global rtl
    if rtl.count(old) != 1:
        raise ValueError(f"Unexpected source context: {old}")
    rtl = rtl.replace(old, new)

replace_one("    input wire clk,", "    input wire clk,\n    input wire sim_store_ready,")
logic = """
    // Simulation-only adapter for a single checked word store.
    reg store_waiting;
    reg [2:0] store_phase;
    reg store_allow;
    reg [31:0] store_addr, store_pc;
    wire store_slot_ready, store_commit_valid, store_reject;
    wire [31:0] store_commit_data;
    wire store_begin = !store_waiting && store_slot_ready && safety_check_en &&
                       ie_inst_o[6:0] == 7'h23 && ie_inst_o[14:12] == 3'd2 &&
                       bnb_check_en && bnb_index_valid;
    wire store_guard = store_waiting || store_begin;
    wire store_done = store_commit_valid && sim_store_ready;
    wire store_decision_valid = store_waiting && store_phase == 3'd3;

    checked_commit guard (
        .clk(clk), .rst_n(rst), .request_valid(store_begin),
        .request_ready(store_slot_ready), .request_id(8'd1),
        .request_data(ex_mem_wdata_o), .decision_valid(store_decision_valid),
        .decision_allow(store_allow), .decision_id(8'd1),
        .commit_valid(store_commit_valid), .commit_ready(sim_store_ready),
        .commit_data(store_commit_data), .reject(store_reject)
    );

    always @(posedge clk) begin
        if (!rst) begin
            store_waiting <= 0;
            store_phase <= 0;
            store_allow <= 0;
            store_addr <= 0;
            store_pc <= 0;
        end else if (store_begin) begin
            store_waiting <= 1;
            store_phase <= 1;
            store_addr <= ex_mem_waddr_o;
            store_pc <= ie_inst_addr_o;
        end else if (store_waiting) begin
            if (store_phase == 1) store_allow <= bnb_check_valid;
            if (store_phase < 4) store_phase <= store_phase + 1'b1;
            if (store_done) store_waiting <= 0;
        end
    end
"""
replace_one("    wire hat_enable;", logic + "\n    wire hat_enable;")
for port, select in (
    ("addr", "store_addr"),
    ("data", "store_commit_data"),
    ("req", "store_done"),
    ("we", "store_done"),
    ("tag_we", "1'b0"),
):
    old = f"assign rib_ex_{port}_o = "
    replace_one(old, old + f"store_guard ? {select} : ")
replace_one(".jump_flag_i(ex_jump_flag_o || alloc_return)", ".jump_flag_i(store_done || (ex_jump_flag_o && !store_guard) || alloc_return)")
replace_one(".jump_addr_i(alloc_return ?", ".jump_addr_i(store_done ? store_pc + 32'd4 : alloc_return ?")
replace_one(".hold_flag_seu_i(seu_hold_flag || alloc_start || alloc_state != ALLOC_IDLE)", ".hold_flag_seu_i(seu_hold_flag || alloc_start || alloc_state != ALLOC_IDLE || store_guard)")
cpu.write_text(rtl, encoding="ascii")
