#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
out_dir="$repo_dir/Vivado/SpikeCompare"
mkdir -p "$out_dir"

if command -v cygpath >/dev/null 2>&1; then
    # Git Bash: preserve WSL paths when crossing the Windows process boundary.
    wsl_repo="$(MSYS2_ARG_CONV_EXCL='*' wsl.exe -d Ubuntu -- wslpath -u "$(cygpath -m "$repo_dir")" | tr -d '\r')"
    run_tool() { MSYS2_ARG_CONV_EXCL='*' wsl.exe -d Ubuntu -- "$@"; }
else
    # WSL bash (the bash.exe selected by Windows Neovim).
    wsl_repo="$repo_dir"
    run_tool() { "$@"; }
fi
wsl_out="$wsl_repo/Vivado/SpikeCompare"

run_tool riscv64-unknown-elf-gcc \
    -march=rv32i_zicsr -mabi=ilp32 -nostdlib -nostartfiles \
    -Wl,-Ttext=0x80000000 -Wl,-e,_start -Wl,--no-relax -Wl,-N \
    "$wsl_repo/Scripts/spike/spike_compare.S" -o "$wsl_out/compare.elf"

run_tool riscv64-unknown-elf-objcopy \
    -O binary -j .text "$wsl_out/compare.elf" "$wsl_out/compare.bin"

run_tool python3 -c \
    'import pathlib,sys; data=pathlib.Path(sys.argv[1]).read_bytes(); assert len(data)%4==0; pathlib.Path(sys.argv[2]).write_text("".join(format(int.from_bytes(data[i:i+4], "little"), "08x") + "\n" for i in range(0,len(data),4)))' \
    "$wsl_out/compare.bin" "$wsl_out/compare.hex"

run_tool spike \
    --isa=rv32i_zicsr --pcs=0:0x80000000 --instructions=25 \
    -l --log-commits "$wsl_out/compare.elf" > "$out_dir/spike.log" 2>&1

for expected in \
    'x2 +0x00000000' 'x3 +0x00000005' \
    'x5 +0x00000005' 'x6 +0x00000007' \
    'x7 +0x00000005' 'x8 +0x0000000d' \
    'x31 +0x00000000' 'c832_mscratch 0x0000000d'; do
    if ! grep -Eq "$expected" "$out_dir/spike.log"; then
        cat "$out_dir/spike.log"
        echo "Spike FAIL: missing expected result: $expected" >&2
        exit 1
    fi
done

echo 'Spike PASS: x31=0, mscratch=13'
