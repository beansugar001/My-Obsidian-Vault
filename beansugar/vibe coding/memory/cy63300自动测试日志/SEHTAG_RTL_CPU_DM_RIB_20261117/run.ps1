$ErrorActionPreference = 'Stop'
$rtl = 'D:/project/tools/tinyriscv-master/rtl'
$ivl = 'D:/project/tools/iverilog-msys2-v12/ucrt64/bin'
$env:Path = "$ivl;$env:Path"
Push-Location -LiteralPath $PSScriptRoot
try {
@'
from hashlib import sha256
from pathlib import Path
import struct
expected = "7E40DA0A3E73E5505784D24F94CAB52A7E46F028CA7646F137371D2346D70441"
for path in Path("..").glob("SEHTAG_CSR*/*/firmware.bin"):
    data = path.read_bytes()
    if sha256(data).hexdigest().upper() == expected:
        break
else:
    raise SystemExit("Pinned mirror firmware missing")
words = struct.unpack(f"<{len(data)//4}I", data)
Path("firmware.hex").write_text("\n".join([f"{w:08x}" for w in words]+["00000001"]*(128-len(words)))+"\n")
'@ | python -
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    $sources = @(Get-ChildItem -LiteralPath "$rtl/core","$rtl/utils" -Filter '*.v' |
        Sort-Object FullName | ForEach-Object FullName) + "$rtl/debug/jtag_dm.v"
    Get-FileHash -LiteralPath $sources | ConvertTo-Json | Set-Content -LiteralPath input_hashes.json -Encoding UTF8
    & "$ivl/iverilog.exe" -g2012 -s firmware_bus_tb -I "$rtl/core" -o firmware_bus.vvp firmware_bus_tb.sv @sources *> compile.log
    if ($LASTEXITCODE) { Get-Content -LiteralPath compile.log; exit $LASTEXITCODE }
    $cases = @('none:overlap:0')
    foreach ($mode in @('dmstatus','sba')) {
        foreach ($phase in @('overlap','after')) {
            foreach ($offset in 0..7) { $cases += "${mode}:${phase}:$offset" }
        }
    }
    $results = foreach ($case in $cases) {
        $mode, $phase, $offset = $case.Split(':')
        $vvpArgs = @('-n', 'firmware_bus.vvp', "+mode=$mode", "+phase=$phase", "+delay=$offset")
        if ($case -eq 'sba:after:0') { $vvpArgs += '+wave' }
        $result = & "$ivl/vvp.exe" @vvpArgs
        $result
        if ($LASTEXITCODE -or @($result | Select-String -Pattern '^RESULT ').Count -ne 1) { exit 1 }
    }
    $results | Tee-Object -FilePath run.log
} finally { Pop-Location }
