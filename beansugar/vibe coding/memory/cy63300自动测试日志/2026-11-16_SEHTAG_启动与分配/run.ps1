$ErrorActionPreference='Stop'
$rtl='D:/project/RISCV-63300/三方测试/Repo_Fanglongrui/rtl'
$ivl='D:/project/tools/iverilog-msys2-v12/ucrt64/bin'
$gcc='D:/project/tools/xpack-riscv-none-embed-gcc-8.3.0-2.3/bin/riscv-none-embed-'
$env:Path="$ivl;$env:Path"
Set-Location -LiteralPath $PSScriptRoot
& ($gcc+'gcc.exe') -march=rv32im -mabi=ilp32 -nostdlib '-Wl,-Ttext=0,-e,_start' firmware.S -o firmware.elf
if($LASTEXITCODE) {exit $LASTEXITCODE}
& ($gcc+'objdump.exe') -d firmware.elf | Set-Content firmware_disasm.log
& ($gcc+'objcopy.exe') -O binary firmware.elf firmware.bin
if($LASTEXITCODE) {exit $LASTEXITCODE}
@'
from pathlib import Path
import struct
data = Path('firmware.bin').read_bytes()
assert 0 < len(data) <= 512 and len(data) % 4 == 0
words = struct.unpack(f"<{len(data)//4}I", data)
Path('firmware.hex').write_text('\n'.join([f"{word:08x}" for word in words] + ['00000013']*(128-len(words))) + '\n')
'@ | python -
if($LASTEXITCODE) {exit $LASTEXITCODE}
$files=@(Get-ChildItem -LiteralPath "$rtl/core","$rtl/utils" -Filter '*.v' | Sort-Object FullName | ForEach-Object FullName)
foreach($top in 'boot_tb','hat_tb') {
  $argsList=@('-g2012','-s',$top,'-I',"$rtl/core",'-o',"$top.vvp","$top.sv")+$files
  $argsList | ConvertTo-Json | Set-Content "$top.compile_args.json"
  & "$ivl/iverilog.exe" @argsList 2>&1 | Tee-Object "$top.compile.log"
  if($LASTEXITCODE) {exit $LASTEXITCODE}
  & "$ivl/vvp.exe" -n "$top.vvp" 2>&1 | Tee-Object "$top.run.log"
  if($LASTEXITCODE -or @(Select-String -LiteralPath "$top.run.log" -Pattern '^PASS ').Count -ne 1) {exit 1}
}
