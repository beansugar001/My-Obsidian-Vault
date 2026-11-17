$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$openocd = 'D:\project\tools\tinyriscv-master\tools\openocd\openocd.exe'
$config = (Resolve-Path -LiteralPath '..\03_experiments\bbx_v76a_100k.cfg').Path.Replace('\','/')
$script = (Resolve-Path -LiteralPath '.\cy_gpio_read.tcl').Path.Replace('\','/')

function Invoke-CyRead($phase) {
    $log = "cy_$phase.log"
    if (Test-Path -LiteralPath $log) {throw "Existing evidence: $log"}
    $cli = @('-f', $config, '-c', "set v145_phase $phase", '-c', "source {$script}")
    @{argv = @($openocd) + $cli; cwd = $PSScriptRoot} |
        ConvertTo-Json | Set-Content -LiteralPath "cy_$($phase)_command.json"
    & $openocd @cli 2>&1 | Tee-Object -FilePath $log | Out-Null
    if ($LASTEXITCODE -ne 0) {return $false}
    return [bool](Select-String -LiteralPath $log -Pattern "^V145_COMPLETE phase=$phase rc=0 .*target_writes=0$")
}

if (Get-Process -Name openocd -ErrorAction SilentlyContinue) {throw 'Existing OpenOCD process'}
if (!(Invoke-CyRead 'gate')) {throw 'CY63300 is not in input mode'}
python .\run_stm32.py load --execute
if ($LASTEXITCODE -ne 0) {exit $LASTEXITCODE}
python .\run_stm32.py arm --execute
if ($LASTEXITCODE -ne 0) {exit $LASTEXITCODE}
$clock = [Diagnostics.Stopwatch]::StartNew()
$cyOk = Invoke-CyRead 'observe'
$left = 22600 - $clock.ElapsedMilliseconds
if ($left -gt 0) {Start-Sleep -Milliseconds $left}
python .\run_stm32.py read --execute
$stmStatus = $LASTEXITCODE
Write-Output "V145_PHASES cy_ok=$cyOk stm_status=$stmStatus"
if (!$cyOk -or $stmStatus -ne 0) {exit 1}
