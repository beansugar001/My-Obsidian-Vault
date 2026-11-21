$ErrorActionPreference = 'Stop'
$tool = 'D:/project/tools/xpack-riscv-none-embed-gcc-8.3.0-2.3/bin/riscv-none-embed-'
$ivl  = 'D:/project/tools/iverilog-msys2-v12/ucrt64/bin'
$rtl  = 'D:/project/RISCV-63300/三方测试/Repo_Fanglongrui/rtl'
Set-Location $PSScriptRoot
$env:PATH = "$ivl;" + $env:PATH
& "${tool}gcc.exe" -march=rv32im -mabi=ilp32 -nostdlib '-Wl,-Ttext=0,-e,_start,--no-relax' firmware.S -o firmware.elf
if ($LASTEXITCODE -ne 0) { throw 'gcc failed' }
& "${tool}objcopy.exe" -O binary firmware.elf firmware.bin
if ($LASTEXITCODE -ne 0) { throw 'objcopy failed' }
& "${tool}objdump.exe" -d firmware.elf > firmware_disasm.log
& python mkhex.py firmware.bin firmware.hex
if ($LASTEXITCODE -ne 0) { throw 'mkhex failed' }
$vfiles = Get-ChildItem "$rtl/core/*.v" | ForEach-Object { $_.FullName }
$ufiles = Get-ChildItem "$rtl/utils/*.v" | ForEach-Object { $_.FullName }
& "${ivl}/iverilog.exe" -g2012 -s tb_stack_v2 -I "$rtl/core" -o stack.vvp tb_stack_v2.sv @vfiles @ufiles
if ($LASTEXITCODE -ne 0) { throw 'iverilog failed' }
& "${ivl}/vvp.exe" -n stack.vvp
exit $LASTEXITCODE