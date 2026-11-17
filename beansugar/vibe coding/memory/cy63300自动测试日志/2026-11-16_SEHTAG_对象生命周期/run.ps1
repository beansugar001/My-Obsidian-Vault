$ErrorActionPreference='Stop'
$rtl='D:/project/RISCV-63300/三方测试/Repo_Fanglongrui/rtl'
$tool='D:/project/tools/iverilog-msys2-v12/ucrt64/bin'
$env:Path="$tool;$env:Path"
Set-Location -LiteralPath $PSScriptRoot
$argv=@('-g2012','-s','lifecycle_tb','-I',"$rtl/core",'-o','lifecycle.vvp','lifecycle_tb.sv',"$rtl/core/bnbcache.v")
$argv | ConvertTo-Json | Set-Content compile_args.json
& "$tool/iverilog.exe" @argv 2>&1 | Tee-Object compile.log
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$tool/vvp.exe" -n lifecycle.vvp 2>&1 | Tee-Object lifecycle_run.log
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$log=Get-Content lifecycle_run.log
if (@($log -match '^PASS ').Count -ne 4 -or $log -match 'FAIL|FATAL|Error:') { exit 1 }
