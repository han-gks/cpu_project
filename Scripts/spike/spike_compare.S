/* Shared RV32I + Zicsr program for Spike and the RTL CPU. */
    .section .text
    .globl _start
_start:
    csrrw x0, mscratch, x0
    addi  x1, x0, 5
    csrrw x2, mscratch, x1
    csrrs x3, mscratch, x0
    addi  x4, x0, 5
    bne   x3, x4, fail

    csrrwi x5, mscratch, 7
    csrrci x6, mscratch, 2
    csrrsi x7, mscratch, 8
    csrrs  x8, mscratch, x0
    addi   x9, x0, 13
    bne    x8, x9, fail
    bne    x2, x0, fail
    bne    x5, x4, fail
    addi   x10, x0, 7
    bne    x6, x10, fail
    bne    x7, x4, fail

    addi  x31, x0, 0
pass:
    jal   x0, pass
fail:
    addi  x31, x0, 1
    jal   x0, fail
