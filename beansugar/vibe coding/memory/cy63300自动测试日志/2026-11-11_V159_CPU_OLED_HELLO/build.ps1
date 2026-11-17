$ErrorActionPreference = 'Stop'
$tool = 'D:\project\tools\xpack-riscv-none-embed-gcc-8.3.0-2.3\bin'
python .\generate_frames.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$tool\riscv-none-embed-gcc.exe" -march=rv32i -mabi=ilp32 -Os -Wall -Wextra -Werror -ffreestanding -fno-builtin -fno-pic -msmall-data-limit=0 -nostdlib -nostartfiles '-Wl,--no-relax,-Map=hello.map' -T flash.ld start.S main.c -o hello.elf
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$tool\riscv-none-embed-objcopy.exe" -O binary hello.elf hello.bin
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$tool\riscv-none-embed-objdump.exe" -d -M no-aliases,numeric hello.elf | Set-Content .\hello.disasm.txt -Encoding ascii
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$tool\riscv-none-embed-readelf.exe" -h -S hello.elf | Set-Content .\hello.elf.txt -Encoding ascii
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Get-Item .\hello.bin | Select-Object Name,Length
Get-FileHash .\hello.bin
Get-Content .\hello.disasm.txt -TotalCount 16
