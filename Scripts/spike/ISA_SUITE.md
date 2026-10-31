# RV32I + Zicsr directed suite

Run from the project root in Git Bash or WSL:

```bash
bash Scripts/spike/run_isa_suite.sh
```

The script compiles `isa_suite.S` for RV32I + Zicsr at PC 0, converts the same
ELF text into a 32-bit-word ROM image, runs it in Spike, and then runs the RTL
in XSim. It checks that all 43 implemented instruction forms occur in the
disassembly, that Spike reaches the completion marker with failure code zero,
and that all 31 RTL registers match Spike's final register values. The RTL
testbench also checks the two data words and final `mscratch` value.

| Group | Instruction forms | Checks |
| --- | --- | --- |
| Register ALU | add, sub, sll, slt, sltu, xor, srl, sra, or, and | 101–110 |
| Immediate ALU | addi, slti, sltiu, xori, ori, andi, slli, srli, srai | 111–119 |
| Upper immediate | lui, auipc | 120–121 |
| Branch | beq, bne, blt, bge, bltu, bgeu | 130–141; both outcomes |
| Jump | jal, jalr | 150–153; targets and link registers |
| Data memory | lb, lh, lw, lbu, lhu, sb, sh, sw | 160–174; byte lanes, sign extension, load dependencies |
| CSR | csrrw, csrrs, csrrc, csrrwi, csrrsi, csrrci | 180–197; zero source and six implemented CSR addresses |

On a failure, `x31` holds the numbered check and the script exits nonzero.
Generated ELF, ROM, disassembly, Spike log, and reference register values are
under `Vivado/IsaSuite/`. This directory is ignored by Git. `InstRom` defaults
to the existing `rom_code_CSR.hex`; the suite selects its generated ROM through
the `ROM_FILE` parameter.

The data test accesses 0x8000–0x81ff in Spike. The RTL `DataMem` maps this
window to its 128-word memory; the testbench checks the high address bits to
catch incorrect addresses. Interrupts, traps, ECALL, EBREAK, and MRET are not
part of this suite. This is directed instruction coverage, not exhaustive
operand or pipeline-state coverage.
