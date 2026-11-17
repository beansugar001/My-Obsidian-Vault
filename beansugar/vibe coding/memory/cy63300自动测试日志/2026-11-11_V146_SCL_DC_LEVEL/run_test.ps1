param([ValidateSet('prepare','measure')][string]$Action)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$openocd = 'D:\project\tools\tinyriscv-master\tools\openocd\openocd.exe'
$config = (Resolve-Path -LiteralPath '..\03_experiments\bbx_v76a_100k.cfg').Path.Replace('\','/')
$script = (Resolve-Path -LiteralPath '.\cy_gpio_read.tcl').Path.Replace('\','/')

function Invoke-CyRead($phase, $budget) {
    $log = "cy_$phase.log"
    if (Test-Path -LiteralPath $log) {throw "Existing evidence: $log"}
    $cli = @('-f', $config, '-c', "set v146_phase $phase", '-c', "source {$script}")
    @{argv = @($openocd) + $cli; cwd = $PSScriptRoot} |
        ConvertTo-Json | Set-Content -LiteralPath "cy_$($phase)_command.json"
    & $openocd @cli 2>&1 | Tee-Object -FilePath $log | Out-Null
    if ($LASTEXITCODE -ne 0) {return $false}
    $match = Select-String -LiteralPath $log -Pattern "^V146_COMPLETE phase=$phase rc=0 .*target_writes=(\d+)$"
    return [bool]($match -and [int]$match.Matches[0].Groups[1].Value -le $budget)
}

if (Get-Process -Name openocd -ErrorAction SilentlyContinue) {throw 'Existing OpenOCD process'}
if ($Action -eq 'prepare') {
    if (!(Invoke-CyRead 'gate' 2)) {throw 'CY63300 input qualification failed. See cy_gate.log.'}
    python .\run_stm32.py load --execute
    exit $LASTEXITCODE
}
if ($Action -ne 'measure' -or !(Select-String -LiteralPath 'cy_gate.log' -Pattern '^V146_COMPLETE phase=gate rc=0 ')) {
    throw 'Complete preparation before pulling down SCL'
}
python .\run_stm32.py arm --execute
if ($LASTEXITCODE -ne 0) {exit $LASTEXITCODE}
$clock = [Diagnostics.Stopwatch]::StartNew()
$cyOk = Invoke-CyRead 'observe' 0
$left = 33500 - $clock.ElapsedMilliseconds
if ($left -gt 0) {Start-Sleep -Milliseconds $left}
python .\run_stm32.py read --execute
$stmStatus = $LASTEXITCODE
Write-Output "V146_PHASES cy_ok=$cyOk stm_status=$stmStatus"
if (!$cyOk -or $stmStatus -ne 0) {exit 1}
