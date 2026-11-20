"""复测_整数溢出.py —— 一键复测「整数溢出 / 长度计算错误」这一项。

它做四件事：
  1. 检查电脑上的工具和板子连线
  2. 检查板子里现在装的是不是我们要测的固件
  3. 重复跑 N 轮：往内存里写"假的旧数据"当证据指纹 → 让固件从 0 重新启动 →
     等固件写完完成标记 → 把内存里的结果读出来 → 存盘
  4. 按固定判据给出 通过 / 未通过 / 待确认，并写一份 summary.json

用法（在 02_程序 目录下打开 PowerShell）：
    python 复测_整数溢出.py                 # 默认跑 2 轮
    python 复测_整数溢出.py --rounds 3      # 跑 3 轮
    python 复测_整数溢出.py --reflash       # 先烧 01_固件\firmware.bin，再复测
    python 复测_整数溢出.py --log "D:\某个目录"   # 结果写到别处（默认写到包里的 runs\）
"""
from __future__ import annotations

import argparse
import json
import struct
import subprocess
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "lib"))
from board import CFG, OCD, debug_process_running, flash_image, run_phase, save, sha  # noqa: E402

PKG = HERE.parent
FIRMWARE = PKG / "01_固件" / "firmware.bin"
IMAGE_TAIL_ADDR = 0x1A8
IMAGE_TAIL_WORD = 0xF75FF06F
MARKER = 0x4D533132
DEFAULT_LOG = PKG / "runs"

# 每一步要注入的"假旧数据"（十六进制地址: 假装里面原本是啥）。每个都是互不相同的常量，
# 只要它被改写了，就说明固件真的往这个格子写过东西。
POISON = {
    0x2000F038: 0xDEADBEEF, 0x2000F03C: 0xCAFEBABE,   # 启动时的原始目标值
    0x2000F010: 0xCCCCCCCC,                            # 合法复制状态 w4
    0x2000F014: 0x55555555,                            # 超长后内容保持 w5
    0x2000F018: 0xBBBBBBBB,                            # 整数溢出状态 w6
    0x2000F01C: 0xAAAAAAAA,                            # 整数溢出后内容保持 w7
    0x2000F050: 0x66666666, 0x2000F054: 0x77777777,   # 请求前快照 w20/w21
    0x2000F058: 0x11112222, 0x2000F05C: 0x33334444,   # 超长后快照 w22/w23
    0x2000F060: 0x88888888, 0x2000F064: 0x99999999,   # 溢出后快照 w24/w25
}
FIELDS = ('completion', 'valid_status', 'copy_word_0', 'copy_word_1', 'oversize_status',
          'oversize_preserved', 'overflow_status', 'overflow_preserved', 'initialized_word_0',
          'initialized_word_1', 'reuse_word_0', 'reuse_word_1', 'original_source_0',
          'original_source_1', 'original_destination_0', 'original_destination_1',
          'restored_source_0', 'restored_source_1', 'restored_destination_0',
          'restored_destination_1', 'destination_before_0', 'destination_before_1',
          'destination_after_oversize_0', 'destination_after_oversize_1',
          'destination_after_overflow_0', 'destination_after_overflow_1')
PATTERN = ("0x2468ACE0", "0x13579BDF")   # 固件在请求里写进目标的"合法内容"


def precheck_tcl(run: Path) -> Path:
    """只读检查：把 Flash 前 512 字节读回来，看板子里是不是目标固件。"""
    d = str(run).replace("\\", "/")
    t = run / "precheck.tcl"
    t.write_text(
        'proc go {} {\n'
        '    if {[catch {init} e]} { echo "PC_ERROR=$e"; return }\n'
        '    catch {halt 2000}\n'
        f'    dump_image "{d}/flash.bin" 0x0 512\n'
        '    echo "PC_DONE"\n'
        '}\n'
        'if {[catch {go} e]} { echo "PC_TOP_ERROR=$e" }\n'
        'shutdown\n', encoding="utf-8")
    return t


def check_environment() -> None:
    print("[1/4] 检查工具与连线")
    missing = [p for p in (OCD, CFG) if not Path(p).exists()]
    if missing:
        raise RuntimeError("找不到这些工具文件：\n  " + "\n  ".join(map(str, missing)))
    print(f"  · OpenOCD  : {OCD}")
    print(f"  · 接线配置 : {CFG}")
    if not FIRMWARE.exists():
        raise RuntimeError(f"找不到固件：{FIRMWARE}")
    print(f"  · 目标固件 : {FIRMWARE.name}  {len(FIRMWARE.read_bytes())} 字节  sha256={sha(FIRMWARE)[:16]}…")
    if debug_process_running():
        raise RuntimeError("现在有 OpenOCD/gdb 正在占用调试器，先全部关掉再跑")
    print("  · 没有别的程序占用调试器")
    print("  · 板子由 ST-Link 供电并连接（本脚本会自己连，不需要手动开 OpenOCD）")


def check_board_image(run: Path) -> None:
    print("[2/4] 检查板子里的固件是不是要测的那一个")
    run.mkdir(parents=True, exist_ok=False)
    tcl = precheck_tcl(run)
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + tcl.as_posix() + "}"]
    log = run / "openocd.log"
    with log.open("xb") as out:
        rc = subprocess.run(argv, cwd=OCD.parent, stdout=out, stderr=subprocess.STDOUT, timeout=120).returncode
    text = log.read_text(encoding="utf-8", errors="replace")
    if "PC_DONE" not in text:
        raise RuntimeError(f"连不上板子，看日志：{log}")
    flash = (run / "flash.bin").read_bytes()
    image = FIRMWARE.read_bytes()
    tail = struct.unpack_from("<I", flash, IMAGE_TAIL_ADDR)[0]
    print(f"  · 板子 Flash 前 512 字节 sha256={sha(run / 'flash.bin')[:16]}…")
    print(f"  · 镜像尾字 [0x{IMAGE_TAIL_ADDR:X}] = 0x{tail:08X}（RAW 固件应为 0x{IMAGE_TAIL_WORD:08X}）")
    if flash[:len(image)] != image:
        save(run / "mismatch.json", {"board_sha256": sha(run / "flash.bin"),
                                     "expected_sha256": sha(FIRMWARE),
                                     "board_prefix_matches": False,
                                     "tail_word": f"0x{tail:08X}"})
        raise RuntimeError("板子里不是目标固件。请加 --reflash 参数重新烧录后再跑，"
                           "或先确认板子上现在装的是哪一版（本轮证据已存盘，不会覆盖）")
    print("  · 板子固件与 01_固件/firmware.bin 逐字节一致 → 可以开始复测")


def round_tcl(run: Path) -> Path:
    d = str(run).replace("\\", "/")
    mww = "\n".join(f"    mww 0x{a:08X} 0x{v:08X}" for a, v in POISON.items())
    shown = " ".join(f"[rd 0x{a:08x}]" for a in POISON)
    t = run / "round.tcl"
    t.write_text(
        'proc rd {addr} {\n'
        f'    dump_image "{d}/tmp.bin" $addr 4\n'
        f'    set fh [open "{d}/tmp.bin" rb]\n'
        '    binary scan [read $fh 4] i v\n'
        '    close $fh\n'
        '    return [expr {$v & 0xffffffff}]\n'
        '}\n'
        'proc go {} {\n'
        '    if {[catch {init} e]} { echo "R_ERROR=init:$e"; return }\n'
        '    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }\n'
        f'    if {{[rd 0x{IMAGE_TAIL_ADDR:x}] != 0x{IMAGE_TAIL_WORD:08x}}} {{ echo "R_IMAGE_MISMATCH"; return }}\n'
        '    echo "R_IMAGE_OK"\n'
        '    mww 0x2000F000 0x00000000\n'
        f'{mww}\n'
        f'    echo "R_POISON={shown}"\n'
        '    catch {reg pc 0x0}\n'
        '    catch {resume}\n'
        '    set tried 0\n'
        '    while {$tried < 80} {\n'
        '        sleep 25\n'
        f'        if {{[rd 0x2000F000] == 0x{MARKER:08x}}} {{ break }}\n'
        '        incr tried\n'
        '    }\n'
        '    echo "R_POLLS=$tried"\n'
        f'    echo [format "R_MARKER=0x%08X" [rd 0x2000F000]]\n'
        f'    echo [format "R_STATUS=0x%08X/0x%08X" [rd 0x2000F010] [rd 0x2000F018]]\n'
        f'    echo [format "R_PRESERVED=0x%08X/0x%08X" [rd 0x2000F014] [rd 0x2000F01C]]\n'
        f'    echo [format "R_BEFORE=0x%08X/0x%08X" [rd 0x2000F050] [rd 0x2000F054]]\n'
        f'    echo [format "R_AFTER_OS=0x%08X/0x%08X" [rd 0x2000F058] [rd 0x2000F05C]]\n'
        f'    echo [format "R_AFTER_OF=0x%08X/0x%08X" [rd 0x2000F060] [rd 0x2000F064]]\n'
        f'    echo [format "R_ORIG_DST=0x%08X/0x%08X" [rd 0x2000F038] [rd 0x2000F03C]]\n'
        f'    dump_image "{d}/mbox_a.bin" 0x2000F000 104\n'
        f'    dump_image "{d}/dest_a.bin" 0x2000F048 8\n'
        f'    dump_image "{d}/mbox_b.bin" 0x2000F000 104\n'
        f'    dump_image "{d}/dest_b.bin" 0x2000F048 8\n'
        '    echo "R_DONE"\n'
        '}\n'
        'if {[catch {go} e]} { echo "R_TOP_ERROR=$e" }\n'
        'shutdown\n', encoding="utf-8")
    return t


def one_round(run: Path) -> dict:
    run.mkdir()
    tcl = round_tcl(run)
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + tcl.as_posix() + "}"]
    log = run / "openocd.log"
    with log.open("xb") as out:
        rc = subprocess.run(argv, cwd=OCD.parent, stdout=out, stderr=subprocess.STDOUT, timeout=180).returncode
    text = log.read_text(encoding="utf-8", errors="replace")
    echo = [ln for ln in text.splitlines() if ln.startswith("R_")]
    if "R_DONE" not in text:
        raise RuntimeError(f"这一轮没跑完，看日志：{log}")
    a = (run / "mbox_a.bin").read_bytes()
    b = (run / "mbox_b.bin").read_bytes()
    da = (run / "dest_a.bin").read_bytes()
    db = (run / "dest_b.bin").read_bytes()
    mbox = {k: f"0x{v:08X}" for k, v in zip(FIELDS, struct.unpack("<26I", a))}
    store = {
        "w4_oversize_status": mbox["oversize_status"] != "0xCCCCCCCC",
        "w5_oversize_preserved": mbox["oversize_preserved"] != "0x55555555",
        "w6_overflow_status": mbox["overflow_status"] != "0xBBBBBBBB",
        "w7_overflow_preserved": mbox["overflow_preserved"] != "0xAAAAAAAA",
        "w20_21_before": mbox["destination_before_0"] != "0x66666666",
        "w22_23_after_oversize": mbox["destination_after_oversize_0"] != "0x11112222",
        "w24_25_after_overflow": mbox["destination_after_overflow_0"] != "0x88888888",
    }
    snap = {
        "before": (mbox["destination_before_0"], mbox["destination_before_1"]),
        "after_oversize": (mbox["destination_after_oversize_0"], mbox["destination_after_oversize_1"]),
        "after_overflow": (mbox["destination_after_overflow_0"], mbox["destination_after_overflow_1"]),
        "orig_dst": (mbox["original_destination_0"], mbox["original_destination_1"]),
    }
    unchanged = snap["before"] == snap["after_overflow"]
    pattern_ok = all(x == y for x, y in zip(snap["after_overflow"], PATTERN))
    ret = mbox["overflow_status"]
    if ret != "0x00000001":
        verdict = "未通过：返回码不是 1"
    elif not unchanged or not pattern_ok:
        verdict = "未通过：目标内容变了"
    elif mbox["overflow_preserved"] != "0x00000001":
        verdict = "通过（主判据）/ 待确认（保持标志异常）"
    else:
        verdict = "通过"
    result = {
        "run": str(run), "exit_code": rc, "log_sha256": sha(log), "echo": echo,
        "mbox_stable": a == b, "dest_stable": da == db,
        "dest_read": [f"0x{v:08X}" for v in struct.unpack("<2I", da)],
        "mailbox": mbox, "store_reached": store, "snapshots": snap,
        "verdict": {
            "overflow_return_code": ret,
            "destination_unchanged_by_firmware_snapshots": unchanged,
            "firmware_preservation_flag_written": store["w7_overflow_preserved"],
            "snapshots_match_pattern": pattern_ok,
            "label": verdict,
        },
    }
    save(run / "round_result.json", result)
    return result


def brief(r: dict) -> str:
    m, s = r["mailbox"], r["snapshots"]
    return (f"返回码={m['overflow_status']}  目标地址=0x2000F048/0x2000F04C  "
            f"前={s['before'][0]}/{s['before'][1]}  后={s['after_overflow'][0]}/{s['after_overflow'][1]}  "
            f"保持标志={m['overflow_preserved']}  JTAG 完成标记后读=0x2000F048={r['dest_read'][0]} "
            f"两次一致={r['mbox_stable'] and r['dest_stable']}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rounds", type=int, default=2, help="跑几轮，默认 2")
    ap.add_argument("--reflash", action="store_true", help="先把 01_固件\\firmware.bin 烧进去")
    ap.add_argument("--log", default=None, help="结果目录，默认是本包里的 runs")
    args = ap.parse_args()
    root = Path(args.log) if args.log else DEFAULT_LOG
    root.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    print(f"结果目录：{root}")

    check_environment()
    if args.reflash:
        flash_run = root / f"flash_{stamp}"
        print("[烧录] 先烧固件")
        res = flash_image(flash_run, FIRMWARE)
        print(f"  · 烧录完成并回读校验通过：{res['bytes']} 字节  sector={res['sector_sha256'][:16]}…")
    check_board_image(root / f"precheck_{stamp}")

    rounds = []
    for i in range(args.rounds):
        print(f"[3/4] 第 {i + 1}/{args.rounds} 轮：注毒 → 重启 → 等完成标记 → 读回结果")
        r = one_round(root / datetime.now().strftime("round_%Y%m%d_%H%M%S_%f"))
        rounds.append(r)
        print("  " + brief(r))
        print("  判定：" + r["verdict"]["label"])

    labels = [r["verdict"]["label"] for r in rounds]
    main_pass = all(l.startswith("通过") for l in labels)
    all_clean = all(l == "通过" for l in labels)
    summary = {
        "when": datetime.now().isoformat(timespec="seconds"),
        "firmware": {"path": str(FIRMWARE), "bytes": len(FIRMWARE.read_bytes()), "sha256": sha(FIRMWARE)},
        "rounds": [{"run": r["run"], "label": r["verdict"]["label"]} for r in rounds],
        "verdict": "通过" if all_clean else ("通过（主判据）/ 待确认" if main_pass else "未通过"),
        "note": "返回 1 且目标两个字前后逐字一致 = 通过；保持标志 w7 与仿真不一致时另记为待确认",
    }
    save(root / f"summary_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json", summary)
    print("[4/4] 汇总")
    for r in rounds:
        print("  · " + r["verdict"]["label"] + " :: " + brief(r))
    print()
    print("本轮结论：" + summary["verdict"])
    if main_pass and not all_clean:
        print("说明：拒绝行为本身成立（返回 1 + 快照一致），但固件写的『溢出后内容保持』标志为 0，"
              "与同镜像 RTL 仿真的 1 不一致，已单独记为待确认。")


if __name__ == "__main__":
    main()
