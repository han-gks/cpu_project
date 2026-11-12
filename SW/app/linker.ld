OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 16K
}

SECTIONS
{
    .text :
    {
        KEEP(*(.init))
        *(.text)
        *(.text.*)
        . = ALIGN(4);
    } > ROM

    .data :
    {
        . = ALIGN(4);
        _sdata = .;
        *(.rodata)
        *(.rodata.*)
        *(.srodata)
        *(.srodata.*)
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        . = ALIGN(4);
        _edata = .;
    } > RAM AT > ROM

    _sidata = LOADADDR(.data);

    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    . = ALIGN(16);
    __freertos_irq_stack_top = ORIGIN(RAM) + LENGTH(RAM);
    _estack = ORIGIN(RAM) + LENGTH(RAM) - 512;
}
