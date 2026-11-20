"""栈项第二轮：用 SRST 真复位重启同一镜像，并在复位前注毒栈帧关键槽位。

与第一轮的区别：
- 第一轮靠 reg pc 0x0 重启（此后再不可用，PC 写被拒）；
- 本轮用 reset_config srst_only srst_nogate + reset，触发整芯片复位，
  复位后由 Flash 启动固件（18:00 探针已证实这个复位真的能重启）。

注毒槽位（都在 0x2001FEE0 这块 32B 栈帧里）：
  +8  0xBBBBBBBB  ← G 段的 sw t1,8(sp) 目标（安全使能已打开之后）
  +16 0x99999999  ← B 段合法复制目标
  +20 0x88888888  ← B 段合法复制目标
  +24 0x77777777  ← 未使用，作对照
  +28 0xAAAAAAAA  ← framer 的 sw ra,28(sp) 目标（安全使能打开之前）
另清空 0x2000F000..0x2000F0FC 与 0x2000F100..0x2000F117。
"""
import sys, json, subprocess, struct, time
from datetime import datetime
from pathlib import Path

HERE = Path(r"C:\Users\24796\Documents\组\CY63300_内存安全首轮\stack_check_20261120")
sys.path.insert(0, str(HERE / "lib"))
from board import OCD, CFG

IMAGE = HERE / "firmware.bin"
LOG_ROOT = Path(r"D:\obsidianvaults\笔记\beansugar\vibe coding\memory\cy63300自动测试日志\2026-11-20_CY63300_栈边界与返回地址")
POISON = {0x2001FEE8: 0xBBBBBBBB, 0x2001FEF0: 0x99999999,
          0x2001FEF4: 0x88888888, 0x2001FEF8: 0x77777777,
          0x2001FEFC: 0xAAAAAAAA}


def posix(p):
    return Path(p).as_posix()


def run_ocd(run: Path, tcl_text: str) -> str:
    run.mkdir(parents=True, exist_ok=True)
    tcl = run / "main.tcl"
    tcl.write_text(tcl_text, encoding="utf-8")
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + posix(tcl) + "}"]
    log = run / "openocd.log"
    with log.open("xb") as out:
        subprocess.run(argv, cwd=OCD.parent, stdout=out, stderr=subprocess.STDOUT, timeout=240)
    return log.read_text(encoding="utf-8", errors="replace")


def prepare_tcl(d: str) -> str:
    mww = "\n    ".join(f"mww 0x{a:08X} 0x{v:08X}" for a, v in POISON.items())
    back = " ".join(f"[format 0x%08X [rd 0x{a:08X}]]" for a in sorted(POISON))
    return f"""proc rd {{addr}} {{
    dump_image "{d}/tmp.bin" $addr 4
    set fh [open "{d}/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {{$v & 0xffffffff}}]
}}
proc go {{}} {{
    if {{[catch {{init}} e]}} {{ echo "P_ERROR=init:$e"; return }}
    if {{[riscv.cpu curstate] eq "running"}} {{ catch {{halt 2000}} }}
    echo "P_STATE=[riscv.cpu curstate]"
    echo "P_IMG=[format 0x%08X [rd 0x100]] [format 0x%08X [rd 0x1ac]]"
    mww 0x2000F000 0x00000000
    mww 0x2000F004 0x00000000
    mww 0x2000F008 0x00000000
    mww 0x2000F00C 0x00000000
    mww 0x2000F030 0x00000000
    mww 0x2000F034 0x00000000
    mww 0x2000F038 0x00000000
    mww 0x2000F03C 0x00000000
    mww 0x2000F040 0x00000000
    mww 0x2000F044 0x00000000
    mww 0x2000F048 0x00000000
    mww 0x2000F04C 0x00000000
    mww 0x2000F100 0x00000000
    mww 0x2000F104 0x00000000
    mww 0x2000F108 0x00000000
    mww 0x2000F10C 0x00000000
    mww 0x2000F110 0x00000000
    mww 0x2000F114 0x00000000
    {mww}
    echo "P_RB_POISON={back}"
    echo "P_RB_MARK=[format 0x%08X [rd 0x2000F000]] R0=[format 0x%08X [rd 0x2000F100]] PH2=[format 0x%08X [rd 0x2000F110]]"
    dump_image "{d}/frame_prep.bin" 0x2001FEE0 32
    dump_image "{d}/mbox_prep.bin" 0x2000F000 64
    if {{[catch {{reset_config srst_only srst_nogate}} e]}} {{ echo "P_CFG=FAIL:$e" }}
    if {{[catch {{reset run}} e]}} {{ echo "P_RESET=FAIL:$e" }} else {{ echo "P_RESET=OK" }}
    echo "P_DONE"
}}
if {{[catch {{go}} r]}} {{ echo "P_TOP_ERROR=$r" }}
shutdown
"""


def check_tcl(d: str) -> str:
    return f"""proc rd {{addr}} {{
    dump_image "{d}/tmp.bin" $addr 4
    set fh [open "{d}/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {{$v & 0xffffffff}}]
}}
proc go {{}} {{
    if {{[catch {{init}} e]}} {{ echo "C_ERROR=init:$e"; return }}
    echo "C_STATE=[riscv.cpu curstate]"
    if {{[riscv.cpu curstate] eq "running"}} {{ catch {{halt 2000}} }}
    echo "C_MARKER=[format 0x%08X [rd 0x2000F000]]"
    echo "C_PHASE2=[format 0x%08X [rd 0x2000F110]]"
    echo "C_MCAUSE=[format 0x%08X [rd 0x2000F108]] MEPC=[format 0x%08X [rd 0x2000F10C]]"
    echo "C_R0=[format 0x%08X [rd 0x2000F100]] R1=[format 0x%08X [rd 0x2000F104]]"
    dump_image "{d}/mbox_a.bin" 0x2000F000 64
    dump_image "{d}/res_a.bin" 0x2000F100 24
    dump_image "{d}/frame_a.bin" 0x2001FEE0 32
    dump_image "{d}/mbox_b.bin" 0x2000F000 64
    dump_image "{d}/res_b.bin" 0x2000F100 24
    dump_image "{d}/frame_b.bin" 0x2001FEE0 32
    echo "C_DONE"
}}
if {{[catch {{go}} r]}} {{ echo "C_TOP_ERROR=$r" }}
shutdown
"""


def main() -> None:
    run = LOG_ROOT / ("round2_srst_" + datetime.now().strftime("%Y%m%d_%H%M%S_%f"))
    d = posix(run)
    t1 = run_ocd(run / "prepare", prepare_tcl(posix(run / "prepare")))
    time.sleep(2.0)
    t2 = run_ocd(run / "check", check_tcl(posix(run / "check")))
    prep = [ln for ln in t1.splitlines() if ln.startswith("P_") or "Error" in ln]
    chk = [ln for ln in t2.splitlines() if ln.startswith("C_") or "Error" in ln]
    got = {}
    for tag in ("mbox", "res", "frame"):
        p = run / "check" / f"{tag}_a.bin"
        if p.exists():
            b = p.read_bytes()
            got[tag] = ["0x%08X" % struct.unpack_from("<I", b, i)[0] for i in range(0, len(b), 4)]
    result = {"run": str(run), "prepare": prep, "check": chk, "words": got,
              "image_sha256": __import__("hashlib").sha256(IMAGE.read_bytes()).hexdigest().upper()}
    (run / "round2_result.json").write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
