$ErrorActionPreference = 'Stop'
$tool = 'D:\project\tools\xpack-riscv-none-embed-gcc-8.3.0-2.3\bin'
python .\generate_frames.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$tool\riscv-none-embed-gcc.exe" -march=rv32i -mabi=ilp32 -Os -Wall -Wextra -Werror -ffreestanding -fno-builtin -fno-pic -msmall-data-limit=0 -nostdlib -nostartfiles '-Wl,--no-relax,-Map=refresh.map' -T flash.ld start.S main.c -o refresh.elf
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$tool\riscv-none-embed-objcopy.exe" -O binary refresh.elf refresh.bin
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$tool\riscv-none-embed-objdump.exe" -d -M no-aliases,numeric refresh.elf | Set-Content .\refresh.disasm.txt -Encoding ascii
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$tool\riscv-none-embed-readelf.exe" -h -S refresh.elf | Set-Content .\refresh.elf.txt -Encoding ascii
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Get-Item .\refresh.bin | Select-Object Name,Length
Get-FileHash .\refresh.bin
Get-Content .\refresh.disasm.txt -TotalCount 16
