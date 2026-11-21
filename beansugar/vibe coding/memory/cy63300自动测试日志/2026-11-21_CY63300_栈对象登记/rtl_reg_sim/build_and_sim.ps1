$ErrorActionPreference = 'Stop'
$tool = 'D:/project/tools/xpack-riscv-none-embed-gcc-8.3.0-2.3/bin/riscv-none-embed-'
$ivl  = 'D:/project/tools/iverilog-msys2-v12/ucrt64/bin'
$rtl  = 'D:/project/RISCV-63300/三方测试/Repo_Fanglongrui/rtl'
Set-Location $PSScriptRoot
$env:PATH = "$ivl;" + $env:PATH
& "${tool}gcc.exe" -march=rv32im -mabi=ilp32 -nostdlib '-Wl,-Ttext=0,-e,_start,--no-relax' firmware_reg.S -o firmware_reg.elf
if ($LASTEXITCODE -ne 0) { throw 'gcc failed' }
& "${tool}objcopy.exe" -O binary firmware_reg.elf firmware_reg.bin
if ($LASTEXITCODE -ne 0) { throw 'objcopy failed' }
& "${tool}objdump.exe" -d firmware_reg.elf > firmware_reg_disasm.log
& python mkhex.py firmware_reg.bin firmware_reg.hex
if ($LASTEXITCODE -ne 0) { throw 'mkhex failed' }
$vfiles = Get-ChildItem "$rtl/core/*.v" | ForEach-Object { $_.FullName }
$ufiles = Get-ChildItem "$rtl/utils/*.v" | ForEach-Object { $_.FullName }
& "${ivl}/iverilog.exe" -g2012 -s tb_stack_reg -I "$rtl/core" -o reg.vvp tb_stack_reg.sv @vfiles @ufiles 2>&1 | Tee-Object -FilePath iverilog.log
if ($LASTEXITCODE -ne 0) { throw 'iverilog failed' }
& "${ivl}/vvp.exe" -n reg.vvp 2>&1 | Tee-Object -FilePath sim_reg.log
exit $LASTEXITCODE
