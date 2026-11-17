$ErrorActionPreference='Stop'
$rtl='D:/project/RISCV-63300/三方测试/Repo_Fanglongrui/rtl'
$ivl='D:/project/tools/iverilog-msys2-v12/ucrt64/bin'
$tool='D:/project/tools/xpack-riscv-none-embed-gcc-8.3.0-2.3/bin/riscv-none-embed-'
$env:Path="$ivl;$env:Path"
Set-Location -LiteralPath $PSScriptRoot
python .\build_sim_adapter.py "$rtl/core"
if($LASTEXITCODE) {exit $LASTEXITCODE}
& ($tool+'gcc.exe') -march=rv32im -mabi=ilp32 -nostdlib '-Wl,-Ttext=0,-e,_start' firmware.S -o firmware.elf
if($LASTEXITCODE) {exit $LASTEXITCODE}
& ($tool+'objdump.exe') -d firmware.elf | Set-Content firmware_disasm.log
& ($tool+'objcopy.exe') -O binary firmware.elf firmware.bin
if($LASTEXITCODE) {exit $LASTEXITCODE}
@'
import struct
from pathlib import Path
data = Path("firmware.bin").read_bytes()
words = struct.unpack(f"<{len(data)//4}I", data)
allocated = [w for w in words if w & 0x7f == 0x0b]
assert allocated == [0x0085950b], allocated
assert len(words) <= 512
Path("firmware.hex").write_text("\n".join([f"{w:08x}" for w in words] + ["00000013"]*(512-len(words))) + "\n")
'@ | python -
if($LASTEXITCODE) {exit $LASTEXITCODE}
$common=@(Get-ChildItem -LiteralPath "$rtl/core","$rtl/utils" -Filter '*.v' | Where-Object Name -notin 'tinyriscv.v','id.v' | Sort-Object FullName | ForEach-Object FullName)
$argv=@('-g2012','-s','native_legal_tb','-I',"$rtl/core",'-o','native_legal.vvp','native_legal_tb.sv','sim_cpu.v','sim_decode.v')+$common
$argv | ConvertTo-Json | Set-Content compile_args.json
& "$ivl/iverilog.exe" @argv 2>&1 | Tee-Object compile.log
if($LASTEXITCODE) {exit $LASTEXITCODE}
& "$ivl/vvp.exe" -n native_legal.vvp 2>&1 | Tee-Object run.log
if($LASTEXITCODE -ne 0 -or @(Select-String -LiteralPath run.log -Pattern '^PASS ').Count -ne 1) {exit 1}
