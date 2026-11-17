$ErrorActionPreference='Stop'
$rtl='D:/project/RISCV-63300/三方测试/Repo_Fanglongrui/rtl'
$ivl='D:/project/tools/iverilog-msys2-v12/ucrt64/bin'
$env:Path="$ivl;$env:Path"
Set-Location -LiteralPath $PSScriptRoot
$src=@('-g2012','-s','security_alloc_integration_tb','-I',"$rtl/core",'-o','simulation.vvp','security_alloc_integration_tb.sv',"$rtl/core/mcu_security_system.v","$rtl/core/memory_security_instruction_handler.v","$rtl/core/mcu_memory_security.v","$rtl/perips/ram.v")
$src | ConvertTo-Json | Set-Content compile_args.json
& "$ivl/iverilog.exe" @src 2>&1 | Tee-Object compile.log
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$ivl/vvp.exe" -n simulation.vvp 2>&1 | Tee-Object run.log
if ($LASTEXITCODE -ne 0 -or @(Select-String -LiteralPath run.log -Pattern '^PASS ').Count -ne 3) { exit 1 }
