# Task Plan: TinyRISC-V UART/I2C debug handoff

## Goal
Save an evidence-based debug memory and a teacher-ready progress report in the workspace.

## Phases
- [x] Phase 1: Reconcile prior UART, I2C, JTAG, and SBA observations.
- [x] Phase 2: Record confirmed results, corrections, and open questions.
- [x] Phase 3: Write a concise teacher briefing and durable debug memory.

## Key Questions
1. What is confirmed by measurements, and what remains an inference?
2. What is the next test that separates UART firmware/output from I2C hardware behavior?

## Decisions Made
- Treat direct SBA readback as evidence of read access only.
- Do not treat SBCS error fields as trustworthy without confirming implementation; local RTL stores SBCS writes directly and does not update busy/error state.
- Do not recommend more Flash writes; current immediate check is UART after reset and then I2C software bit-bang scan if menu output works.

## Errors Encountered
- Earlier interpretation that zero SBCS error bits proved the SBA transaction succeeded was too strong; local RTL does not implement those status updates.
- Previous I2C hardware probe sequence was not a valid protocol test: it set STOP without START and used I2C_ADDR as a target address despite the manual describing it as the slave's own address.

## Status
**Complete** - memory and teacher report written; latest user result is recorded with the next checks still pending.
