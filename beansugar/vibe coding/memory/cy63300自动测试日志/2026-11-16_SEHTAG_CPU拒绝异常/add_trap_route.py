from pathlib import Path

cpu = Path("sim_cpu.v")
text = cpu.read_text()
def swap(old, new):
    global text
    if text.count(old) != 1:
        raise ValueError(old)
    text = text.replace(old, new)

swap("    input wire sim_store_ready,", "    input wire sim_store_ready,\n    input wire sim_deny_store,")
swap("store_allow <= bnb_check_valid;", "store_allow <= bnb_check_valid && !sim_deny_store;")
swap("if (store_done) store_waiting <= 0;", "if (store_done || store_reject) store_waiting <= 0;")
swap("assign csr_we_o = ", "assign csr_we_o = store_reject ? 1'b1 : ")
swap("assign csr_waddr_o = ", "assign csr_waddr_o = store_reject ? 32'h342 : ")
swap("assign csr_wdata_o = ", "assign csr_wdata_o = store_reject ? 32'h5 : ")
swap(".jump_flag_i(store_done ||", ".jump_flag_i(store_reject || store_done ||")
swap(".jump_addr_i(store_done ?", ".jump_addr_i(store_reject ? csr_clint_csr_mtvec : store_done ?")
cpu.write_text(text, encoding="ascii")
