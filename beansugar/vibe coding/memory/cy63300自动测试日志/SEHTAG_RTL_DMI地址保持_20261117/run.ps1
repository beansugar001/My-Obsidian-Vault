$ErrorActionPreference = 'Stop'
$rtl = 'D:/project/tools/tinyriscv-master/rtl'
$ivl = 'D:/project/tools/iverilog-msys2-v12/ucrt64/bin'
$env:Path = "$ivl;$env:Path"
Push-Location -LiteralPath $PSScriptRoot
try {
    $sources = @('debug/jtag_dm.v','core/rib.v','utils/full_handshake_rx.v','utils/full_handshake_tx.v') |
        ForEach-Object { Join-Path $rtl $_ }
    Get-FileHash -LiteralPath ($sources + (Join-Path $rtl 'core/defines.v')) |
        ConvertTo-Json | Set-Content -LiteralPath input_hashes.json -Encoding UTF8
    & "$ivl/iverilog.exe" -g2012 -s retained_address_tb -I "$rtl/core" -o retained_address.vvp retained_address_tb.sv @sources *> compile.log
    if ($LASTEXITCODE) { Get-Content -LiteralPath compile.log; exit $LASTEXITCODE }
    & "$ivl/vvp.exe" -n retained_address.vvp 2>&1 | Tee-Object -FilePath run.log
    if ($LASTEXITCODE -or @(Select-String -LiteralPath run.log -Pattern '^PASS ').Count -ne 3) { exit 1 }
} finally { Pop-Location }
