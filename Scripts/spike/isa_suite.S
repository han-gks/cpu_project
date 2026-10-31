/* RV32I and Zicsr instructions implemented by Ctrlpath.sv.
 * Runs at PC 0. Data accesses use 0x8000, which the RTL data RAM maps to word 0.
 * x31 is the failure code (0 means pass); x28=0x5a5 means the suite finished.
 */
    .option norvc
    .section .text
    .globl _start

    .macro FAIL id
        li x31, \id
        j done
    .endm

    .macro CHECK reg, value, id
        li x30, \value
        beq \reg, x30, 1f
        FAIL \id
1:
    .endm

    .macro TAKEN op, a, b, id
        \op \a, \b, 1f
        FAIL \id
1:
    .endm

    .macro NOT_TAKEN op, a, b, id
        \op \a, \b, 1f
        j 2f
1:
        FAIL \id
2:
    .endm

_start:
    /* Register file has no reset; initialize every architectural register. */
    addi x1,x0,0
    addi x2,x0,0
    addi x3,x0,0
    addi x4,x0,0
    addi x5,x0,0
    addi x6,x0,0
    addi x7,x0,0
    addi x8,x0,0
    addi x9,x0,0
    addi x10,x0,0
    addi x11,x0,0
    addi x12,x0,0
    addi x13,x0,0
    addi x14,x0,0
    addi x15,x0,0
    addi x16,x0,0
    addi x17,x0,0
    addi x18,x0,0
    addi x19,x0,0
    addi x20,x0,0
    addi x21,x0,0
    addi x22,x0,0
    addi x23,x0,0
    addi x24,x0,0
    addi x25,x0,0
    addi x26,x0,0
    addi x27,x0,0
    addi x28,x0,0
    addi x29,x0,0
    addi x30,x0,0
    addi x31,x0,0

    /* RV32I register ALU: signed/unsigned boundaries and shift mask 31. */
    li x1,0x80000000
    li x2,1
    li x3,-1
    add  x4,x2,x3
    CHECK x4,0,101
    sub  x4,x2,x3
    CHECK x4,2,102
    sll  x4,x2,x3
    CHECK x4,0x80000000,103
    slt  x4,x1,x2
    CHECK x4,1,104
    sltu x4,x1,x2
    CHECK x4,0,105
    xor  x4,x1,x3
    CHECK x4,0x7fffffff,106
    srl  x4,x1,x3
    CHECK x4,1,107
    sra  x4,x1,x3
    CHECK x4,-1,108
    or   x4,x1,x2
    CHECK x4,0x80000001,109
    and  x4,x1,x3
    CHECK x4,0x80000000,110

    /* RV32I immediate ALU. */
    addi  x4,x3,-1
    CHECK x4,-2,111
    slti  x4,x1,0
    CHECK x4,1,112
    sltiu x4,x2,-1
    CHECK x4,1,113
    xori  x4,x1,-1
    CHECK x4,0x7fffffff,114
    ori   x4,x1,1
    CHECK x4,0x80000001,115
    andi  x4,x1,255
    CHECK x4,0,116
    slli  x4,x2,31
    CHECK x4,0x80000000,117
    srli  x4,x1,31
    CHECK x4,1,118
    srai  x4,x1,31
    CHECK x4,-1,119

    /* Upper immediates and PC-relative value. */
    lui x5,0x12345
    CHECK x5,0x12345000,120
auipc_here:
    auipc x6,0
    lui x30,%hi(auipc_here)
    addi x30,x30,%lo(auipc_here)
    beq x6,x30,1f
    FAIL 121
1:

    /* Each branch is exercised in both directions. */
    li x5,1
    li x6,2
    TAKEN     beq,  x2,x5,130
    NOT_TAKEN beq,  x2,x6,131
    TAKEN     bne,  x2,x6,132
    NOT_TAKEN bne,  x2,x5,133
    TAKEN     blt,  x1,x2,134
    NOT_TAKEN blt,  x2,x1,135
    TAKEN     bge,  x2,x1,136
    NOT_TAKEN bge,  x1,x2,137
    TAKEN     bltu, x2,x1,138
    NOT_TAKEN bltu, x1,x2,139
    TAKEN     bgeu, x1,x2,140
    NOT_TAKEN bgeu, x2,x1,141

    /* JAL and JALR: target, link register, and JALR bit-zero clearing. */
    jal x7,jal_target
jal_return:
    FAIL 150
jal_target:
    lui x30,%hi(jal_return)
    addi x30,x30,%lo(jal_return)
    beq x7,x30,1f
    FAIL 151
1:
    lui x8,%hi(jalr_target)
    addi x8,x8,%lo(jalr_target)
    addi x8,x8,1
    jalr x9,0(x8)
jalr_return:
    FAIL 152
jalr_target:
    lui x30,%hi(jalr_return)
    addi x30,x30,%lo(jalr_return)
    beq x9,x30,1f
    FAIL 153
1:

    /* Data at 0x8000 stays separate from instructions in Spike. */
    lui x20,0x8
    sw x0,0(x20)
    li x1,0x11223344
    sw x1,0(x20)
    lw x2,0(x20)
    CHECK x2,0x11223344,160

    li x3,-1
    sb x3,1(x20)
    lw x2,0(x20)
    CHECK x2,0x1122ff44,161
    lb x4,1(x20)
    CHECK x4,-1,162
    lbu x5,1(x20)
    CHECK x5,255,163

    li x6,0x8001
    sh x6,2(x20)
    lw x2,0(x20)
    CHECK x2,0x8001ff44,164
    lh x4,2(x20)
    CHECK x4,0xffff8001,165
    lhu x5,2(x20)
    CHECK x5,0x8001,166

    li x6,0x80
    sb x6,0(x20)
    lb x4,0(x20)
    CHECK x4,-128,167
    lbu x5,0(x20)
    CHECK x5,128,168
    li x6,0x7f
    sb x6,3(x20)
    lb x4,3(x20)
    CHECK x4,127,169

    li x6,0xabcd
    sh x6,0(x20)
    lw x2,0(x20)
    CHECK x2,0x7f01abcd,170
    lh x4,0(x20)
    CHECK x4,0xffffabcd,171
    lhu x5,0(x20)
    CHECK x5,0xabcd,172

    /* Load-use and load-to-store data dependencies. */
    lw x7,0(x20)
    addi x8,x7,1
    CHECK x8,0x7f01abce,173
    lw x7,0(x20)
    sw x7,4(x20)
    lw x9,4(x20)
    CHECK x9,0x7f01abcd,174

    /* All six Zicsr instruction forms and zero-source write suppression. */
    csrrw x0,mscratch,x0
    li x1,0x55
    csrrw x2,mscratch,x1
    CHECK x2,0,180
    csrrs x3,mscratch,x0
    CHECK x3,0x55,181
    li x4,5
    csrrc x5,mscratch,x4
    CHECK x5,0x55,182
    csrrwi x6,mscratch,7
    CHECK x6,0x50,183
    csrrsi x7,mscratch,8
    CHECK x7,7,184
    csrrci x8,mscratch,2
    CHECK x8,15,185
    csrrs x9,mscratch,x0
    CHECK x9,13,186
    csrrsi x10,mscratch,0
    CHECK x10,13,187
    csrrci x11,mscratch,0
    CHECK x11,13,188
    csrrs x12,mscratch,x0
    CHECK x12,13,189

    /* CSR registers implemented by CsrRegisterFile, without traps/IRQs. */
    li x13,0x100
    csrrw x0,mtvec,x13
    csrrs x14,mtvec,x0
    CHECK x14,0x100,190
    li x13,0x104
    csrrw x0,mepc,x13
    csrrs x14,mepc,x0
    CHECK x14,0x104,191
    li x13,3
    csrrw x0,mcause,x13
    csrrs x14,mcause,x0
    CHECK x14,3,192
    li x13,8
    csrrw x0,mie,x13
    csrrs x14,mie,x0
    CHECK x14,8,193
    li x13,0x1808
    csrrw x0,mstatus,x13
    csrrs x14,mstatus,x0
    CHECK x14,0x1808,194

    /* Final memory and CSR state is also compared via Spike's register log. */
    lw x15,0(x20)
    CHECK x15,0x7f01abcd,195
    lw x16,4(x20)
    CHECK x16,0x7f01abcd,196
    csrrs x17,mscratch,x0
    CHECK x17,13,197

done:
    li x28,0x5a5
halt:
    jal x0,halt
