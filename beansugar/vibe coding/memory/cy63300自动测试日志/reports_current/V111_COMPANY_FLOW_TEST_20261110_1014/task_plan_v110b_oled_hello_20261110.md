# V110B onward: CY63300 OLED Hello test plan

## Goal
After the V110A post-power-cycle baseline, use the documented RISC-V register map and the ARM software sequence as a flow reference to send a verified I²C transaction and then display `Hello` on the 4-pin OLED.

## Phases
- [x] Phase 1: Read company ZIP and compare ARM I²C code with RISC-V mapping.
- [x] Phase 2: Run V110A post-repower read-only baseline.
- [ ] Phase 3: Confirm OLED wiring is connected with target power off before attaching; leave it connected if already wired.
- [ ] Phase 4: New-stage read-only preflight: JTAG/TAP, hart/DMSTATUS/SBCS, PERI_CLKEN and PERI_RST.
- [ ] Phase 5: Enable GPIO + I²C clocks once (`PERI_CLKEN <- 0x21` only if still 0); independently verify.
- [ ] Phase 6: Configure Pad8/Pad9 as GPIOB2/B3 AF3, open-drain, released high; verify register fields and input levels.
- [ ] Phase 7: Read I²C reset defaults; configure only confirmed 7-bit master settings and FIFO; keep divider conservative; enable I²C only after FIFO setup.
- [ ] Phase 8: Send one OLED control byte (`0x00`) to the confirmed 7-bit OLED address; check FIFO drain, WORK/status, NACK/STOP and line input state. Stop on any anomaly.
- [ ] Phase 9: If the byte transaction passes, run the STM32-derived OLED initialization sequence, send `Hello`, then verify display output and retain logs.

## Guardrails
- Each hardware stage gets a unique marker, immutable raw logs, command line, hashes and archive copy under the user's Obsidian test-log directory.
- Before each target-write stage, do a fresh read-only preflight.
- Preserve unrelated register bits. Do not reuse consumed markers.
- A failed readback, unexpected reset/clock bit, busy/error, I²C NACK or stalled FIFO ends that stage immediately; keep the resulting state and evidence.
- No automatic retry, reset pulse, resume, Flash/NVR write or power cycle. Any physical power cycle is performed by the user; after it, begin at a new read-only stage.
- Never use the ARM header's disputed bit numbers or GPIO mapping blindly. RISC-V design documentation controls RISC-V register/pad mapping.

## Current gate
V110A passed: `PERI_CLKEN=0`, `PERI_RST=0` (each stable three times); target MMIO writes=0. The next action depends on OLED being connected safely; actual I²C clock remains off.

## Status (updated after V110B and V110C0)
- V110B0–B5 were run. The OLED was connected. One `0x00` was enqueued to TX FIFO, but the queue did not drain; the stage stopped without a second FIFO write or reset.
- V110C0 is a new read-only snapshot. It confirms the same live state: CLKEN=`0x21`, RST=`0`, MODULE_CTRL=`0x0F`, FIFO_STA=`0x104` (TX count 1), STATUS=`1` (WORK), RAW=`0`. No target MMIO writes in C0. CPU was initially running and was halted once for the snapshot.
- The company `CY63300.c::I2CTest()` was audited. It uses PB0/PB1 AF2 push-pull, STOP=SCL_L/manual-stop, address `0x55`, queues four bytes, and immediately disables the I²C clock without waiting for drain or issuing STOP. It is not a safe verbatim recipe for this RISC-V board/OLED.
- See `51_COMPANY_I2CTEST_REVIEW_AND_V110C0_STATE_20261110.md` for source hashes, exact evidence, and the adapted next-step criteria.

## Current gate
The I²C controller is still active with one queued byte. Do not append data or change the controller while this state persists. Before any new company-flow experiment, the target must be cleanly power-cycled (OLED may remain connected), then start a fresh read-only baseline. Translate the ARM init order to the RISC-V board's Pad8/Pad9 AF3 open-drain wiring; use the OLED's 7-bit address, not `0x55`; add completion polling and an explicit documented STOP before any clock gating.
