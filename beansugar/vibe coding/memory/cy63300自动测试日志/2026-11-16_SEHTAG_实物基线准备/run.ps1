$ErrorActionPreference='Stop'
$repo='D:/project/RISCV-63300/三方测试/Repo_Fanglongrui'
$ivl='D:/project/tools/iverilog-msys2-v12/ucrt64/bin'
$gcc='D:/project/tools/xpack-riscv-none-embed-gcc-8.3.0-2.3/bin/riscv-none-embed-gcc.exe'
$env:Path="$ivl;$env:Path"
Set-Location -LiteralPath $PSScriptRoot
$rtl="$repo/rtl/core"
& "$ivl/iverilog.exe" -g2012 -s csr_enable_tb -I $rtl -o csr_enable.vvp csr_enable_tb.sv "$rtl/csr_reg.v" 2>&1 | Tee-Object csr_compile.log
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$ivl/vvp.exe" -n csr_enable.vvp 2>&1 | Tee-Object csr_enable.log
if ($LASTEXITCODE -ne 0 -or @(Select-String -LiteralPath csr_enable.log -Pattern '^PASS ').Count -ne 2) { exit 1 }
& $gcc --version | Select-Object -First 1 | Set-Content compiler_version.log
$compile=@('-march=rv32im','-mabi=ilp32','-O2','-ffreestanding','-I',"$repo/sehtag_experiment_starter/common",'-c','native_compile_probe.c')
& $gcc @compile -o stub_probe.o 2>&1 | Tee-Object stub_compile.log
$stub_rc=$LASTEXITCODE
& $gcc @compile -DSEHTAG_NATIVE=1 -o native_probe.o 2>&1 | Tee-Object native_compile.log
$native_rc=$LASTEXITCODE
[ordered]@{csr_simulation='PASS'; normal_compile_exit=$stub_rc; native_compile_exit=$native_rc; hardware_operations=0} | ConvertTo-Json | Set-Content result.json
Get-Content result.json
if ($stub_rc -ne 0) { exit $stub_rc }

