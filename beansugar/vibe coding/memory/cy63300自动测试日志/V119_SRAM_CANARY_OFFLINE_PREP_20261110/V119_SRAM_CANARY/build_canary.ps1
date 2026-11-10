$ErrorActionPreference = 'Stop'
$tool = 'D:\project\tools\xpack-riscv-none-embed-gcc-8.3.0-2.3\bin'
$gcc = Join-Path $tool 'riscv-none-embed-gcc.exe'
$objcopy = Join-Path $tool 'riscv-none-embed-objcopy.exe'
$objdump = Join-Path $tool 'riscv-none-embed-objdump.exe'
$size = Join-Path $tool 'riscv-none-embed-size.exe'
$nm = Join-Path $tool 'riscv-none-embed-nm.exe'
if (!(Test-Path -LiteralPath $gcc) -or !(Test-Path -LiteralPath $objcopy) -or !(Test-Path -LiteralPath $objdump)) { throw 'RISCV_TOOLCHAIN_MISSING' }
Push-Location $PSScriptRoot
try {
  & $gcc -march=rv32i -mabi=ilp32 -mno-relax -nostdlib -nostartfiles '-Wl,--no-relax' '-Wl,-T,sram_canary.ld' '-Wl,-Map=sram_canary.map' 'sram_canary.S' '-o' 'sram_canary.elf'
  if ($LASTEXITCODE -ne 0) { throw "LINK_FAILED:$LASTEXITCODE" }
  & $objcopy -O binary 'sram_canary.elf' 'sram_canary.bin'
  if ($LASTEXITCODE -ne 0) { throw "OBJCOPY_FAILED:$LASTEXITCODE" }
  & $objdump -d -M no-aliases 'sram_canary.elf' | Set-Content -LiteralPath 'sram_canary.disasm.txt' -Encoding Ascii
  if ($LASTEXITCODE -ne 0) { throw "OBJDUMP_FAILED:$LASTEXITCODE" }
  & $nm -n 'sram_canary.elf' | Set-Content -LiteralPath 'sram_canary.symbols.txt' -Encoding Ascii
  if ($LASTEXITCODE -ne 0) { throw "NM_FAILED:$LASTEXITCODE" }
  & $size 'sram_canary.elf' | Set-Content -LiteralPath 'sram_canary.size.txt' -Encoding Ascii
  if ($LASTEXITCODE -ne 0) { throw "SIZE_FAILED:$LASTEXITCODE" }
  Get-FileHash -Algorithm SHA256 'sram_canary.S','sram_canary.ld','sram_canary.elf','sram_canary.bin','sram_canary.disasm.txt','sram_canary.map' | Format-Table Path,Hash -AutoSize
} finally { Pop-Location }
