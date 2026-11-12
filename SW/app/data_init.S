    .section .text.init_data_ram
    .globl init_data_ram
    .type init_data_ram, @function
init_data_ram:
    la t0, _sdata
    li t1, 0x534f5452
    sw t1, 0(t0)
    li t1, 0x000a0d21
    sw t1, 4(t0)
    li t1, 0x3144454c
    sw t1, 8(t0)
    sw zero, 12(t0)
    li t1, 0x3244454c
    sw t1, 16(t0)
    sw zero, 20(t0)
    li t1, 0x00004f49
    sw t1, 24(t0)
    li t1, 0x454c4449
    sw t1, 28(t0)
    sw zero, 32(t0)
    li t1, 0x00000003
    sw t1, 36(t0)
    li t1, 0x000186a0
    sw t1, 40(t0)
    li t1, 0x80001ad0
    sw t1, 44(t0)
    li t1, 0x00000110
    sw t1, 48(t0)
    li t1, 0x80000038
    sw t1, 52(t0)
    li t1, 0xaaaaaaaa
    sw t1, 56(t0)
    li t1, 0x80001b30
    sw t1, 60(t0)
    ret
