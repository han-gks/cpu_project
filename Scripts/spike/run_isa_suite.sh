#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out_dir="$repo_dir/Vivado/IsaSuite"
mkdir -p "$out_dir"

if command -v cygpath >/dev/null 2>&1; then
    wsl_repo="$(MSYS2_ARG_CONV_EXCL='*' wsl.exe -d Ubuntu -- wslpath -u "$(cygpath -m "$repo_dir")" | tr -d '\r')"
    run_tool() { MSYS2_ARG_CONV_EXCL='*' wsl.exe -d Ubuntu -- "$@"; }
else
    wsl_repo="$repo_dir"
    run_tool() { "$@"; }
fi
wsl_out="$wsl_repo/Vivado/IsaSuite"

run_tool riscv64-unknown-elf-gcc \
    -march=rv32i_zicsr -mabi=ilp32 -nostdlib -nostartfiles \
    -Wl,-Ttext=0 -Wl,-e,_start -Wl,--no-relax -Wl,-N \
    "$wsl_repo/Scripts/spike/isa_suite.S" -o "$wsl_out/isa_suite.elf"
run_tool riscv64-unknown-elf-objcopy -O binary -j .text \
    "$wsl_out/isa_suite.elf" "$wsl_out/isa_suite.bin"
run_tool riscv64-unknown-elf-objdump -d -M no-aliases \
    "$wsl_out/isa_suite.elf" > "$out_dir/disasm.txt"
run_tool python3 "$wsl_repo/Scripts/spike/isa_suite_tools.py" prepare \
    "$wsl_out/isa_suite.bin" "$wsl_out/rom.hex" "$wsl_out/disasm.txt"

run_tool spike '-m0:1048576' --no-dm --disable-dtb \
    --isa=rv32i_zicsr --pcs=0:0 --instructions=2000 \
    -l --log-commits --log="$wsl_out/spike.log" "$wsl_out/isa_suite.elf"
run_tool python3 "$wsl_repo/Scripts/spike/isa_suite_tools.py" check \
    "$wsl_out/spike.log" "$wsl_out/expected_regs.hex"

cd "$repo_dir"
bash Scripts/sim.sh -f Scripts/spike/filelist_isa_suite.f -top tb_IsaSuite "$@"
