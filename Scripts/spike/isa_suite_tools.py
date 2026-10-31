#!/usr/bin/env python3
"""Prepare the ROM and check Spike's architectural result for isa_suite.S."""

import pathlib
import re
import sys


ROM_WORDS = 1024
MNEMONICS = {
    "add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and",
    "addi", "slti", "sltiu", "xori", "ori", "andi", "slli", "srli", "srai",
    "lb", "lh", "lw", "lbu", "lhu", "sb", "sh", "sw",
    "beq", "bne", "blt", "bge", "bltu", "bgeu",
    "lui", "auipc", "jal", "jalr",
    "csrrw", "csrrs", "csrrc", "csrrwi", "csrrsi", "csrrci",
}


def prepare(binary_path: pathlib.Path, rom_path: pathlib.Path, disasm_path: pathlib.Path) -> None:
    data = binary_path.read_bytes()
    if not data or len(data) % 4:
        raise ValueError("instruction binary must contain whole 32-bit words")
    words = len(data) // 4
    if words > ROM_WORDS:
        raise ValueError(f"program has {words} words; ROM holds {ROM_WORDS}")

    disasm = disasm_path.read_text()
    found = set(re.findall(r"^\s*[0-9a-f]+:\s+[0-9a-f]+\s+([a-z][a-z0-9.]*)", disasm, re.M))
    missing = MNEMONICS - found
    if missing:
        raise ValueError("instruction forms missing from suite: " + ", ".join(sorted(missing)))

    rom_path.write_text("".join(
        f"{int.from_bytes(data[i:i + 4], 'little'):08x}\n"
        for i in range(0, len(data), 4)
    ))
    print(f"ROM: {words}/{ROM_WORDS} words; instruction forms: {len(MNEMONICS)}/{len(MNEMONICS)}")


def check(log_path: pathlib.Path, expected_path: pathlib.Path) -> None:
    regs = [None] * 32
    regs[0] = 0
    mscratch = None
    for line in log_path.read_text().splitlines():
        if not line.startswith("core   0: 3 "):
            continue
        for match in re.finditer(r"\bx([1-9]|[12][0-9]|3[01])\s+0x([0-9a-fA-F]{8})", line):
            regs[int(match.group(1))] = int(match.group(2), 16)
        match = re.search(r"\bc832_mscratch\s+0x([0-9a-fA-F]{8})", line)
        if match:
            mscratch = int(match.group(1), 16)

    if regs[28] != 0x5A5:
        raise ValueError("Spike did not reach the suite completion marker")
    if regs[31] != 0:
        raise ValueError(f"Spike failed check {regs[31]}")
    if mscratch != 13:
        raise ValueError(f"Spike mscratch is {mscratch}, expected 13")
    missing = [index for index in range(1, 32) if regs[index] is None]
    if missing:
        raise ValueError(f"Spike log has no final value for registers {missing}")

    expected_path.write_text("".join(f"{value:08x}\n" for value in regs))
    print("Spike PASS: x31=0, x28=0x5a5, mscratch=13; register reference saved")


if __name__ == "__main__":
    try:
        mode = sys.argv[1]
        if mode == "prepare" and len(sys.argv) == 5:
            prepare(*(pathlib.Path(arg) for arg in sys.argv[2:]))
        elif mode == "check" and len(sys.argv) == 4:
            check(*(pathlib.Path(arg) for arg in sys.argv[2:]))
        else:
            raise ValueError("usage: isa_suite_tools.py prepare BIN ROM DISASM | check LOG EXPECTED")
    except (OSError, ValueError) as exc:
        print(f"ISA suite error: {exc}", file=sys.stderr)
        sys.exit(1)
