# Notes: V110B OLED Hello planning

## Latest real-chip evidence
- V110A (2026-11-10) after target replug: IDCODE `0x1E200A6F`; DMSTATUS `0x00430382`; SBCS `0x20040404`.
- `PERI_CLKEN=0x00000000` x3 and `PERI_RST=0x00000000` x3.
- Status `PASS_RESET_CLEAR_CLOCK_OFF`; I²C internal registers skipped while its clock was off; target MMIO writes=0; one halt request.
- Combined log SHA256: `08B758B2A9C392060C82472B1C431541143AD1E66C6E0BA404F4EB9C78C8DBB7`.

## Company ZIP findings
- ZIP `D:\project\RISCV-63300\恢复jtag后\CY63300_flash.zip`; SHA256 `F4AE88059A86A4FF473B653C588527A8ABE316F95E6F681A353CF2D848106D9C`.
- `DRIVER_LIB/src/cj32l01xx_i2c.c`: `I2C_MasterInit()` enables I²C clock, writes dividers as input-minus-one, MCTR, HOLD, both FIFO enables and Master mode; it does not set `I2C_EN`. `I2C_Cmd(ENABLE)` is separate.
- `I2C_WrByte()` only checks TX FIFO not-full then writes FIFO; it does not wait for drain or generate an explicit START register write.
- Some ARM examples use `STOP_MODE=SCL_L` and require `I2C_GenerateStop()`; other variants use `GEN_STOP` for automatic STOP when TX FIFO empties.
- Example application `USER/main.c` doesn't invoke I²C; `I2CTest()` has only a definition/declaration; `I2CTestCase0()` call is commented. No success log/scope/OLED result in ZIP.
- ZIP has incompatible variants: ARM RCC enum maps I²C clock to bit5, device header maps it to bit2; reset enum/header map I²C reset to bit2, while RISC-V design doc uses bit5. RISC-V design doc must control RISC-V tests.
- ARM examples use PB0/PB1 AF2, while this RISC-V board uses Pad8/Pad9 = GPIOB2/B3 AF3. One CY63300 ARM test sets I²C pins push-pull; do not copy that electrical mode.

## Known prior I²C experiment
- V109F before the later reset attempt: CLKEN `0x21`, RST `0`, pins Pad8/9 AF3/open-drain/released, controller enabled, `MCTR=0x2` (GEN_STOP mode), address `0x3C`; one FIFO write `0x00` remained queued (`FIFO_STA=0x104`), `STATUS=WORK (1)`, `RAW_INTR=0`, GPIO IDR=`0x2C`.
- This was before V109G set the soft-reset bit. V109G/V109I then failed to clear `PERI_RST=0x20`. V110A power-cycle baseline cleared reset; it did not test a new bus transfer.
- Because V109F already used GEN_STOP and correct RISC-V AF3/open-drain configuration, simply changing STOP or repeating the same byte is not a sufficient root-cause test. Observe transaction progress and stop on a single stall.

## Pin and wiring gate
- RISC-V Pad8=SCL / GPIOB2, Pad9=SDA / GPIOB3, AF3.
- OLED wiring: common GND, VCC=3.3V, SCL=Pad8, SDA=Pad9.
- If disconnected, attach only while target power is off. If already connected, leave wiring untouched.

## Next discriminating sequence
1. Reconfirm cable/OLED present and make a new read-only preflight.
2. If gates remain 0/0, one controlled `PERI_CLKEN=0x21` write (GPIO bit0 + I²C bit5); read back independently.
3. Reapply known Pad8/9 settings and confirm IDR bits 2/3 high.
4. Inspect reset-state I²C registers first; preserve defaults unless evidence says otherwise.
5. Configure from RISC-V manual using ARM call order, slow/reliable divider, 7-bit OLED address `0x3C` or `0x3D` only as confirmed by module. Keep I²C_EN off until FIFO/mode/address preconditions are read back.
6. One-byte probe; collect FIFO count, WORK, RAW interrupt, and optionally scope. TX count drains + WORK returns idle + no NACK is the minimum software pass. If it remains queued, stop without changing state.
7. Only on a clear pass, send OLED init commands and then `Hello`; record each outcome.

