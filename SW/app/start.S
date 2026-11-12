    .section .init
    .globl _start
    .type _start, @function
_start:
    /* 1. Clear registers to prevent X propagation in simulation */
    li x1, 0
    li x2, 0
    li x3, 0
    li x4, 0
    li x5, 0
    li x6, 0
    li x7, 0
    li x8, 0
    li x9, 0
    li x10, 0
    li x11, 0
    li x12, 0
    li x13, 0
    li x14, 0
    li x15, 0
    li x16, 0
    li x17, 0
    li x18, 0
    li x19, 0
    li x20, 0
    li x21, 0
    li x22, 0
    li x23, 0
    li x24, 0
    li x25, 0
    li x26, 0
    li x27, 0
    li x28, 0
    li x29, 0
    li x30, 0
    li x31, 0

    /* 2. Initialize stack pointer */
    la sp, _estack

    /* 3. Initialize .data/.rodata in Harvard DataMem (0x8000_0000) */
    call init_data_ram

    /* 4. Zero-initialize .bss section in DataMem */
    la a0, _sbss
    la a1, _ebss
    bgeu a0, a1, 2f
1:
    sw zero, 0(a0)
    addi a0, a0, 4
    bltu a0, a1, 1b
2:
    /* 5. Set mtvec to FreeRTOS trap handler */
    la t0, freertos_risc_v_trap_handler
    csrw mtvec, t0

    /* 6. Jump to main() */
    call main

3:
    j 3b

    /* Weak default init_data_ram (overridden by generated data_init.S) */
    .weak init_data_ram
init_data_ram:
    ret
