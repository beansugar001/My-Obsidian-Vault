
from pathlib import Path
import sys

rtl = Path(sys.argv[1])
source = (rtl / "tinyriscv.v").read_text()
decode = (rtl / "id.v").read_text()

def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f"Unexpected source context: {old}")
    return text.replace(old, new)

decode = replace_once(decode, "        case (opcode)\n", """        case (opcode)
            7'h0b: begin
                reg1_raddr_o = rs1;
                reg2_raddr_o = \`ZeroReg;
                reg_waddr_o = rd;
                reg_we_o = \`WriteDisable;
            end
""")
adapter = """
    // Simulation adapter for one legitimate allocation. It is not a chip ABI.
    localparam ALLOC_IDLE=0, ALLOC_WAIT=1, ALLOC_BASE=2, ALLOC_BOUND=3, ALLOC_RETURN=4;
    reg [2:0] alloc_state;
    reg [31:0] alloc_pc, alloc_ptr;
    reg [15:0] alloc_size;
    reg [4:0] alloc_rd;
    reg [3:0] alloc_tag;
    wire alloc_start = alloc_state == ALLOC_IDLE && ie_inst_o[6:0] == 7'h0b
                     && ie_inst_o[14:12] == 3'd1;
    wire alloc_return = alloc_state == ALLOC_RETURN;
    wire write_metadata = alloc_state == ALLOC_BASE || alloc_state == ALLOC_BOUND;
    wire checked_word_load = safety_check_en && ie_reg1_tag_o &&
                      ie_inst_o[6:0] == \`INST_TYPE_L && ie_inst_o[14:12] == \`INST_LW &&
                      ex_mem_req_o;

    always @(posedge clk) begin
        if (rst == \`RstEnable) begin
            alloc_state <= ALLOC_IDLE;
            alloc_pc <= 0;
            alloc_ptr <= 0;
            alloc_size <= 0;
            alloc_rd <= 0;
            alloc_tag <= 0;
        end else begin
            case (alloc_state)
                ALLOC_IDLE: if (alloc_start) begin
                    alloc_pc <= ie_inst_addr_o;
                    alloc_size <= ie_reg1_rdata_o[15:0];
                    alloc_rd <= ie_inst_o[11:7];
                    alloc_tag <= ie_inst_o[23:20];
                    alloc_state <= ALLOC_WAIT;
                end
                ALLOC_WAIT: if (hat_valid && !hat_error) begin
                    alloc_ptr <= hat_alloc_addr;
                    alloc_state <= ALLOC_BASE;
                end
                ALLOC_BASE: alloc_state <= ALLOC_BOUND;
                ALLOC_BOUND: alloc_state <= ALLOC_RETURN;
                ALLOC_RETURN: alloc_state <= ALLOC_IDLE;
                default: alloc_state <= ALLOC_IDLE;
            endcase
        end
    end
""".replace("\\","")
decode = decode.replace("\\\x60","\x60")
source = replace_once(source, "    wire hat_enable;", adapter + "\n    wire hat_enable;")
for name, selected in {
    "ext_tag_o": "alloc_return ? alloc_tag : checked_word_load ? 4'b0 : ",
    "tag_we_o": "alloc_return ? 1'b1 : checked_word_load ? ex_reg_we_o : ",
    "tag_addr_o": "alloc_return ? alloc_rd : checked_word_load ? ex_reg_waddr_o : ",
    "final_reg_we": "alloc_return ? 1'b1 : ",
    "final_reg_waddr": "alloc_return ? alloc_rd : ",
    "final_reg_wdata": "alloc_return ? alloc_ptr : checked_word_load ? rib_ex_data_i : ",
    "bnb_index_we": "alloc_return ? 1'b1 : ",
    "bnb_index_addr": "alloc_return ? alloc_rd : ",
    "bnb_index_value": "alloc_return ? 3'd0 : ",
    "bnb_lookup_we": "write_metadata ? 1'b1 : ",
    "bnb_lookup_addr_we": "write_metadata ? 3'd0 : ",
    "bnb_lookup_base_i": "write_metadata ? alloc_ptr : ",
    "bnb_lookup_bound_i": "write_metadata ? (alloc_ptr + {16'b0,alloc_size} - 1'b1) : ",
    "bnb_lookup_ptr_id_i": "write_metadata ? alloc_ptr : ",
    "bnb_lookup_wt": "write_metadata ? (alloc_state == ALLOC_BOUND) : ",
}.items():
    key = f"assign {name} = "
    source = replace_once(source, key, key + selected)
ctrl_begin = source.index("    ctrl u_ctrl(")
ctrl_end = source.index("    );", ctrl_begin)
ctrl = source[ctrl_begin:ctrl_end]
ctrl = replace_once(ctrl, ".jump_flag_i(ex_jump_flag_o)", ".jump_flag_i(ex_jump_flag_o || alloc_return)")
ctrl = replace_once(ctrl, ".jump_addr_i(ex_jump_addr_o)", ".jump_addr_i(alloc_return ? alloc_pc + 32'd4 : ex_jump_addr_o)")
source = source[:ctrl_begin] + ctrl + source[ctrl_end:]

for old, new in (
    (".hold_flag_seu_i(seu_hold_flag)", ".hold_flag_seu_i(seu_hold_flag || alloc_start || alloc_state != ALLOC_IDLE)"),
    (".index_addr_i(id_reg1_raddr_o)", ".index_addr_i(ie_inst_o[19:15])"),
    ("assign hat_enable = 1'b0;", "assign hat_enable = alloc_state == ALLOC_WAIT && !hat_valid;"),
    ("assign hat_operation = 3'b000;", "assign hat_operation = 3'b001;"),
    ("assign hat_size = 16'h0;", "assign hat_size = alloc_size;"),
    ("assign hat_tag = 4'h0;", "assign hat_tag = alloc_tag;"),
):
    source = replace_once(source, old, new)
Path("sim_cpu.v").write_text(source, encoding="ascii")
Path("sim_decode.v").write_text(decode, encoding="ascii")

