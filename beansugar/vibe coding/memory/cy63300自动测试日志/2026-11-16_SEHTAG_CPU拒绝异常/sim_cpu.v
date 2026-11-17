
`include "defines.v"


module tinyriscv(

    input wire clk,
    input wire sim_store_ready,
    input wire sim_deny_store,
    input wire rst,

    output wire[`MemAddrBus] rib_ex_addr_o,
    input wire[`MemBus] rib_ex_data_i,
    output wire[`MemBus] rib_ex_data_o,
    output wire rib_ex_req_o,
    output wire rib_ex_we_o,


    output wire[`ExtTagBus] rib_ex_tag_o,
    input wire[`ExtTagBus] rib_ex_tag_i,
    output wire rib_ex_tag_we_o,

    output wire[`MemAddrBus] rib_pc_addr_o,
    input wire[`MemBus] rib_pc_data_i,

    input wire[`RegAddrBus] jtag_reg_addr_i,
    input wire[`RegBus] jtag_reg_data_i,
    input wire jtag_reg_we_i,
    output wire[`RegBus] jtag_reg_data_o,

    input wire rib_hold_flag_i,
    input wire jtag_halt_flag_i,
    input wire jtag_reset_flag_i,

    input wire[`INT_BUS] int_i

    );


    wire[`ExtTagBus] mem_tag_i;
    wire[`ExtTagBus] mem_tag_o;
    wire mem_tag_we_o;
    wire fnst_mem_tag_we_o;
    wire fnld_mem_tag_we_o;


	wire[`InstAddrBus] pc_pc_o;


	wire[`InstBus] if_inst_o;
    wire[`InstAddrBus] if_inst_addr_o;
    wire[`INT_BUS] if_int_flag_o;


    wire[`RegAddrBus] id_reg1_raddr_o;
    wire[`RegAddrBus] id_reg2_raddr_o;
    wire[`InstBus] id_inst_o;
    wire[`InstAddrBus] id_inst_addr_o;
    wire[`RegBus] id_reg1_rdata_o;
    wire[`RegBus] id_reg2_rdata_o;
    wire id_reg_we_o;
    wire[`RegAddrBus] id_reg_waddr_o;
    wire[`MemAddrBus] id_csr_raddr_o;
    wire id_csr_we_o;
    wire[`RegBus] id_csr_rdata_o;
    wire[`MemAddrBus] id_csr_waddr_o;
    wire[`MemAddrBus] id_op1_o;
    wire[`MemAddrBus] id_op2_o;
    wire[`MemAddrBus] id_op1_jump_o;
    wire[`MemAddrBus] id_op2_jump_o;


    wire[`InstBus] ie_inst_o;
    wire[`InstAddrBus] ie_inst_addr_o;
    wire ie_reg_we_o;
    wire[`RegAddrBus] ie_reg_waddr_o;
    wire[`RegBus] ie_reg1_rdata_o;
    wire[`RegBus] ie_reg2_rdata_o;
    wire ie_csr_we_o;
    wire[`MemAddrBus] ie_csr_waddr_o;
    wire[`RegBus] ie_csr_rdata_o;
    wire[`MemAddrBus] ie_op1_o;
    wire[`MemAddrBus] ie_op2_o;
    wire[`MemAddrBus] ie_op1_jump_o;
    wire[`MemAddrBus] ie_op2_jump_o;


    wire[`MemBus] ex_mem_wdata_o;
    wire[`MemAddrBus] ex_mem_raddr_o;
    wire[`MemAddrBus] ex_mem_waddr_o;
    wire ex_mem_we_o;
    wire ex_mem_req_o;
    wire[`RegBus] ex_reg_wdata_o;
    wire ex_reg_we_o;
    wire[`RegAddrBus] ex_reg_waddr_o;
    wire ex_hold_flag_o;
    wire ex_jump_flag_o;
    wire[`InstAddrBus] ex_jump_addr_o;
    wire ex_div_start_o;
    wire[`RegBus] ex_div_dividend_o;
    wire[`RegBus] ex_div_divisor_o;
    wire[2:0] ex_div_op_o;
    wire[`RegAddrBus] ex_div_reg_waddr_o;
    wire[`RegBus] ex_csr_wdata_o;
    wire ex_csr_we_o;
    wire[`MemAddrBus] ex_csr_waddr_o;


    wire ex_tag_we_o;
    wire ex_tag_value_o;
    wire[`RegAddrBus] ex_tag_addr_o;


    wire[`RegBus] regs_rdata1_o;
    wire[`RegBus] regs_rdata2_o;


    wire[`RegBus] csr_data_o;
    wire[`RegBus] csr_clint_data_o;
    wire csr_global_int_en_o;
    wire[`RegBus] csr_clint_csr_mtvec;
    wire[`RegBus] csr_clint_csr_mepc;
    wire[`RegBus] csr_clint_csr_mstatus;


    wire[`Hold_Flag_Bus] ctrl_hold_flag_o;
    wire ctrl_jump_flag_o;
    wire[`InstAddrBus] ctrl_jump_addr_o;


    wire[`RegBus] div_result_o;
	wire div_ready_o;
    wire div_busy_o;
    wire[`RegAddrBus] div_reg_waddr_o;


    wire clint_we_o;
    wire[`MemAddrBus] clint_waddr_o;
    wire[`MemAddrBus] clint_raddr_o;
    wire[`RegBus] clint_data_o;
    wire[`InstAddrBus] clint_int_addr_o;
    wire clint_int_assert_o;
    wire clint_hold_flag_o;


    wire bnb_index_we;
    wire[4:0] bnb_index_addr;
    wire[2:0] bnb_index_value;
    wire[2:0] bnb_index;
    wire bnb_index_valid;

    wire bnb_lookup_we;
    wire[2:0] bnb_lookup_addr;
    wire[`RegBus] bnb_lookup_base;
    wire[`RegBus] bnb_lookup_bound;
    wire[`RegBus] bnb_lookup_ptr_id;
    wire bnb_lookup_valid;

    wire bnb_stack_push;
    wire bnb_stack_pop;
    wire[`RegBus] bnb_stack_ptr_id_o;
    wire[`RegBus] bnb_stack_ptr_id_i;

    wire bnb_check_en;
    wire bnb_check_valid;
    wire[`RegBus] check_addr;


    wire[2:0] bnb_lookup_addr_we;
    wire[`RegBus] bnb_lookup_base_i;
    wire[`RegBus] bnb_lookup_bound_i;
    wire[`RegBus] bnb_lookup_ptr_id_i;
    wire bnb_lookup_wt;

    wire seu_bnb_lookup_wt;
    wire seu_bnb_lookup_alloc_req_o;
    wire[`RegBus] seu_bnb_lookup_alloc_ptr_id_o;

    wire[2:0] exec_index_value;
    wire exec_index_valid;


    wire seu_bnb_index_we_o;
    wire[4:0] seu_bnb_index_addr_o;
    wire[2:0] seu_bnb_index_value_o;
    wire seu_bnb_lookup_we_o;
    wire[2:0] seu_bnb_lookup_addr_o;
    wire[2:0] seu_bnb_lookup_addr_we_o;
    wire[`RegBus] seu_bnb_lookup_base_o;
    wire[`RegBus] seu_bnb_lookup_bound_o;
    wire[`RegBus] seu_bnb_lookup_ptr_id_o;
    wire seu_bnb_stack_push_o;
    wire seu_bnb_stack_pop_o;
    wire[`RegBus] seu_bnb_stack_ptr_id_o;


    wire[6:0] ex_opcode;
    wire ex_inst_bit20;


    wire reg1_tag;
    wire reg2_tag;
    wire reg_tag_we;
    wire reg_tag_value;
    wire[`RegAddrBus] reg_tag_addr;


    wire[`SEC_LEVEL_BUS] reg1_sec_level;
    wire[`SEC_LEVEL_BUS] reg2_sec_level;
    wire[`SEC_LEVEL_BUS] reg3_sec_level;
    wire reg1_trust;
    wire reg2_trust;
    wire reg3_trust;

    wire[`SEC_LEVEL_BUS] id_reg1_sec_level;
    wire[`SEC_LEVEL_BUS] id_reg2_sec_level;
    wire[`SEC_LEVEL_BUS] id_reg3_sec_level;
    wire id_reg1_trust;
    wire id_reg2_trust;
    wire id_reg3_trust;

    wire[`SEC_LEVEL_BUS] ie_reg1_sec_level_o;
    wire[`SEC_LEVEL_BUS] ie_reg2_sec_level_o;
    wire[`SEC_LEVEL_BUS] ie_reg3_sec_level_o;
    wire ie_reg1_trust_o;
    wire ie_reg2_trust_o;
    wire ie_reg3_trust_o;

    wire[`SEC_LEVEL_BUS] tcu_result_sec_level;
    wire tcu_result_trust;

    wire[`ExtTagBus] id_ext_tag;
    wire[`ExtTagBus] ie_ext_tag_o;
    wire[`ExtTagBus] ex_ext_tag;
    wire[`ExtTagBus] seu_ext_tag;
    wire[`ExtTagBus] ext_tag_o;


    wire seu_enable;
    wire[`RegBus] seu_result;
    wire seu_ready;
    wire id_is_security_inst;
    wire ie_is_security_inst;


    wire seu_plm_we_o;
    wire[`MemAddrBus] seu_plm_addr_o;
    wire[`RegBus] seu_plm_wdata_o;


    wire seu_csr_we_o;
    wire[`MemAddrBus] seu_csr_waddr_o;
    wire[`RegBus] seu_csr_wdata_o;


    wire seu_reg_tag_we;
    wire[`RegAddrBus] seu_reg_tag_addr;


    wire[`RegBus] tcu_result;
    wire tcu_result_tag;
    wire tcu_illegal_op;


    wire[`RegBus] csr_plbr;
    wire[`RegBus] csr_bnbsp;
    wire alloc_new_ptr;


    wire id_reg1_tag;
    wire id_reg2_tag;
    wire id_tag_we;
    wire id_tag_value;
    wire[`RegAddrBus] id_tag_addr;
    wire seu_reg_we;
    wire[`RegAddrBus] seu_reg_waddr;
    wire tag_we_o;
    wire[`RegAddrBus] tag_addr_o;


    wire[`RegAddrBus] id_reg3_raddr;
    wire[`RegBus] regs_rdata3_o;
    wire id_reg3_tag_o;
    wire[`MemAddrBus] id_op3;

    wire ie_reg3_tag;

    wire ie_reg1_tag_o;
    wire ie_reg2_tag_o;
    wire ie_reg3_tag_o;
    wire ie_tag_we_o;
    wire ie_tag_value_o;
    wire[`RegAddrBus] ie_tag_addr_o;
    wire[`RegBus] ie_reg3_rdata_o;
    wire[`RegBus] id_reg3_rdata_o;
    wire[`MemAddrBus] ie_op3_o;


    wire seu_mem_we;
    wire[`MemAddrBus] seu_mem_addr;
    wire[`RegBus] seu_mem_wdata;
    wire seu_mem_req;

    wire ex_reg_tag;

    wire seu_hold_flag;


    wire bnb_lookup_alloc_req;
    wire[`RegBus] bnb_lookup_alloc_ptr_id;

    wire[2:0] bnb_lookup_alloc_addr;
    wire bnb_lookup_alloc_valid;


    wire ldptr_start;
    wire ldptr_ready;
    wire ldptr_busy;
    wire[`RegBus] ldptr_result;
    wire[`MemAddrBus] ldptr_mem_addr;
    wire ldptr_mem_req;
    wire ldptr_mem_we;


    wire ldptr_bnb_index_we;
    wire[4:0] ldptr_bnb_index_addr;
    wire[2:0] ldptr_bnb_index_value;

    wire ldptr_bnb_lookup_we;
    wire[2:0] ldptr_bnb_lookup_addr;
    wire[2:0] ldptr_bnb_lookup_addr_we;
    wire[`RegBus] ldptr_bnb_lookup_base;
    wire[`RegBus] ldptr_bnb_lookup_bound;
    wire[`RegBus] ldptr_bnb_lookup_ptr_id;
    wire ldptr_bnb_lookup_wt;

    wire ldptr_bnb_lookup_alloc_req;
    wire[`RegBus] ldptr_bnb_lookup_alloc_ptr_id;

    wire ldptr_reg_we;
    wire[`RegAddrBus] ldptr_reg_waddr;
    wire[`RegBus] ldptr_reg_wdata;


    wire ldptr_reg_tag_we;
    wire[`RegAddrBus] ldptr_reg_tag_addr;
    wire[`ExtTagBus] ldptr_ext_tag;

    wire fnst_start;
    wire fnst_ready;
    wire fnst_busy;
    wire[`MemAddrBus] fnst_mem_addr;
    wire[`RegBus] fnst_mem_wdata;
    wire fnst_mem_req;
    wire fnst_mem_we;
    wire fnst_csr_we;
    wire[`MemAddrBus] fnst_csr_waddr;
    wire[`RegBus] fnst_csr_wdata;
    wire fnst_bnb_stack_push;
    wire[`RegBus] fnst_bnb_stack_ptr_id;


    wire fnld_start;
    wire fnld_ready;
    wire fnld_busy;
    wire[`RegBus] fnld_result;
    wire[`MemAddrBus] fnld_mem_addr;
    wire fnld_mem_req;
    wire fnld_mem_we;
    wire fnld_csr_we;
    wire[`MemAddrBus] fnld_csr_waddr;
    wire[`RegBus] fnld_csr_wdata;


    wire fnld_bnb_index_we;
    wire[4:0] fnld_bnb_index_addr;
    wire[2:0] fnld_bnb_index_value;
    wire fnld_bnb_lookup_we;
    wire[2:0] fnld_bnb_lookup_addr;
    wire[2:0] fnld_bnb_lookup_addr_we;
    wire[`RegBus] fnld_bnb_lookup_base;
    wire[`RegBus] fnld_bnb_lookup_bound;
    wire[`RegBus] fnld_bnb_lookup_ptr_id;
    wire fnld_bnb_lookup_wt;
    wire fnld_bnb_lookup_alloc_req;
    wire[`RegBus] fnld_bnb_lookup_alloc_ptr_id;


    wire fnld_reg_tag_we;
    wire[`RegAddrBus] fnld_reg_tag_addr;
    wire[`ExtTagBus] fnld_ext_tag;
    wire fnld_reg_we;
    wire[`RegAddrBus] fnld_reg_waddr;
    wire[`RegBus] fnld_reg_wdata;


    wire final_reg_we;
    wire[`RegAddrBus] final_reg_waddr;
    wire[`RegBus] final_reg_wdata;

    wire csr_we_o;
    wire[`MemAddrBus] csr_waddr_o;
    wire[`RegBus] csr_wdata_o;


    wire safety_check_en;



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
                      ie_inst_o[6:0] == `INST_TYPE_L && ie_inst_o[14:12] == `INST_LW &&
                      ex_mem_req_o;

    always @(posedge clk) begin
        if (rst == `RstEnable) begin
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
            if (store_phase == 1) store_allow <= bnb_check_valid && !sim_deny_store;
            if (store_phase < 4) store_phase <= store_phase + 1'b1;
            if (store_done || store_reject) store_waiting <= 0;
        end
    end

    wire hat_enable;
    wire[2:0] hat_operation;
    wire[`ADDR_WIDTH-1:0] hat_addr;
    wire[`SIZE_WIDTH-1:0] hat_size;
    wire[`TAG_WIDTH-1:0] hat_tag;
    wire[`ADDR_WIDTH-1:0] hat_alloc_addr;
    wire hat_valid;
    wire hat_error;
    wire[3:0] hat_error_type;


    wire bnb_ptr_freed;
    wire bnb_ptr_valid;
    wire[`GEN_WIDTH-1:0] bnb_ptr_gen;
    wire[7:0] bnb_lookup_freed_vec;


    wire hat_ptr_freed;
    wire[`GEN_WIDTH-1:0] hat_ptr_gen;
    wire hat_query_en;


    assign rib_ex_tag_o = mem_tag_o;
    assign rib_ex_tag_we_o = store_guard ? 1'b0 : (fnld_busy) ? fnld_mem_tag_we_o :
                        (fnst_busy) ? fnst_mem_tag_we_o :
                        mem_tag_we_o;
    assign mem_tag_i = rib_ex_tag_i;


    assign ext_tag_o = alloc_return ? alloc_tag : checked_word_load ? 4'b0 : (fnld_busy && fnld_reg_tag_we) ? fnld_ext_tag :
        (ldptr_busy && ldptr_reg_tag_we) ? ldptr_ext_tag :
        (ie_is_security_inst ? seu_ext_tag : ex_ext_tag);


    assign csr_we_o = store_reject ? 1'b1 : (fnld_busy && fnld_csr_we) ? fnld_csr_we :
                     (fnst_busy && fnst_csr_we) ? fnst_csr_we :
                     (ie_is_security_inst ? seu_csr_we_o : ex_csr_we_o);

    assign csr_waddr_o = store_reject ? 32'h342 : (fnld_busy && fnld_csr_we) ? fnld_csr_waddr :
                        (fnst_busy && fnst_csr_we) ? fnst_csr_waddr :
                        (ie_is_security_inst ? seu_csr_waddr_o : ex_csr_waddr_o);

    assign csr_wdata_o = store_reject ? 32'h5 : (fnld_busy && fnld_csr_we) ? fnld_csr_wdata :
                        (fnst_busy && fnst_csr_we) ? fnst_csr_wdata :
                        (ie_is_security_inst ? seu_csr_wdata_o : ex_csr_wdata_o);


    assign rib_ex_addr_o = store_guard ? store_addr : (fnld_busy) ? fnld_mem_addr :
                          (fnst_busy) ? fnst_mem_addr :
                          (ldptr_busy) ? ldptr_mem_addr :
                          (ie_is_security_inst && seu_mem_req) ? seu_mem_addr :
                          ((ex_mem_we_o == `WriteEnable) ? ex_mem_waddr_o : ex_mem_raddr_o);

    assign rib_ex_data_o = store_guard ? store_commit_data : (fnld_busy) ? `ZeroWord :
                          (fnst_busy) ? fnst_mem_wdata :
                          (ldptr_busy) ? `ZeroWord :
                          (ie_is_security_inst && seu_mem_req) ? seu_mem_wdata :
                          ex_mem_wdata_o;

    assign rib_ex_req_o = store_guard ? store_done : (fnld_busy) ? fnld_mem_req :
                         (fnst_busy) ? fnst_mem_req :
                         (ldptr_busy) ? ldptr_mem_req :
                         (ie_is_security_inst && seu_mem_req) ? seu_mem_req :
                         ex_mem_req_o;

    assign rib_ex_we_o = store_guard ? store_done : (fnld_busy) ? fnld_mem_we :
                        (fnst_busy) ? fnst_mem_we :
                        (ldptr_busy) ? ldptr_mem_we :
                        (ie_is_security_inst && seu_mem_req) ? seu_mem_we :
                        ex_mem_we_o;

    assign rib_pc_addr_o = pc_pc_o;


    assign bnb_index_we = alloc_return ? 1'b1 : (fnld_busy) ? fnld_bnb_index_we :
                          (fnst_busy) ? `WriteDisable :
                          (ldptr_busy) ? ldptr_bnb_index_we :
                          seu_bnb_index_we_o;

    assign bnb_index_addr = alloc_return ? alloc_rd : (fnld_busy) ? fnld_bnb_index_addr :
                            (fnst_busy) ? 5'h0 :
                            (ldptr_busy) ? ldptr_bnb_index_addr :
                            seu_bnb_index_addr_o;

    assign bnb_index_value = alloc_return ? 3'd0 : (fnld_busy) ? fnld_bnb_index_value :
                             (fnst_busy) ? 3'h0 :
                             (ldptr_busy) ? ldptr_bnb_index_value :
                             seu_bnb_index_value_o;


    assign bnb_lookup_we = write_metadata ? 1'b1 : (fnld_busy) ? fnld_bnb_lookup_we :
                           (fnst_busy) ? `WriteDisable :
                           (ldptr_busy) ? ldptr_bnb_lookup_we :
                           seu_bnb_lookup_we_o;

    assign bnb_lookup_addr = (fnld_busy) ? fnld_bnb_lookup_addr :
                             (fnst_busy) ? 3'h0 :
                             (ldptr_busy) ? ldptr_bnb_lookup_addr :
                             seu_bnb_lookup_addr_o;

    assign bnb_lookup_addr_we = write_metadata ? 3'd0 : (fnld_busy) ? fnld_bnb_lookup_addr_we :
                               (fnst_busy) ? 3'h0 :
                               (ldptr_busy) ? ldptr_bnb_lookup_addr_we :
                               seu_bnb_lookup_addr_we_o;

    assign bnb_lookup_base_i = write_metadata ? alloc_ptr : (fnld_busy) ? fnld_bnb_lookup_base :
                              (fnst_busy) ? `ZeroWord :
                              (ldptr_busy) ? ldptr_bnb_lookup_base :
                              seu_bnb_lookup_base_o;

    assign bnb_lookup_bound_i = write_metadata ? (alloc_ptr + {16'b0,alloc_size} - 1'b1) : (fnld_busy) ? fnld_bnb_lookup_bound :
                               (fnst_busy) ? `ZeroWord :
                               (ldptr_busy) ? ldptr_bnb_lookup_bound :
                               seu_bnb_lookup_bound_o;

    assign bnb_lookup_ptr_id_i = write_metadata ? alloc_ptr : (fnld_busy) ? fnld_bnb_lookup_ptr_id :
                                 (fnst_busy) ? `ZeroWord :
                                 (ldptr_busy) ? ldptr_bnb_lookup_ptr_id :
                                 seu_bnb_lookup_ptr_id_o;

    assign bnb_lookup_wt = write_metadata ? (alloc_state == ALLOC_BOUND) : (fnld_busy) ? fnld_bnb_lookup_wt :
                           (fnst_busy) ? 1'b0 :
                           (ldptr_busy) ? ldptr_bnb_lookup_wt :
                           seu_bnb_lookup_wt;


    assign bnb_lookup_alloc_req = (fnld_busy) ? fnld_bnb_lookup_alloc_req :
                                  (fnst_busy) ? `False :
                                  (ldptr_busy) ? ldptr_bnb_lookup_alloc_req :
                                  seu_bnb_lookup_alloc_req_o;

    assign bnb_lookup_alloc_ptr_id = (fnld_busy) ? fnld_bnb_lookup_alloc_ptr_id :
                                     (fnst_busy) ? `ZeroWord :
                                     (ldptr_busy) ? ldptr_bnb_lookup_alloc_ptr_id :
                                     seu_bnb_lookup_alloc_ptr_id_o;


    assign bnb_stack_push = (fnld_busy) ? `False :
                            (fnst_busy || fnst_start) ? fnst_bnb_stack_push :
                            seu_bnb_stack_push_o;

    assign bnb_stack_pop = (fnld_busy) ? `True :
                           (fnst_busy) ? `False :
                           seu_bnb_stack_pop_o;

    assign bnb_stack_ptr_id_i = (fnld_busy) ? `ZeroWord :
                                (fnst_busy || fnst_start) ? fnst_bnb_stack_ptr_id :
                                seu_bnb_stack_ptr_id_o;


    assign tag_we_o = alloc_return ? 1'b1 : checked_word_load ? ex_reg_we_o : (fnld_busy && fnld_reg_tag_we) ? fnld_reg_tag_we :
                      (ldptr_busy && ldptr_reg_tag_we) ? ldptr_reg_tag_we :
                      (ie_is_security_inst ? seu_reg_tag_we : ex_tag_we_o);

    assign tag_addr_o = alloc_return ? alloc_rd : checked_word_load ? ex_reg_waddr_o : (fnld_busy && fnld_reg_tag_we) ? fnld_reg_tag_addr :
                        (ldptr_busy && ldptr_reg_tag_we) ? ldptr_reg_tag_addr :
                        (ie_is_security_inst ? seu_reg_tag_addr : ex_tag_addr_o);


    assign final_reg_we = alloc_return ? 1'b1 : (fnld_busy && fnld_reg_we) ? fnld_reg_we :
                          (ldptr_busy && ldptr_reg_we) ? ldptr_reg_we :
                          (ie_is_security_inst ? seu_reg_we : ex_reg_we_o);

    assign final_reg_waddr = alloc_return ? alloc_rd : (fnld_busy && fnld_reg_we) ? fnld_reg_waddr :
                             (ldptr_busy && ldptr_reg_we) ? ldptr_reg_waddr :
                             (ie_is_security_inst ? seu_reg_waddr : ex_reg_waddr_o);

    assign final_reg_wdata = alloc_return ? alloc_ptr : checked_word_load ? rib_ex_data_i : (fnld_busy && fnld_reg_we) ? fnld_reg_wdata :
                         (ldptr_busy && ldptr_reg_we) ? ldptr_reg_wdata :
                         (ie_is_security_inst ? seu_result : ex_reg_wdata_o);


    assign check_addr = (ex_mem_we_o == `WriteEnable) ? ex_mem_waddr_o : ex_mem_raddr_o;


    assign ex_opcode = ie_inst_o[6:0];
    assign ex_inst_bit20 = ie_inst_o[20];
    assign alloc_new_ptr = (
        (ex_opcode == `INST_WRTAG && ex_inst_bit20 == 1'b1) ||
        (ex_opcode == `INST_LDPTR)
    );


    pc_reg u_pc_reg(
        .clk(clk),
        .rst(rst),
        .jtag_reset_flag_i(jtag_reset_flag_i),
        .pc_o(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .jump_flag_i(ctrl_jump_flag_o),
        .jump_addr_i(ctrl_jump_addr_o)
    );


    ctrl u_ctrl(
        .rst(rst),
        .jump_flag_i(store_reject || store_done || (ex_jump_flag_o && !store_guard) || alloc_return),
        .jump_addr_i(store_reject ? csr_clint_csr_mtvec : store_done ? store_pc + 32'd4 : alloc_return ? alloc_pc + 32'd4 : ex_jump_addr_o),
        .hold_flag_ex_i(ex_hold_flag_o),
        .hold_flag_rib_i(rib_hold_flag_i),
        .hold_flag_o(ctrl_hold_flag_o),
        .hold_flag_clint_i(clint_hold_flag_o),
        .jump_flag_o(ctrl_jump_flag_o),
        .jump_addr_o(ctrl_jump_addr_o),
        .jtag_halt_flag_i(jtag_halt_flag_i),
        .hold_flag_seu_i(seu_hold_flag || alloc_start || alloc_state != ALLOC_IDLE || store_guard)

    );


    regs u_regs(
        .clk(clk),
        .rst(rst),
        .we_i(final_reg_we),
        .waddr_i(final_reg_waddr),
        .wdata_i(final_reg_wdata),
        .raddr1_i(id_reg1_raddr_o),
        .rdata1_o(regs_rdata1_o),
        .raddr2_i(id_reg2_raddr_o),
        .rdata2_o(regs_rdata2_o),
        .jtag_we_i(jtag_reg_we_i),
        .jtag_addr_i(jtag_reg_addr_i),
        .jtag_data_i(jtag_reg_data_i),
        .jtag_data_o(jtag_reg_data_o),

        .tag_we_i(tag_we_o),
        .tag_addr_i(tag_addr_o),
        .ext_tag_i(ext_tag_o),

        .rdata1_tag_o(reg1_tag),
        .rdata2_tag_o(reg2_tag),
        .rdata1_sec_level_o(reg1_sec_level),
        .rdata2_sec_level_o(reg2_sec_level),
        .rdata1_trust_o(reg1_trust),
        .rdata2_trust_o(reg2_trust),

        .raddr3_i(id_reg3_raddr),
        .rdata3_o(regs_rdata3_o),
        .rdata3_tag_o(reg3_tag),
        .rdata3_sec_level_o(reg3_sec_level),
        .rdata3_trust_o(reg3_trust)
    );


        csr_reg u_csr_reg(
            .clk(clk),
            .rst(rst),

        .we_i(csr_we_o),

        .raddr_i(id_csr_raddr_o),

        .waddr_i(csr_waddr_o),

        .data_i(csr_wdata_o),

        .data_o(csr_data_o),
        .global_int_en_o(csr_global_int_en_o),
        .clint_we_i(clint_we_o),
        .clint_raddr_i(clint_raddr_o),
        .clint_waddr_i(clint_waddr_o),
        .clint_data_i(clint_data_o),
        .clint_data_o(csr_clint_data_o),
        .clint_csr_mtvec(csr_clint_csr_mtvec),
        .clint_csr_mepc(csr_clint_csr_mepc),
        .clint_csr_mstatus(csr_clint_csr_mstatus),

        .plbr_o(csr_plbr),
        .bnbsp_o(csr_bnbsp),
        .alloc_new_ptr_i(alloc_new_ptr),
        .safety_check_en_o(safety_check_en)
    );


    if_id u_if_id(
        .clk(clk),
        .rst(rst),
        .inst_i(rib_pc_data_i),
        .inst_addr_i(pc_pc_o),
        .int_flag_i(int_i),
        .int_flag_o(if_int_flag_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(if_inst_o),
        .inst_addr_o(if_inst_addr_o)
    );


    id u_id(
        .rst(rst),
        .inst_i(if_inst_o),
        .inst_addr_i(if_inst_addr_o),
        .reg1_rdata_i(regs_rdata1_o),
        .reg2_rdata_i(regs_rdata2_o),
        .ex_jump_flag_i(ex_jump_flag_o),
        .reg1_raddr_o(id_reg1_raddr_o),
        .reg2_raddr_o(id_reg2_raddr_o),
        .inst_o(id_inst_o),
        .inst_addr_o(id_inst_addr_o),
        .reg1_rdata_o(id_reg1_rdata_o),
        .reg2_rdata_o(id_reg2_rdata_o),
        .reg_we_o(id_reg_we_o),
        .reg_waddr_o(id_reg_waddr_o),
        .op1_o(id_op1_o),
        .op2_o(id_op2_o),
        .op1_jump_o(id_op1_jump_o),
        .op2_jump_o(id_op2_jump_o),
        .csr_rdata_i(csr_data_o),
        .csr_raddr_o(id_csr_raddr_o),
        .csr_we_o(id_csr_we_o),
        .csr_rdata_o(id_csr_rdata_o),
        .csr_waddr_o(id_csr_waddr_o),
        .is_security_inst_o(id_is_security_inst),

        .reg1_tag_i(reg1_tag),
        .reg2_tag_i(reg2_tag),
        .reg1_sec_level_i(reg1_sec_level),
        .reg2_sec_level_i(reg2_sec_level),
        .reg1_trust_i(reg1_trust),
        .reg2_trust_i(reg2_trust),
        .reg1_tag_o(id_reg1_tag),
        .reg2_tag_o(id_reg2_tag),
        .reg1_sec_level_o(id_reg1_sec_level),
        .reg2_sec_level_o(id_reg2_sec_level),
        .reg1_trust_o(id_reg1_trust),
        .reg2_trust_o(id_reg2_trust),

        .tag_we_o(id_tag_we),
        .ext_tag_o(id_ext_tag),
        .tag_addr_o(id_tag_addr),

        .reg3_rdata_i(regs_rdata3_o),
        .reg3_tag_i(reg3_tag),
        .reg3_sec_level_i(reg3_sec_level),
        .reg3_sec_level_o(id_reg3_sec_level),
        .reg3_trust_i(reg3_trust),
        .reg3_trust_o(id_reg3_trust),
        .reg3_raddr_o(id_reg3_raddr),
        .reg3_rdata_o(id_reg3_rdata_o),
        .reg3_tag_o(id_reg3_tag_o),
        .op3_o(id_op3)
    );


    id_ex u_id_ex(
        .clk(clk),
        .rst(rst),
        .inst_i(id_inst_o),
        .inst_addr_i(id_inst_addr_o),
        .reg_we_i(id_reg_we_o),
        .reg_waddr_i(id_reg_waddr_o),
        .reg1_rdata_i(id_reg1_rdata_o),
        .reg2_rdata_i(id_reg2_rdata_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(ie_inst_o),
        .inst_addr_o(ie_inst_addr_o),
        .reg_we_o(ie_reg_we_o),
        .reg_waddr_o(ie_reg_waddr_o),
        .reg1_rdata_o(ie_reg1_rdata_o),
        .reg2_rdata_o(ie_reg2_rdata_o),
        .op1_i(id_op1_o),
        .op2_i(id_op2_o),
        .op1_jump_i(id_op1_jump_o),
        .op2_jump_i(id_op2_jump_o),
        .op1_o(ie_op1_o),
        .op2_o(ie_op2_o),
        .op1_jump_o(ie_op1_jump_o),
        .op2_jump_o(ie_op2_jump_o),
        .csr_we_i(id_csr_we_o),
        .csr_waddr_i(id_csr_waddr_o),
        .csr_rdata_i(id_csr_rdata_o),
        .csr_we_o(ie_csr_we_o),
        .csr_waddr_o(ie_csr_waddr_o),
        .csr_rdata_o(ie_csr_rdata_o),

        .reg1_tag_i(id_reg1_tag),
        .reg2_tag_i(id_reg2_tag),
        .reg1_sec_level_i(id_reg1_sec_level),
        .reg2_sec_level_i(id_reg2_sec_level),
        .reg1_trust_i(id_reg1_trust),
        .reg2_trust_i(id_reg2_trust),
        .tag_we_i(id_tag_we),
        .tag_addr_i(id_tag_addr),
        .is_security_inst_i(id_is_security_inst),
        .is_security_inst_o(ie_is_security_inst),

        .reg1_tag_o(ie_reg1_tag_o),
        .reg2_tag_o(ie_reg2_tag_o),
        .reg1_sec_level_o(ie_reg1_sec_level_o),
        .reg2_sec_level_o(ie_reg2_sec_level_o),
        .reg1_trust_o(ie_reg1_trust_o),
        .reg2_trust_o(ie_reg2_trust_o),
        .tag_we_o(ie_tag_we_o),
        .ext_tag_o(ie_ext_tag_o),
        .tag_addr_o(ie_tag_addr_o),

        .reg3_rdata_i(id_reg3_rdata_o),
        .reg3_tag_i(id_reg3_tag_o),
        .op3_i(id_op3),

        .reg3_rdata_o(ie_reg3_rdata_o),
        .reg3_sec_level_i(id_reg3_sec_level),
        .reg3_trust_i(id_reg3_trust),
        .reg3_sec_level_o(ie_reg3_sec_level_o),
        .reg3_trust_o(ie_reg3_trust_o),
        .reg3_tag_o(ie_reg3_tag_o),
        .op3_o(ie_op3_o)
    );


    ex u_ex(
        .rst(rst),
        .inst_i(ie_inst_o),
        .inst_addr_i(ie_inst_addr_o),
        .reg_we_i(ie_reg_we_o),
        .reg_waddr_i(ie_reg_waddr_o),
        .reg1_rdata_i(ie_reg1_rdata_o),
        .reg2_rdata_i(ie_reg2_rdata_o),
        .op1_i(ie_op1_o),
        .op2_i(ie_op2_o),
        .op1_jump_i(ie_op1_jump_o),
        .op2_jump_i(ie_op2_jump_o),
        .mem_rdata_i(rib_ex_data_i),
        .mem_wdata_o(ex_mem_wdata_o),
        .mem_raddr_o(ex_mem_raddr_o),
        .mem_waddr_o(ex_mem_waddr_o),
        .mem_we_o(ex_mem_we_o),
        .mem_req_o(ex_mem_req_o),
        .reg_wdata_o(ex_reg_wdata_o),
        .reg_we_o(ex_reg_we_o),
        .reg_waddr_o(ex_reg_waddr_o),
        .hold_flag_o(ex_hold_flag_o),
        .jump_flag_o(ex_jump_flag_o),
        .jump_addr_o(ex_jump_addr_o),
        .int_assert_i(clint_int_assert_o),
        .int_addr_i(clint_int_addr_o),
        .div_ready_i(div_ready_o),
        .div_result_i(div_result_o),
        .div_busy_i(div_busy_o),
        .div_reg_waddr_i(div_reg_waddr_o),
        .div_start_o(ex_div_start_o),
        .div_dividend_o(ex_div_dividend_o),
        .div_divisor_o(ex_div_divisor_o),
        .div_op_o(ex_div_op_o),
        .div_reg_waddr_o(ex_div_reg_waddr_o),
        .csr_we_i(ie_csr_we_o),
        .csr_waddr_i(ie_csr_waddr_o),
        .csr_rdata_i(ie_csr_rdata_o),
        .csr_wdata_o(ex_csr_wdata_o),
        .csr_we_o(ex_csr_we_o),
        .csr_waddr_o(ex_csr_waddr_o),

        .reg1_tag_i(ie_reg1_tag_o),
        .reg2_tag_i(ie_reg2_tag_o),
        .bnb_check_valid_i(bnb_check_valid),
        .bnb_check_en_o(bnb_check_en),
        .seu_ready_i(seu_ready),
        .seu_result_i(seu_result),
        .is_security_inst_i(ie_is_security_inst),
        .tcu_result_i(tcu_result),
        .tcu_result_tag_i(tcu_result_tag),
        .tcu_illegal_op_i(tcu_illegal_op),
        .reg_tag_o(ex_tag_value_o),
        .tag_we_o(ex_tag_we_o),
        .tag_addr_o(ex_tag_addr_o),
        .safety_check_en_i(safety_check_en),

        .reg1_sec_level_i(ie_reg1_sec_level_o),
        .reg2_sec_level_i(ie_reg2_sec_level_o),
        .reg1_trust_i(ie_reg1_trust_o),
        .reg2_trust_i(ie_reg2_trust_o),
        .tcu_result_sec_level_i(tcu_result_sec_level),
        .tcu_result_trust_i(tcu_result_trust),
        .ext_tag_o(ex_ext_tag),
        .csr_mtvec_i(csr_clint_csr_mtvec)
    );


    div u_div(
        .clk(clk),
        .rst(rst),
        .dividend_i(ex_div_dividend_o),
        .divisor_i(ex_div_divisor_o),
        .start_i(ex_div_start_o),
        .op_i(ex_div_op_o),
        .reg_waddr_i(ex_div_reg_waddr_o),
        .result_o(div_result_o),
        .ready_o(div_ready_o),
        .busy_o(div_busy_o),
        .reg_waddr_o(div_reg_waddr_o)
    );


    clint u_clint(
        .clk(clk),
        .rst(rst),
        .int_flag_i(if_int_flag_o),
        .inst_i(id_inst_o),
        .inst_addr_i(id_inst_addr_o),
        .jump_flag_i(ex_jump_flag_o),
        .jump_addr_i(ex_jump_addr_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .div_started_i(ex_div_start_o),
        .data_i(csr_clint_data_o),
        .csr_mtvec(csr_clint_csr_mtvec),
        .csr_mepc(csr_clint_csr_mepc),
        .csr_mstatus(csr_clint_csr_mstatus),
        .we_o(clint_we_o),
        .waddr_o(clint_waddr_o),
        .raddr_o(clint_raddr_o),
        .data_o(clint_data_o),
        .hold_flag_o(clint_hold_flag_o),
        .global_int_en_i(csr_global_int_en_o),
        .int_addr_o(clint_int_addr_o),
        .int_assert_o(clint_int_assert_o)
    );


    bnbcache u_bnbcache(
        .clk(clk),
        .rst(rst),
        .index_addr_i(ie_inst_o[19:15]),
        .index_value_o(bnb_index),
        .index_valid_o(bnb_index_valid),
        .index_we_i(bnb_index_we),
        .index_addr_we_i(bnb_index_addr),
        .index_value_i(bnb_index_value),
        .lookup_addr_i(bnb_lookup_addr),
        .lookup_base_o(bnb_lookup_base),
        .lookup_bound_o(bnb_lookup_bound),
        .lookup_ptr_id_o(bnb_lookup_ptr_id),
        .lookup_valid_o(bnb_lookup_valid),
        .lookup_we_i(bnb_lookup_we),
        .lookup_addr_we_i(bnb_lookup_addr_we),
        .lookup_base_i(bnb_lookup_base_i),
        .lookup_bound_i(bnb_lookup_bound_i),
        .lookup_ptr_id_i(bnb_lookup_ptr_id_i),
        .stack_push_i(bnb_stack_push),
        .stack_pop_i(bnb_stack_pop),
        .stack_ptr_id_i(bnb_stack_ptr_id_i),
        .stack_ptr_id_o(bnb_stack_ptr_id_o),
        .check_addr_i(check_addr),
        .check_en_i(bnb_check_en),
        .check_valid_o(bnb_check_valid),
        .bnb_lookup_wt(bnb_lookup_wt),

        .alloc_req_i(bnb_lookup_alloc_req),
        .alloc_ptr_id_i(bnb_lookup_alloc_ptr_id),

        .alloc_addr_o(bnb_lookup_alloc_addr),
        .alloc_valid_o(bnb_lookup_alloc_valid),
        .exec_index_addr_i(ie_inst_o[19:15]),
        .exec_index_value_o(exec_index_value),
        .exec_index_valid_o(exec_index_valid),


        .ptr_freed_i(hat_ptr_freed),
        .ptr_gen_i(hat_ptr_gen),
        .ptr_query_en_i(hat_query_en),
        .ptr_valid_o(bnb_ptr_valid),
        .ptr_freed_o(bnb_ptr_freed),
        .ptr_gen_o(bnb_ptr_gen),
        .lookup_freed_o(bnb_lookup_freed_vec)
    );


    seu u_seu(
        .clk(clk),
        .rst(rst),
        .inst_i(ie_inst_o),
        .reg1_data_i(ie_reg1_rdata_o),
        .reg2_data_i(ie_reg2_rdata_o),
        .reg3_data_i(ie_reg3_rdata_o),
        .is_security_inst_i(ie_is_security_inst),
        .reg_we_o(seu_reg_we),
        .reg_waddr_o(seu_reg_waddr),
        .csr_plbr_i(csr_plbr),
        .csr_bnbsp_i(csr_bnbsp),
        .csr_we_o(seu_csr_we_o),
        .csr_waddr_o(seu_csr_waddr_o),
        .csr_wdata_o(seu_csr_wdata_o),

        .mem_we_o(seu_mem_we),
        .mem_addr_o(seu_mem_addr),
        .mem_wdata_o(seu_mem_wdata),
        .mem_req_o(seu_mem_req),
        .mem_rdata_i(rib_ex_data_i),
        .hold_flag_o(seu_hold_flag),

        .bnb_index_we_o(seu_bnb_index_we_o),
        .bnb_index_addr_o(seu_bnb_index_addr_o),
        .bnb_index_value_o(seu_bnb_index_value_o),
        .bnb_lookup_we_o(seu_bnb_lookup_we_o),
        .bnb_lookup_addr_o(seu_bnb_lookup_addr_o),
        .bnb_lookup_addr_we_o(seu_bnb_lookup_addr_we_o),

        .bnb_lookup_base_o(seu_bnb_lookup_base_o),
        .bnb_lookup_bound_o(seu_bnb_lookup_bound_o),
        .bnb_lookup_ptr_id_o(seu_bnb_lookup_ptr_id_o),
        .bnb_stack_push_o(seu_bnb_stack_push_o),
        .bnb_stack_pop_o(seu_bnb_stack_pop_o),
        .bnb_stack_ptr_id_o(seu_bnb_stack_ptr_id_o),
        .bnb_stack_ptr_id_i(bnb_stack_ptr_id_o),

        .reg_tag_we_o(seu_reg_tag_we),
        .reg_tag_addr_o(seu_reg_tag_addr),
        .ext_tag_o(seu_ext_tag),


        .reg1_tag_i(ie_reg1_tag_o),
        .reg2_tag_i(ie_reg2_tag_o),
        .reg3_tag_i(ie_reg3_tag_o),

        .reg1_sec_level_i(ie_reg1_sec_level_o),
        .reg2_sec_level_i(ie_reg2_sec_level_o),
        .reg3_sec_level_i(ie_reg3_sec_level_o),
        .reg1_trust_i(ie_reg1_trust_o),
        .reg2_trust_i(ie_reg2_trust_o),
        .reg3_trust_i(ie_reg3_trust_o),

        .mem_tag_i(1'b0),

        .result_o(seu_result),
        .ready_o(seu_ready),
        .bnb_lookup_wt(seu_bnb_lookup_wt),

        .bnb_lookup_alloc_req_o(seu_bnb_lookup_alloc_req_o),
        .bnb_lookup_alloc_ptr_id_o(seu_bnb_lookup_alloc_ptr_id_o),

        .bnb_lookup_alloc_addr_i(bnb_lookup_alloc_addr),
        .bnb_lookup_alloc_valid_i(bnb_lookup_alloc_valid),

        .ldptr_start_o(ldptr_start),
        .ldptr_ready_i(ldptr_ready),
        .ldptr_result_i(ldptr_result),
        .ldptr_busy_i(ldptr_busy),

        .fnst_start_o(fnst_start),
        .fnst_ready_i(fnst_ready),
        .fnst_busy_i(fnst_busy),

        .fnld_start_o(fnld_start),
        .fnld_ready_i(fnld_ready),
        .fnld_busy_i(fnld_busy),
        .fnld_result_i(fnld_result),


        .ptr_freed_i(hat_ptr_freed),
        .ptr_valid_i(bnb_ptr_valid),


        .bnb_index_value_i(bnb_index),
        .bnb_lookup_ptr_id_i(bnb_lookup_ptr_id)

    );

    ldptr u_ldptr(
        .clk(clk),
        .rst(rst),


        .start_i(ldptr_start),
        .inst_i(ie_inst_o),
        .rs1_data_i(ie_reg1_rdata_o),
        .rd_addr_i(ie_reg_waddr_o),


        .mem_rdata_i(rib_ex_data_i),
        .mem_addr_o(ldptr_mem_addr),
        .mem_req_o(ldptr_mem_req),
        .mem_we_o(ldptr_mem_we),


        .csr_plbr_i(csr_plbr),


        .bnb_index_we_o(ldptr_bnb_index_we),
        .bnb_index_addr_o(ldptr_bnb_index_addr),
        .bnb_index_value_o(ldptr_bnb_index_value),

        .bnb_lookup_we_o(ldptr_bnb_lookup_we),
        .bnb_lookup_addr_o(ldptr_bnb_lookup_addr),
        .bnb_lookup_addr_we_o(ldptr_bnb_lookup_addr_we),
        .bnb_lookup_base_o(ldptr_bnb_lookup_base),
        .bnb_lookup_bound_o(ldptr_bnb_lookup_bound),
        .bnb_lookup_ptr_id_o(ldptr_bnb_lookup_ptr_id),
        .bnb_lookup_wt(ldptr_bnb_lookup_wt),


        .bnb_lookup_alloc_req_o(ldptr_bnb_lookup_alloc_req),
        .bnb_lookup_alloc_ptr_id_o(ldptr_bnb_lookup_alloc_ptr_id),
        .bnb_lookup_alloc_addr_i(bnb_lookup_alloc_addr),
        .bnb_lookup_alloc_valid_i(bnb_lookup_alloc_valid),


        .reg_tag_we_o(ldptr_reg_tag_we),
        .reg_tag_addr_o(ldptr_reg_tag_addr),
        .ext_tag_o(ldptr_ext_tag),


        .result_o(ldptr_result),
        .ready_o(ldptr_ready),
        .busy_o(ldptr_busy),

        .reg_we_o(ldptr_reg_we),
        .reg_waddr_o(ldptr_reg_waddr),
        .reg_wdata_o(ldptr_reg_wdata)
    );
    fnst u_fnst(
        .clk(clk),
        .rst(rst),


        .start_i(fnst_start),
        .inst_i(ie_inst_o),
        .rs1_data_i(ie_reg1_rdata_o),
        .rs2_data_i(ie_reg2_rdata_o),
        .rs1_tag_i(ie_reg1_tag_o),


        .mem_rdata_i(rib_ex_data_i),
        .mem_addr_o(fnst_mem_addr),
        .mem_wdata_o(fnst_mem_wdata),
        .mem_req_o(fnst_mem_req),
        .mem_we_o(fnst_mem_we),

        .mem_tag_we_o(fnst_mem_tag_we_o),
        .mem_tag_o(mem_tag_o),
        .rs1_tag_full_i(ie_ext_tag_o),


        .csr_bnbsp_i(csr_bnbsp),
        .csr_we_o(fnst_csr_we),
        .csr_waddr_o(fnst_csr_waddr),
        .csr_wdata_o(fnst_csr_wdata),


        .bnb_index_i(exec_index_value),
        .bnb_index_valid_i(exec_index_valid),
        .bnb_lookup_ptr_id_i(bnb_lookup_ptr_id),


        .bnb_stack_push_o(fnst_bnb_stack_push),
        .bnb_stack_ptr_id_o(fnst_bnb_stack_ptr_id),


        .ready_o(fnst_ready),
        .busy_o(fnst_busy)
    );
    fnld u_fnld(
        .clk(clk),
        .rst(rst),


        .start_i(fnld_start),
        .inst_i(ie_inst_o),
        .rs1_data_i(ie_reg1_rdata_o),
        .rd_addr_i(ie_reg_waddr_o),


        .mem_rdata_i(rib_ex_data_i),
        .mem_addr_o(fnld_mem_addr),
        .mem_req_o(fnld_mem_req),
        .mem_we_o(fnld_mem_we),

        .mem_tag_i(rib_ex_tag_i),
        .mem_tag_we_o(fnld_mem_tag_we_o),


        .csr_bnbsp_i(csr_bnbsp),
        .csr_plbr_i(csr_plbr),
        .csr_we_o(fnld_csr_we),
        .csr_waddr_o(fnld_csr_waddr),
        .csr_wdata_o(fnld_csr_wdata),


        .bnb_index_we_o(fnld_bnb_index_we),
        .bnb_index_addr_o(fnld_bnb_index_addr),
        .bnb_index_value_o(fnld_bnb_index_value),

        .bnb_lookup_we_o(fnld_bnb_lookup_we),
        .bnb_lookup_addr_o(fnld_bnb_lookup_addr),
        .bnb_lookup_addr_we_o(fnld_bnb_lookup_addr_we),
        .bnb_lookup_base_o(fnld_bnb_lookup_base),
        .bnb_lookup_bound_o(fnld_bnb_lookup_bound),
        .bnb_lookup_ptr_id_o(fnld_bnb_lookup_ptr_id),
        .bnb_lookup_wt(fnld_bnb_lookup_wt),


        .bnb_lookup_alloc_req_o(fnld_bnb_lookup_alloc_req),
        .bnb_lookup_alloc_ptr_id_o(fnld_bnb_lookup_alloc_ptr_id),
        .bnb_lookup_alloc_addr_i(bnb_lookup_alloc_addr),
        .bnb_lookup_alloc_valid_i(bnb_lookup_alloc_valid),


        .reg_tag_we_o(fnld_reg_tag_we),
        .reg_tag_addr_o(fnld_reg_tag_addr),
        .ext_tag_o(fnld_ext_tag),
        .reg_we_o(fnld_reg_we),
        .reg_waddr_o(fnld_reg_waddr),
        .reg_wdata_o(fnld_reg_wdata),


        .result_o(fnld_result),
        .ready_o(fnld_ready),
        .busy_o(fnld_busy)
    );

    tcu u_tcu(

        .inst_i(ie_inst_o),
        .op1_i(ie_reg1_rdata_o),
        .op2_i(ie_reg2_rdata_o),
        .op1_tag_i(ie_reg1_tag_o),
        .op2_tag_i(ie_reg2_tag_o),
        .op1_sec_level_i(ie_reg1_sec_level_o),
        .op2_sec_level_i(ie_reg2_sec_level_o),
        .op1_trust_i(ie_reg1_trust_o),
        .op2_trust_i(ie_reg2_trust_o),

        .safety_check_en_i(safety_check_en),


        .ptr_freed_i(hat_ptr_freed),

        .result_o(tcu_result),
        .result_tag_o(tcu_result_tag),
        .result_sec_level_o(tcu_result_sec_level),
        .result_trust_o(tcu_result_trust),

        .illegal_op_o(tcu_illegal_op)
    );


    mcu_memory_security u_hat(
        .clk(clk),
        .rst_n(rst),

        .enable_i(hat_enable),
        .operation_i(hat_operation),
        .addr_i(hat_addr),
        .size_i(hat_size),
        .tag_i(hat_tag),
        .stack_ptr_i(32'h0),

        .alloc_addr_o(hat_alloc_addr),
        .valid_o(hat_valid),
        .error_o(hat_error),
        .error_type_o(hat_error_type),
        .stack_overflow_o(),


        .ptr_freed_o(hat_ptr_freed),
        .ptr_gen_o(hat_ptr_gen),
        .ptr_query_addr_i(check_addr),
        .ptr_query_en_i(hat_query_en)
    );


    assign hat_query_en = safety_check_en &&
                          (ie_inst_o[6:0] == `INST_TYPE_L ||
                           ie_inst_o[6:0] == `INST_TYPE_S ||
                           ie_inst_o[6:0] == `INST_WRTAG ||
                           ie_inst_o[6:0] == `INST_LDPTR);


    assign hat_enable = alloc_state == ALLOC_WAIT && !hat_valid;
    assign hat_operation = 3'b001;
    assign hat_addr = 32'h0;
    assign hat_size = alloc_size;
    assign hat_tag = alloc_tag;


endmodule
