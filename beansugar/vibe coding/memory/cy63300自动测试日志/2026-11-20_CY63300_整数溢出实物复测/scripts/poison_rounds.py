
from __future__ import annotations
import json
import os
import struct
import subprocess
import sys
from pathlib import Path

HERE = Path(r"C:\Users\24796\Documents\组\CY63300_内存安全首轮")
LOG_ROOT = Path(os.environ.get("CY63300_LOG_ROOT", str(HERE / "recheck_20261120")))
REC = LOG_ROOT
sys.path.insert(0, str(HERE.parent / "SEHTAG_CSR可逆探针/单次触发探针"))
from run_real_csr import CFG, OCD, save, sha  # noqa: E402

TAIL = 0xF75FF06F
MARKER = 0x4D533132
POISON = {
    0x2000F038: 0xDEADBEEF, 0x2000F03C: 0xCAFEBABE,
    0x2000F010: 0xCCCCCCCC, 0x2000F014: 0x55555555,
    0x2000F018: 0xBBBBBBBB, 0x2000F01C: 0xAAAAAAAA,
    0x2000F050: 0x66666666, 0x2000F054: 0x77777777,
    0x2000F058: 0x11112222, 0x2000F05C: 0x33334444,
    0x2000F060: 0x88888888, 0x2000F064: 0x99999999,
}
FIELDS = ('completion','valid_status','copy_word_0','copy_word_1','oversize_status','oversize_preserved',
          'overflow_status','overflow_preserved','initialized_word_0','initialized_word_1','reuse_word_0',
          'reuse_word_1','original_source_0','original_source_1','original_destination_0','original_destination_1',
          'restored_source_0','restored_source_1','restored_destination_0','restored_destination_1',
          'destination_before_0','destination_before_1','destination_after_oversize_0','destination_after_oversize_1',
          'destination_after_overflow_0','destination_after_overflow_1')


def tcl_text(run):
    d = str(run).replace("\\", "/")
    mww = "\n".join(f"    mww 0x{a:08X} 0x{v:08X}" for a, v in POISON.items())
    dumpw = " ".join(f"[rd 0x{a:08x}]" for a in POISON)
    return (
        'proc rd {addr} {\n'
        f'    dump_image "{d}/tmp.bin" $addr 4\n'
        f'    set fh [open "{d}/tmp.bin" rb]\n'
        '    binary scan [read $fh 4] i v\n'
        '    close $fh\n'
        '    return [expr {$v & 0xffffffff}]\n'
        '}\n'
        'proc go {} {\n'
        '    if {[catch {init} e]} { echo "R3_ERROR=init:$e"; return }\n'
        '    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }\n'
        f'    if {{[rd 0x1a8] != 0x{TAIL:08x}}} {{ echo "R3_IMAGE_MISMATCH"; return }}\n'
        '    echo "R3_IMAGE_WORD_OK"\n'
        '    mww 0x2000F000 0x00000000\n'
        f'{mww}\n'
        f'    echo "R3_POISON_READ={dumpw}"\n'
        '    catch {reg pc 0x0}\n'
        '    catch {resume}\n'
        '    set tried 0\n'
        '    while {$tried < 80} {\n'
        '        sleep 25\n'
        f'        if {{[rd 0x2000F000] == 0x{MARKER:08x}}} {{ break }}\n'
        '        incr tried\n'
        '    }\n'
        '    echo "R3_POLLS=$tried"\n'
        f'    echo [format "R3_MARKER=0x%08X" [rd 0x2000F000]]\n'
        f'    echo [format "R3_STATUS=0x%08X/0x%08X" [rd 0x2000F010] [rd 0x2000F018]]\n'
        f'    echo [format "R3_FLAGS=0x%08X/0x%08X" [rd 0x2000F054] [rd 0x2000F070]]\n'
        f'    echo [format "R3_AFTER_OS=0x%08X/0x%08X" [rd 0x2000F058] [rd 0x2000F05C]]\n'
        f'    echo [format "R3_AFTER_OF=0x%08X/0x%08X" [rd 0x2000F060] [rd 0x2000F064]]\n'
        f'    echo [format "R3_ORIG_DST=0x%08X/0x%08X" [rd 0x2000F038] [rd 0x2000F03C]]\n'
        f'    dump_image "{d}/mbox_a.bin" 0x2000F000 104\n'
        f'    dump_image "{d}/dest_a.bin" 0x2000F048 8\n'
        f'    dump_image "{d}/mbox_b.bin" 0x2000F000 104\n'
        f'    dump_image "{d}/dest_b.bin" 0x2000F048 8\n'
        '    echo "R3_DONE"\n'
        '}\n'
        'if {[catch {go} e]} { echo "R3_TOP_ERROR=$e" }\n'
        'echo "R3_SHUTDOWN_REQUEST"\n'
        'shutdown\n'
    )


def one(run):
    run.mkdir()
    t = run / "round.tcl"
    t.write_text(tcl_text(run), encoding="utf-8")
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + t.as_posix() + "}"]
    log = run / "openocd.log"
    with log.open("xb") as out:
        rc = subprocess.run(argv, cwd=OCD.parent, stdout=out, stderr=subprocess.STDOUT, timeout=180).returncode
    text = log.read_text(encoding="utf-8", errors="replace")
    echo = [ln for ln in text.splitlines() if ln.startswith("R3_")]
    a = (run / "mbox_a.bin").read_bytes()
    b = (run / "mbox_b.bin").read_bytes()
    da = (run / "dest_a.bin").read_bytes()
    db = (run / "dest_b.bin").read_bytes()
    words = struct.unpack("<26I", a)
    mbox = {k: f"0x{v:08X}" for k, v in zip(FIELDS, words)}
    known = set(FIELDS)
    result = {
        "run": str(run), "exit_code": rc, "log_sha256": sha(log),
        "echo": echo,
        "mbox_stable": a == b, "dest_stable": da == db,
        "dest_read": [f"0x{v:08X}" for v in struct.unpack("<2I", da)],
        "mailbox": mbox,
        "store_reached": {
            "w4_oversize_status": mbox["oversize_status"] != "0xCCCCCCCC",
            "w5_oversize_preserved": mbox["oversize_preserved"] != "0x55555555",
            "w6_overflow_status": mbox["overflow_status"] != "0xBBBBBBBB",
            "w7_overflow_preserved": mbox["overflow_preserved"] != "0xAAAAAAAA",
            "w20_21_before": mbox["destination_before_0"] != "0x66666666",
            "w22_23_after_oversize": mbox["destination_after_oversize_0"] != "0x11112222",
            "w24_25_after_overflow": mbox["destination_after_overflow_0"] != "0x88888888",
        },
    }
    pat = ("0x2468ACE0", "0x13579BDF")
    result["snapshots"] = {
        "before": (mbox["destination_before_0"], mbox["destination_before_1"]),
        "after_oversize": (mbox["destination_after_oversize_0"], mbox["destination_after_oversize_1"]),
        "after_overflow": (mbox["destination_after_overflow_0"], mbox["destination_after_overflow_1"]),
        "orig_dst": (mbox["original_destination_0"], mbox["original_destination_1"]),
    }
    result["verdict"] = {
        "overflow_return_code": mbox["overflow_status"],
        "destination_unchanged_by_firmware_snapshots": (
            result["snapshots"]["before"] == result["snapshots"]["after_overflow"]),
        "firmware_preservation_flag_written": result["store_reached"]["w7_overflow_preserved"],
        "snapshots_match_pattern": all(x == y for x, y in zip(result["snapshots"]["after_overflow"], pat)),
    }
    save(run / "round_result.json", result)
    print(json.dumps({k: v for k, v in result.items() if k not in ("mailbox",)}, indent=1, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    for i in range(int(sys.argv[1]) if len(sys.argv) > 1 else 2):
        from datetime import datetime
        one(REC / datetime.now().strftime("poison_round_%Y%m%d_%H%M%S_%f"))
