
`include "defines.v"


module id(

	input wire rst,


    input wire[`InstBus] inst_i,
    input wire[`InstAddrBus] inst_addr_i,


    input wire[`RegBus] reg1_rdata_i,
    input wire[`RegBus] reg2_rdata_i,


    input wire[`RegBus] csr_rdata_i,


    input wire ex_jump_flag_i,


    output reg[`RegAddrBus] reg1_raddr_o,
    output reg[`RegAddrBus] reg2_raddr_o,


    output reg[`MemAddrBus] csr_raddr_o,


    output reg[`MemAddrBus] op1_o,
    output reg[`MemAddrBus] op2_o,
    output reg[`MemAddrBus] op1_jump_o,
    output reg[`MemAddrBus] op2_jump_o,
    output reg[`InstBus] inst_o,
    output reg[`InstAddrBus] inst_addr_o,
    output reg[`RegBus] reg1_rdata_o,
    output reg[`RegBus] reg2_rdata_o,
    output reg reg_we_o,
    output reg[`RegAddrBus] reg_waddr_o,
    output reg csr_we_o,
    output reg[`RegBus] csr_rdata_o,
    output reg[`MemAddrBus] csr_waddr_o,

    output reg is_security_inst_o,

    input wire reg1_tag_i,
    input wire reg2_tag_i,
    input wire[`SEC_LEVEL_BUS] reg1_sec_level_i,
    input wire[`SEC_LEVEL_BUS] reg2_sec_level_i,
    input wire reg1_trust_i,
    input wire reg2_trust_i,

    output reg reg1_tag_o,
    output reg reg2_tag_o,
    output reg[`SEC_LEVEL_BUS] reg1_sec_level_o,
    output reg[`SEC_LEVEL_BUS] reg2_sec_level_o,
    output reg reg1_trust_o,
    output reg reg2_trust_o,

    output reg tag_we_o,
    output reg[`ExtTagBus] ext_tag_o,
    output reg[`RegAddrBus] tag_addr_o,


    input wire[`RegBus] reg3_rdata_i,
    input wire reg3_tag_i,
    input wire[`SEC_LEVEL_BUS] reg3_sec_level_i,
    input wire reg3_trust_i,
    output reg[`RegAddrBus] reg3_raddr_o,
    output reg[`RegBus] reg3_rdata_o,
    output reg reg3_tag_o,
    output reg[`SEC_LEVEL_BUS] reg3_sec_level_o,
    output reg reg3_trust_o,
    output reg[`MemAddrBus] op3_o
);

    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];
    wire[6:0] funct7 = inst_i[31:25];
    wire[4:0] rd = inst_i[11:7];
    wire[4:0] rs1 = inst_i[19:15];
    wire[4:0] rs2 = inst_i[24:20];
    wire[4:0] rs3 = inst_i[31:27];


    always @ (*) begin
        inst_o = inst_i;
        inst_addr_o = inst_addr_i;
        reg1_rdata_o = reg1_rdata_i;
        reg2_rdata_o = reg2_rdata_i;
        reg3_rdata_o = reg3_rdata_i;

        reg1_tag_o = reg1_tag_i;
        reg2_tag_o = reg2_tag_i;
        reg3_tag_o = reg3_tag_i;
        reg1_sec_level_o = reg1_sec_level_i;
        reg2_sec_level_o = reg2_sec_level_i;
        reg3_sec_level_o = reg3_sec_level_i;
        reg1_trust_o = reg1_trust_i;
        reg2_trust_o = reg2_trust_i;
        reg3_trust_o = reg3_trust_i;

        csr_rdata_o = csr_rdata_i;
        csr_raddr_o = `ZeroWord;
        csr_waddr_o = `ZeroWord;
        csr_we_o = `WriteDisable;
        op1_o = `ZeroWord;
        op2_o = `ZeroWord;
        op3_o = `ZeroWord;
        op1_jump_o = `ZeroWord;
        op2_jump_o = `ZeroWord;

        tag_we_o = `WriteDisable;
        ext_tag_o = 4'h0;
        tag_addr_o = `ZeroReg;
        reg3_raddr_o = `ZeroReg;
        is_security_inst_o = 1'b0;

        case (opcode)
            7'h0b: begin
                reg1_raddr_o = rs1;
                reg2_raddr_o = `ZeroReg;
                reg_waddr_o = rd;
                reg_we_o = `WriteDisable;
            end
            `INST_TYPE_I: begin
                case (funct3)
                    `INST_ADDI, `INST_SLTI, `INST_SLTIU, `INST_XORI, `INST_ORI, `INST_ANDI, `INST_SLLI, `INST_SRI: begin
                        reg_we_o = `WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                        reg1_raddr_o = `ZeroReg;
                        reg2_raddr_o = `ZeroReg;
                    end
                endcase
            end
            `INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `INST_ADD_SUB, `INST_SLL, `INST_SLT, `INST_SLTU, `INST_XOR, `INST_SR, `INST_OR, `INST_AND: begin
                            reg_we_o = `WriteEnable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_rdata_i;
                            op2_o = reg2_rdata_i;
                        end
                        default: begin
                            reg_we_o = `WriteDisable;
                            reg_waddr_o = `ZeroReg;
                            reg1_raddr_o = `ZeroReg;
                            reg2_raddr_o = `ZeroReg;
                        end
                    endcase
                end else if (funct7 == 7'b0000001) begin
                    case (funct3)
                        `INST_MUL, `INST_MULHU, `INST_MULH, `INST_MULHSU: begin
                            reg_we_o = `WriteEnable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_rdata_i;
                            op2_o = reg2_rdata_i;
                        end
                        `INST_DIV, `INST_DIVU, `INST_REM, `INST_REMU: begin
                            reg_we_o = `WriteDisable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_rdata_i;
                            op2_o = reg2_rdata_i;
                            op1_jump_o = inst_addr_i;
                            op2_jump_o = 32'h4;
                        end
                        default: begin
                            reg_we_o = `WriteDisable;
                            reg_waddr_o = `ZeroReg;
                            reg1_raddr_o = `ZeroReg;
                            reg2_raddr_o = `ZeroReg;
                        end
                    endcase
                end else begin
                    reg_we_o = `WriteDisable;
                    reg_waddr_o = `ZeroReg;
                    reg1_raddr_o = `ZeroReg;
                    reg2_raddr_o = `ZeroReg;
                end
            end
            `INST_TYPE_L: begin
                case (funct3)
                    `INST_LB, `INST_LH, `INST_LW, `INST_LBU, `INST_LHU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `ZeroReg;
                        reg_we_o = `WriteEnable;
                        reg_waddr_o = rd;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};

                    end
                    default: begin
                        reg1_raddr_o = `ZeroReg;
                        reg2_raddr_o = `ZeroReg;
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                    end
                endcase
            end
            `INST_TYPE_S: begin
                case (funct3)
                    `INST_SB, `INST_SW, `INST_SH: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                    end
                    default: begin
                        reg1_raddr_o = `ZeroReg;
                        reg2_raddr_o = `ZeroReg;
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                    end
                endcase
            end
            `INST_TYPE_B: begin
                case (funct3)
                    `INST_BEQ, `INST_BNE, `INST_BLT, `INST_BGE, `INST_BLTU, `INST_BGEU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = reg2_rdata_i;
                        op1_jump_o = inst_addr_i;
                        op2_jump_o = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                    end
                    default: begin
                        reg1_raddr_o = `ZeroReg;
                        reg2_raddr_o = `ZeroReg;
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                    end
                endcase
            end
            `INST_JAL: begin
                reg_we_o = `WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = inst_addr_i;
                op2_jump_o = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
            end
            `INST_JALR: begin
                reg_we_o = `WriteEnable;
                reg1_raddr_o = rs1;
                reg2_raddr_o = `ZeroReg;
                reg_waddr_o = rd;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = reg1_rdata_i;
                op2_jump_o = {{20{inst_i[31]}}, inst_i[31:20]};
            end
            `INST_LUI: begin
                reg_we_o = `WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
                op1_o = {inst_i[31:12], 12'b0};
                op2_o = `ZeroWord;
            end
            `INST_AUIPC: begin
                reg_we_o = `WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
                op1_o = inst_addr_i;
                op2_o = {inst_i[31:12], 12'b0};
            end
            `INST_NOP_OP: begin
                reg_we_o = `WriteDisable;
                reg_waddr_o = `ZeroReg;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
            end
            `INST_FENCE: begin
                reg_we_o = `WriteDisable;
                reg_waddr_o = `ZeroReg;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
                op1_jump_o = inst_addr_i;
                op2_jump_o = 32'h4;
            end
            `INST_CSR: begin
                reg_we_o = `WriteDisable;
                reg_waddr_o = `ZeroReg;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
                csr_raddr_o = {20'h0, inst_i[31:20]};
                csr_waddr_o = {20'h0, inst_i[31:20]};
                case (funct3)
                    `INST_CSRRW, `INST_CSRRS, `INST_CSRRC: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `ZeroReg;
                        reg_we_o = `WriteEnable;
                        reg_waddr_o = rd;
                        csr_we_o = `WriteEnable;
                    end
                    `INST_CSRRWI, `INST_CSRRSI, `INST_CSRRCI: begin
                        reg1_raddr_o = `ZeroReg;
                        reg2_raddr_o = `ZeroReg;
                        reg_we_o = `WriteEnable;
                        reg_waddr_o = rd;
                        csr_we_o = `WriteEnable;
                    end
                    default: begin
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                        reg1_raddr_o = `ZeroReg;
                        reg2_raddr_o = `ZeroReg;
                        csr_we_o = `WriteDisable;
                    end
                endcase
            end

            `INST_SETSL: begin
                reg_we_o = `WriteDisable;
                reg_waddr_o = rd;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
                tag_we_o = `WriteEnable;
                tag_addr_o = rd;

                ext_tag_o = {
                    reg1_tag_i,
                    inst_i[21:20],
                    reg1_trust_i
                };
                is_security_inst_o = 1'b1;
            end


            `INST_SETRUST: begin
                reg_we_o = `WriteDisable;
                reg_waddr_o = rd;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
                tag_we_o = `WriteEnable;
                tag_addr_o = rd;

                ext_tag_o = {
                    reg1_tag_i,
                    reg1_sec_level_i,
                    inst_i[20]
                };
                is_security_inst_o = 1'b1;
            end

            `INST_WRTAG: begin
                reg_we_o = `WriteDisable;
                reg_waddr_o = rd;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
                tag_we_o = `WriteEnable;
                ext_tag_o = {
                    inst_i[20],
                    reg1_sec_level_i,
                    reg1_trust_i
                };
                tag_addr_o = rd;
                is_security_inst_o = 1'b1;
            end

            `INST_WRSPREG: begin
                reg1_raddr_o = rs1;
                reg2_raddr_o = `ZeroReg;
                reg_we_o = `WriteDisable;
                reg_waddr_o = `ZeroReg;
                op1_o = reg1_rdata_i;
                op2_o = `ZeroWord;
                is_security_inst_o = 1'b1;
            end

            `INST_RDSPREG: begin


                    reg_we_o = `WriteEnable;
                    reg_waddr_o = rd;
                    reg1_raddr_o = `ZeroReg;
                    reg2_raddr_o = `ZeroReg;
                    op1_o = `ZeroWord;
                    op2_o = `ZeroWord;
                    is_security_inst_o = 1'b1;
            end

            `INST_WRPLM: begin
                reg1_raddr_o = rs1;
                reg2_raddr_o = rs2;
                reg_we_o = `WriteDisable;
                reg_waddr_o = `ZeroReg;
                op1_o = reg1_rdata_i;
                op2_o = reg2_rdata_i;
                is_security_inst_o = 1'b1;

            end

            `INST_LDBNB: begin
                reg1_raddr_o = rs1;
                reg2_raddr_o = `ZeroReg;
                reg_we_o = `WriteDisable;
                reg_waddr_o = `ZeroReg;
                op1_o = reg1_rdata_i;
                op2_o = `ZeroWord;
                tag_addr_o = rd;
                is_security_inst_o = 1'b1;
            end

            `INST_LDPTR: begin
                reg1_raddr_o = rs1;
                reg2_raddr_o = `ZeroReg;
                reg_we_o = `WriteEnable;
                reg_waddr_o = rd;
                op1_o = reg1_rdata_i;
                op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                tag_we_o = `WriteEnable;
                ext_tag_o = {
                    `TagEnable,
                    reg1_sec_level_i,
                    reg1_trust_i
                };

                tag_addr_o = rd;
                is_security_inst_o = 1'b1;
            end

            `INST_FNST: begin
                reg1_raddr_o = rs1;
                reg2_raddr_o = rs2;
                reg_we_o = `WriteDisable;
                reg_waddr_o = `ZeroReg;
                op1_o = reg1_rdata_i;
                op2_o = reg2_rdata_i;
                 is_security_inst_o = 1'b1;
            end

            `INST_FNLD: begin
                reg1_raddr_o = rs1;
                reg2_raddr_o = `ZeroReg;
                reg_we_o = `WriteEnable;
                reg_waddr_o = rd;
                op1_o = reg1_rdata_i;
                op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                is_security_inst_o = 1'b1;
            end
            default: begin
                reg_we_o = `WriteDisable;
                reg_waddr_o = `ZeroReg;
                reg1_raddr_o = `ZeroReg;
                reg2_raddr_o = `ZeroReg;
            end
        endcase
    end

endmodule
