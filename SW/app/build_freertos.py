#!/usr/bin/env python3
import os
import struct
import subprocess
import sys

APP_DIR = "/mnt/c/__Project/CPU_OS/SW/app"
KERNEL_DIR = "/mnt/c/__Project/CPU_OS/SW/FreeRTOS-Kernel"
PORT_DIR = f"{KERNEL_DIR}/portable/GCC/RISC-V"
HEX_OUT_SRC = "/mnt/c/__Project/CPU_OS/Src/code/rom_code_FreeRTOS.hex"
HEX_OUT_DESKTOP = "/mnt/c/Users/admin/Desktop/rom_code_FreeRTOS.hex"

TOOLCHAIN_BIN = "/home/gkseorb/xpack-riscv-none-elf-gcc-14.2.0-1/bin"
GCC = f"{TOOLCHAIN_BIN}/riscv-none-elf-gcc"
OBJCOPY = f"{TOOLCHAIN_BIN}/riscv-none-elf-objcopy"
OBJDUMP = f"{TOOLCHAIN_BIN}/riscv-none-elf-objdump"
SIZE = f"{TOOLCHAIN_BIN}/riscv-none-elf-size"

CFLAGS = [
    "-march=rv32i_zicsr",
    "-mabi=ilp32",
    "-Os",
    "-g",
    "-Wall",
    "-nostdlib",
    "-ffreestanding",
    "-ffunction-sections",
    "-fdata-sections",
    f"-I{APP_DIR}",
    f"-I{KERNEL_DIR}/include",
    f"-I{PORT_DIR}",
    f"-I{PORT_DIR}/chip_specific_extensions/RV32I_CLINT_no_extensions",
]

SRCS = [
    f"{APP_DIR}/start.S",
    f"{APP_DIR}/main.c",
    f"{KERNEL_DIR}/tasks.c",
    f"{KERNEL_DIR}/list.c",
    f"{KERNEL_DIR}/queue.c",
    f"{KERNEL_DIR}/portable/MemMang/heap_4.c",
    f"{PORT_DIR}/port.c",
    f"{PORT_DIR}/portASM.S",
]

def run(cmd):
    print("+", " ".join(cmd))
    subprocess.check_call(cmd)

def generate_data_init_asm(data_bin_path, asm_out_path):
    data = b""
    if os.path.exists(data_bin_path):
        with open(data_bin_path, "rb") as f:
            data = f.read()
    # Pad to 4-byte boundary
    while len(data) % 4 != 0:
        data += b"\x00"

    lines = [
        "    .section .text.init_data_ram",
        "    .globl init_data_ram",
        "    .type init_data_ram, @function",
        "init_data_ram:",
        "    la t0, _sdata",
    ]
    for offset in range(0, len(data), 4):
        word = struct.unpack("<I", data[offset:offset+4])[0]
        if word == 0:
            lines.append(f"    sw zero, {offset}(t0)")
        else:
            lines.append(f"    li t1, 0x{word:08x}")
            lines.append(f"    sw t1, {offset}(t0)")
    lines.append("    ret")
    lines.append("")
    with open(asm_out_path, "w", newline="\n") as f:
        f.write("\n".join(lines))
    print(f"Generated {asm_out_path} for {len(data)} bytes ({len(data)//4} words) of .data/.rodata")

def main():
    os.chdir(APP_DIR)

    # Pass 1: Link with empty/weak init_data_ram to extract .data/.rodata bytes
    elf_pass1 = f"{APP_DIR}/freertos_pass1.elf"
    data_bin = f"{APP_DIR}/data_pass1.bin"
    data_init_s = f"{APP_DIR}/data_init.S"

    run([GCC] + CFLAGS + SRCS + [
        f"-T{APP_DIR}/linker.ld",
        "-Wl,--gc-sections",
        "-lgcc",
        "-o", elf_pass1
    ])
    run([OBJCOPY, "-O", "binary", "-j", ".data", elf_pass1, data_bin])
    generate_data_init_asm(data_bin, data_init_s)

    # Pass 2: Link final ELF including generated data_init.S
    elf_final = f"{APP_DIR}/freertos.elf"
    text_bin = f"{APP_DIR}/freertos_text.bin"
    run([GCC] + CFLAGS + SRCS + [data_init_s] + [
        f"-T{APP_DIR}/linker.ld",
        "-Wl,--gc-sections",
        "-Wl,-Map=freertos.map",
        "-lgcc",
        "-o", elf_final
    ])

    run([SIZE, elf_final])
    run([OBJCOPY, "-O", "binary", "-j", ".text", elf_final, text_bin])

    with open(text_bin, "rb") as f:
        code_bytes = f.read()

    while len(code_bytes) % 4 != 0:
        code_bytes += b"\x00"

    num_words = len(code_bytes) // 4
    print(f"Final .text size: {len(code_bytes)} bytes ({num_words} words / 4096 max words)")
    if num_words > 4096:
        raise RuntimeError(f"Code size ({num_words} words) exceeds 4096-word InstRom!")

    hex_lines = []
    for i in range(4096):
        if i < num_words:
            word = struct.unpack("<I", code_bytes[i*4:(i+1)*4])[0]
            hex_lines.append(f"{word:08x}")
        else:
            hex_lines.append("00000013")  # NOP padding

    hex_content = "\n".join(hex_lines) + "\n"
    for out_path in [HEX_OUT_SRC, HEX_OUT_DESKTOP]:
        with open(out_path, "w", newline="\n") as f:
            f.write(hex_content)
        print(f"Wrote {out_path}")

    # Also dump disassembly for verification
    with open(f"{APP_DIR}/freertos.dump", "w") as f:
        subprocess.check_call([OBJDUMP, "-d", "-S", elf_final], stdout=f)
    print(f"Wrote disassembly to {APP_DIR}/freertos.dump")

if __name__ == "__main__":
    main()
