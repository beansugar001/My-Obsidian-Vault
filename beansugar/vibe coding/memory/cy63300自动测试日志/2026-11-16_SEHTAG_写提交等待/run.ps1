$ErrorActionPreference='Stop'
$ivl='D:/project/tools/iverilog-msys2-v12/ucrt64/bin'
$env:Path="$ivl;$env:Path"
Push-Location -LiteralPath $PSScriptRoot
try {
    & "$ivl/iverilog.exe" -g2012 -s checked_commit_tb -o checked_commit.vvp checked_commit.v checked_commit_tb.sv
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & "$ivl/vvp.exe" -n checked_commit.vvp 2>&1 | Tee-Object run.log
    if ($LASTEXITCODE -ne 0 -or @(Select-String -LiteralPath run.log -Pattern '^PASS ').Count -ne 6) { exit 1 }
} finally { Pop-Location }
