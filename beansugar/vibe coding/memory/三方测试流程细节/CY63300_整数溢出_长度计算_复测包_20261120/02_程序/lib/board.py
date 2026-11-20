"""board.py —— 和 CY63300 板子通信要用到的最小一组函数。

看不懂代码也没关系：你只需要知道这里放的是"怎么让 OpenOCD 干活"的固定写法，
真正的测试步骤在同目录的 复测_整数溢出.py 里。

三个路径 = 三件工具：
  OCD  : OpenOCD 程序（JTAG/SWD 调试器驱动）
  CFG  : 调试器与芯片的接线描述文件
  TCL  : 烧录一个 Flash 页/读一段内存的脚本模板
"""
from __future__ import annotations

import json
import os
import re
import subprocess
from hashlib import sha256
from pathlib import Path

OCD = Path(r"D:\project\tools\tinyriscv-master\tools\openocd\openocd.exe")
CFG = Path(r"C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\03_experiments\bbx_v76a_100k.cfg")
TCL = Path(r"C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX\V160_CPU_OLED_REFRESH\flash_v160_address_park.tcl")


def sha(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest().upper()


def save(path: Path, data: dict) -> None:
    """写一个 json 文件；路径已存在时直接报错，避免把上一轮证据覆盖掉。"""
    with path.open("x", encoding="utf-8") as output:
        json.dump(data, output, ensure_ascii=False, indent=2)
        output.write("\n")


def debug_process_running() -> bool:
    """同一时刻只允许一个程序占用调试器，否则 OpenOCD 会连不上。"""
    procs = subprocess.run(
        ["powershell", "-NoProfile", "-Command", "(Get-Process -ErrorAction Stop).ProcessName"],
        capture_output=True, check=True, timeout=20,
    ).stdout
    return re.search(rb"(openocd|pyocd|probe-rs|daplink|cmsis-dap|[a-z0-9-]+-gdb)", procs, re.I) is not None


def flash_tcl(image_size: int) -> str:
    """把模板里的长度/地址改成本次固件的大小。"""
    source = TCL.read_text(encoding="utf-8")
    for old, new in (
        ("$trigger != 0 && $trigger != 0x200 && $trigger != 0x400 && $trigger != 0x600 && $trigger != 0x800", "$trigger != 0"),
        ("0x00000A00", "0x00000200"),
        ("0x00000A8C", f"0x{image_size:08X}"),
        ("bytes=2700", f"bytes={image_size}"),
    ):
        if source.count(old) != 1:
            raise RuntimeError(f"模板脚本已变化，找不到唯一锚点：{old}")
        source = source.replace(old, new)
    return source


def run_phase(run: Path, tcl: Path, image: Path, name: str, phase: str, length: int,
              *, trigger: int = 0, sentinel=None, program_bytes: int = 136) -> bytes:
    """跑一次 OpenOCD：读/擦/写一段内存，结果写到 run/<name>/ 下。"""
    folder = run / name
    folder.mkdir()
    dump = folder / "readback.bin"
    log = folder / "openocd.log"
    if debug_process_running():
        raise RuntimeError("已有调试进程在跑（openocd/gdb 等），先关掉")
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + tcl.as_posix() + "}"]
    opts = {
        "V160B_PHASE": phase,
        "V160B_DUMP": dump.as_posix(),
        "V160B_IMAGE": image.as_posix(),
        "V160B_TRIGGER": hex(trigger),
    }
    if sentinel is not None:
        addr, word = sentinel
        opts.update(V160B_SENTINEL_ADDR=hex(addr), V160B_SENTINEL_WORD=hex(word))
    save(folder / "command.json", {"argv": argv, "cwd": str(OCD.parent), "env": opts, "tcl_sha256": sha(tcl)})
    print(f"  · {name} ...", flush=True)
    with log.open("xb") as output:
        rc = subprocess.run(argv, cwd=OCD.parent, env={**os.environ, **opts},
                            stdout=output, stderr=subprocess.STDOUT, timeout=240).returncode
    text = log.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    valid = (
        rc == 0 and lines.count(f"V160B_COMPLETE phase={phase} rc=0") == 1
        and not re.search(r"Error:|V160B_ERROR=", text, re.I)
        and dump.is_file() and dump.stat().st_size == length
        and lines.count(f"V160B_ERASE_TRIGGER=0x{trigger:08X}") == (phase == "erase")
        and lines.count(f"V160B_PROGRAM_BEGIN address=0x0 bytes={program_bytes}") == (phase == "program")
    )
    save(folder / "result.json", {"pass": valid, "exit_code": rc, "log_sha256": sha(log),
                                  "readback_sha256": sha(dump) if dump.is_file() else None})
    if not valid:
        raise RuntimeError(f"这一步失败了，看日志：{log}")
    return dump.read_bytes()


def flash_image(run: Path, image: Path) -> dict:
    """把 image 烧进 Flash 第 0 页并独立回读校验（原样校验，不做任何假设）。"""
    run.mkdir(exist_ok=True)
    tcl = run / "flash_image.tcl"
    tcl.write_text(flash_tcl(len(bytearray(image.read_bytes()))), encoding="utf-8")
    data = image.read_bytes()
    before = run_phase(run, tcl, image, "pre_erase", "snapshot", 0x10000)
    save(run / "pre_flash_snapshot.json", {"sector_sha256": sha(run / "pre_erase/readback.bin"),
                                           "first_word": f"0x{int.from_bytes(before[:4], 'little'):08X}"})
    page = run_phase(run, tcl, image, "erase_0000", "erase", 0x200,
                     sentinel=(0, int.from_bytes(before[:4], "little")))
    if page != b"\xff" * 0x200:
        raise RuntimeError("擦除后第 0 页不是全 0xFF")
    programmed = run_phase(run, tcl, image, "program", "program", len(data),
                           sentinel=(0, 0xFFFFFFFF), program_bytes=len(data))
    if programmed != data:
        raise RuntimeError("烧录后回读与固件不一致")
    actual = run_phase(run, tcl, image, "independent_readback", "snapshot", 0x10000)
    if actual != data.ljust(0x200, b"\xff") + before[0x200:]:
        raise RuntimeError("独立回读与预期扇区不一致")
    result = {"verified": True, "bytes": len(data), "image_sha256": sha(image),
              "sector_sha256": sha(run / "independent_readback/readback.bin")}
    save(run / "program_result.json", result)
    return result
