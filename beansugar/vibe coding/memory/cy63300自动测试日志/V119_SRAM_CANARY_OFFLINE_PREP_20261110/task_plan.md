# Task Plan: SRAM CPU execution diagnosis

## Goal
Prove CPU execution from a fresh SRAM image using an isolated mailbox canary, without confusing SRAM load/verify or stale markers with execution.

## Phases
- [x] Audit V93/V95/V114/V117/V118 evidence; identify the V117C false PASS and reject 0x64 as an entry.
- [x] Create and compile a 76-byte RV32I SRAM canary with unique mailbox markers.
- [x] Verify ELF entry, linker map, disassembly, code/data ranges, and SHA256.
- [ ] Obtain matching OpenOCD RISC-V source or vendor-confirmed DPC/resume semantics; finish exact PC-control-path audit.
- [ ] Only after that audit, request a separate explicit authorization for one real SRAM canary stage.
- [ ] If hardware stage is authorized and passes, plan the next CPU-store/I2C test separately.

## Decisions
- No real hardware call during this preparation.
- Do not repeat V117C or V118 resume and do not test guessed PC values such as 0x64.
- Treat any PC mismatch, OpenOCD Error, missing unique completion words, or unstable hart state as non-PASS and stop.

## Errors / blockers
- OpenOCD binary present (SHA256 recorded), but the matching `riscv.c` / `riscv-013.c` source was not found in the accessible tool project. `help resume` without target setup returned no command details.

## Status
**Offline artifact ready; hardware execution gated** pending PC/DPC semantics audit and new authorization.
