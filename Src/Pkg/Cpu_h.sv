/**************************************************************
 - Project          : 20260902_CPU
 - File name        : Cpu_h.sv
 - Description      : Common types and enums for CPU
 - Owner            : Daegyu.Han
**************************************************************/
`timescale 1ns / 1ps

package Cpu_h;

    // 1. Opcode (RV32I Base Instruction Set, inst[6:0])
    typedef enum logic [6:0] {
        OP_LOAD     = 7'b000_0011, // I-Type (lw, lh, lb, etc.)
        OP_IMM      = 7'b001_0011, // I-Type (addi, slli, etc.)
        OP_AUIPC    = 7'b001_0111, // U-Type (auipc)
        OP_STORE    = 7'b010_0011, // S-Type (sw, sh, sb)
        OP_OP       = 7'b011_0011, // R-Type (add, sub, etc.)
        OP_LUI      = 7'b011_0111, // U-Type (lui)
        OP_BRANCH   = 7'b110_0011, // B-Type (beq, bne, etc.)
        OP_JALR     = 7'b110_0111, // I-Type (jalr)
        OP_JAL      = 7'b110_1111  // J-Type (jal)
        //OP_SYSTEM = 7'b111_0011  // SYSTEM (csr, ecall, mret 등)
    } opcode_e;

    // 2. ALU
    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b0001,
        ALU_XOR  = 4'b0010,
        ALU_OR   = 4'b0011,
        ALU_AND  = 4'b0100,
        ALU_SLL  = 4'b0101,
        ALU_SRL  = 4'b0110,
        ALU_SRA  = 4'b0111,
        ALU_SLT  = 4'b1000,
        ALU_SLTU = 4'b1001
    } alu_op_e;

    // 3. ALU Source 1
    typedef enum logic [1:0] {
        ALU_SRC1_RS1  = 2'b00,
        ALU_SRC1_PC   = 2'b01,
        ALU_SRC1_ZERO = 2'b10
    } alu_src1_e;

    // 4. ALU Source 2
    typedef enum logic {
        ALU_SRC2_RS2 = 1'b0,
        ALU_SRC2_IMM = 1'b1
    } alu_src2_e;

    // 5. Write Back
    typedef enum logic [1:0] {
        WB_ALU = 2'b00,
        WB_MEM = 2'b01,
        WB_PC4 = 2'b10
    } wb_sel_e;

    // 6. PC Select
    typedef enum logic [1:0] {
        PC_NEXT   = 2'b00,
        PC_BRANCH = 2'b01,
        PC_JAL    = 2'b10,
        PC_JALR   = 2'b11
    } pc_sel_e;

    // 7. Branch (Match RISC-V B-Type funct3)
    typedef enum logic [2:0] {
        BR_EQ  = 3'b000,
        BR_NE  = 3'b001,
        BR_LT  = 3'b100,
        BR_GE  = 3'b101,
        BR_LTU = 3'b110,
        BR_GEU = 3'b111
    } branch_op_e;

    // 8. Immediate
    typedef enum logic [2:0] {
        IMM_I = 3'b000,
        IMM_S = 3'b001,
        IMM_B = 3'b010,
        IMM_U = 3'b011,
        IMM_J = 3'b100,
        IMM_Z = 3'b101  
    } imm_type_e;

    // 9. ByteSelect
    // bit[1:0]: access size, bit[2]: unsigned load
    typedef enum logic [2:0] {
        BYTE   = 3'b000,
        HALF   = 3'b001,
        WORD   = 3'b010,
        BYTE_U = 3'b100,
        HALF_U = 3'b101
    } byte_sel_e;

endpackage
