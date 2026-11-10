# Notes: SRAM CPU execution evidence

## Sources inspected

- `CY63300_I2C_BLACKBOX/00_INDEX.md`: current project status says SRAM execution is not established.
- `runs_local_v116/BBX_V117C_SRAM_ARM_PACED_OLED_20261110_01_20261110_135751/openocd.combined.log` and `result.json`.
- `V117_ARM_PACED_CPU_STORE/v117c_sram_paced_execute.tcl`, `v117_sram.ld`, and `cpu_i2c_paced_probe.c`.
- `V118_FLASH_CANDIDATE/V118_FLASH_OPERATION_RESULT.md`, `cpu_i2c_paced_probe.elf`, and `cpu_i2c_paced_probe.map`.
- `reports_current/V114_PROGBUF_AND_DPC_RESULT_20261110.md`.
- `34_V95_V97B_DPC_AND_FIFO_STOP_RESULT_20261109.md` (archive stub in workspace; its full report is in the previously cited D: archive).
- RISC-V ISA alignment section: <https://docs.riscv.org/reference/isa/v20240411/unpriv/intro.html>.
- OpenOCD RISC-V resume implementation documentation: <https://www.openocd.org/doc/doxygen/html/riscv_8c.html>.

## Reconciled evidence

1. V117C is **not** a proven SRAM execution success. Its OpenOCD log contains `Error: Written PC (0x20008000) does not match read back value (0x0)`. The mailbox read afterward is `4d424f58 / 0000600d`, matching the old V116 marker, not a V117C-unique completion marker. The Tcl accepts that generic old marker, and `result.json` consequently labels the stage `SRAM_PROGRAM_EXECUTED`; this is a false-positive classification.
2. V93 likewise loaded/verified SRAM but reported a PC readback mismatch and no mailbox completion.
3. V95's candidate DPC write was not observed on readback; restoring the original DPC value was observed. V114 reports Program Buffer readback remained zero and DPC writes changed the hart state. These paths are not safe substitutes without a separate, explicitly gated diagnosis.
4. V118's Flash `resume 0` reported PC readback `0x64`. In the exact V118 disassembly, `_start` is at 0; it sets `sp` at 0 and 4, calls `main` at 8, and `main` begins at 0xC. A 32-bit instruction starts at 0x62, so 0x64 is its second 16-bit parcel, not a valid code label. Although RVC relaxes instruction alignment to 16 bits, an aligned address is not automatically an instruction boundary.
5. V117's SRAM linker map reserves code at `0x20008000` (up to a 0x7000 region), mailbox at `0x2000F000`, and stack top `0x20020000`; the 1208-byte image fits. These are prior linker choices, not proof that SRAM contents remain intact now.
6. V117C log reported `misa=0xC`; this differs from prior normal-looking reads and should be captured and reported, not treated as a verified CPU capability value.

## Evidence boundary

No new hardware action occurred while preparing this plan. A successful canary would prove only that the hart can start a fresh SRAM image, execute basic instructions, and write a fresh SRAM completion marker. It would not prove CPU MMIO stores, I2C progress, FIFO consumption, or OLED operation.
