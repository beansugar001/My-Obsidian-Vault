
$ErrorActionPreference='Stop'
$rtl='D:/project/RISCV-63300/三方测试/Repo_Fanglongrui/rtl'
$tool='D:/project/tools/iverilog-msys2-v12/ucrt64/bin'
$env:Path="$tool;$env:Path"
Set-Location -LiteralPath $PSScriptRoot
$argv=@('-g2012','-s','rib_ram_decision_tb','-I',"$rtl/core",'-o','rib_ram_decision.vvp','rib_ram_decision_tb.sv')
$argv+=@(Get-ChildItem -LiteralPath "$rtl/core","$rtl/utils" -Filter '*.v' | Sort-Object FullName | ForEach-Object FullName)
$argv += "$rtl/perips/ram.v"
$argv | ConvertTo-Json | Set-Content compile_args.json
& "$tool/iverilog.exe" @argv 2>&1 | Tee-Object compile.log
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$tool/vvp.exe" -n rib_ram_decision.vvp 2>&1 | Tee-Object run.log
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$log=Get-Content run.log
if (@($log -match '^PASS ').Count -ne 2 -or $log -match 'FAIL|FATAL|Error:') { exit 1 }


