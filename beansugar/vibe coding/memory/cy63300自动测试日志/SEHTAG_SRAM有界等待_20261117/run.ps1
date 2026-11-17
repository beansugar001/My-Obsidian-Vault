$ErrorActionPreference='Stop'
$rtl='D:/project/RISCV-63300/三方测试/Repo_Fanglongrui/rtl'
$ivl='D:/project/tools/iverilog-msys2-v12/ucrt64/bin'
$tool='D:/project/tools/xpack-riscv-none-embed-gcc-8.3.0-2.3/bin/riscv-none-embed-'
$env:Path="$ivl;$env:Path"
Push-Location -LiteralPath $PSScriptRoot
try {
    & ($tool+'gcc.exe') -march=rv32im -mabi=ilp32 -nostdlib '-Wl,-Ttext=0,-e,_start' firmware.S -o firmware.elf
    if($LASTEXITCODE) {exit $LASTEXITCODE}
    & ($tool+'objdump.exe') -d firmware.elf | Set-Content firmware_disasm.log
    if($LASTEXITCODE) {exit $LASTEXITCODE}
    & ($tool+'objcopy.exe') -O binary firmware.elf firmware.bin
    if($LASTEXITCODE) {exit $LASTEXITCODE}
@'
from pathlib import Path
import struct
data=Path("firmware.bin").read_bytes()
words=struct.unpack(f"<{len(data)//4}I",data)
assert len(words)<=128
Path("firmware.hex").write_text("\n".join([f"{w:08x}" for w in words]+["00000013"]*(128-len(words)))+"\n")
'@ | python -
    if($LASTEXITCODE) {exit $LASTEXITCODE}
    $sources=@(Get-ChildItem -LiteralPath "$rtl/core","$rtl/utils" -Filter '*.v' | Sort-Object FullName | ForEach-Object FullName)
    $argsList=@('-g2012','-s','wait_loop_tb','-I',"$rtl/core",'-o','probe.vvp','wait_loop_tb.sv')+$sources
    $argsList | ConvertTo-Json | Set-Content compile_args.json
    & "$ivl/iverilog.exe" @argsList *> compile.log
    if($LASTEXITCODE) {exit $LASTEXITCODE}
    foreach ($scenario in @('reference','force_early_match')) {
        $vvpArgs = @('-n', 'probe.vvp')
        if ($scenario -ne 'reference') { $vvpArgs += "+$scenario" }
        & "$ivl/vvp.exe" @vvpArgs 2>&1 | Tee-Object "$scenario.log"
        if ($LASTEXITCODE -or -not (Select-String -LiteralPath "$scenario.log" -Pattern '^PASS ')) { exit 1 }
    }
} finally { Pop-Location }




