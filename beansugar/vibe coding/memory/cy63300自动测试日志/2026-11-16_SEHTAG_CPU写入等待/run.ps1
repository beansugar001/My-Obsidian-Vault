$ErrorActionPreference='Stop'
$rtl='D:/project/RISCV-63300/三方测试/Repo_Fanglongrui/rtl'
$ivl='D:/project/tools/iverilog-msys2-v12/ucrt64/bin'
$env:Path="$ivl;$env:Path"
Push-Location -LiteralPath $PSScriptRoot
try {
    $guard = 'checked_commit.v'
    python .\build_sim_adapter.py "$rtl/core"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    python .\add_store_guard.py
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $common=@(Get-ChildItem -LiteralPath "$rtl/core","$rtl/utils" -Filter '*.v' | Where-Object Name -notin 'tinyriscv.v','id.v' | Sort-Object FullName | ForEach-Object FullName)
    $argv=@('-g2012','-s','guarded_cpu_tb','-I',"$rtl/core",'-o','cpu_wait.vvp','guarded_cpu_tb.sv','sim_cpu.v','sim_decode.v',"$rtl/perips/ram.v",$guard)+$common
    $argv | ConvertTo-Json | Set-Content compile_args.json
    & "$ivl/iverilog.exe" @argv 2>&1 | Tee-Object compile.log
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & "$ivl/vvp.exe" -n cpu_wait.vvp 2>&1 | Tee-Object run.log
    if ($LASTEXITCODE -ne 0 -or @(Select-String -LiteralPath run.log -Pattern '^PASS ').Count -ne 1) { exit 1 }
} finally { Pop-Location }
