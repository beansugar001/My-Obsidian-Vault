$ErrorActionPreference='Stop'
$rtl='D:/project/RISCV-63300/三方测试/Repo_Fanglongrui/rtl'
$ivl='D:/project/tools/iverilog-msys2-v12/ucrt64/bin'
$tool='D:/project/tools/xpack-riscv-none-embed-gcc-8.3.0-2.3/bin/riscv-none-embed-'
$env:Path="$ivl;$env:Path"
Push-Location -LiteralPath $PSScriptRoot
try {
    foreach($script in @('build_sim_adapter.py','add_store_guard.py','add_trap_route.py')) {
        python $script "$rtl/core"
        if($LASTEXITCODE) {exit $LASTEXITCODE}
    }
    & ($tool+'gcc.exe') -march=rv32im -mabi=ilp32 -nostdlib '-Wl,-Ttext=0,-e,_start' firmware.S -o firmware.elf
    if($LASTEXITCODE) {exit $LASTEXITCODE}
    & ($tool+'objdump.exe') -d firmware.elf | Set-Content firmware_disasm.log
    & ($tool+'objcopy.exe') -O binary firmware.elf firmware.bin
    if($LASTEXITCODE) {exit $LASTEXITCODE}
@'
from pathlib import Path
import struct
data=Path("firmware.bin").read_bytes()
words=struct.unpack(f"<{len(data)//4}I",data)
assert len(words)<=512
Path("firmware.hex").write_text("\n".join([f"{w:08x}" for w in words]+["00000013"]*(512-len(words)))+"\n")
'@ | python -
    if($LASTEXITCODE) {exit $LASTEXITCODE}
    $common=@(Get-ChildItem -LiteralPath "$rtl/core","$rtl/utils" -Filter '*.v' | Where-Object Name -notin 'tinyriscv.v','id.v' | Sort-Object FullName | ForEach-Object FullName)
    $argv=@('-g2012','-s','guard_trap_tb','-I',"$rtl/core",'-o','sim.vvp','guard_trap_tb.sv','sim_cpu.v','sim_decode.v',"$rtl/perips/ram.v",'checked_commit.v')+$common
    $argv | ConvertTo-Json | Set-Content compile_args.json
    & "$ivl/iverilog.exe" @argv 2>&1 | Tee-Object compile.log
    if($LASTEXITCODE) {exit $LASTEXITCODE}
    foreach($case in @('allow','deny')) {
        & "$ivl/vvp.exe" -n sim.vvp "+$case" 2>&1 | Tee-Object "$case.log"
        if($LASTEXITCODE -or @(Select-String -LiteralPath "$case.log" -Pattern "^PASS $case").Count -ne 1) {exit 1}
    }
} finally { Pop-Location }
