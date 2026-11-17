import argparse
from datetime import datetime
from pathlib import Path
import re
from statistics import mean
import subprocess
from sys import path

FOLDER = Path(__file__).resolve().parent
ROOT = FOLDER.parent
path.insert(0, str(ROOT / "基线镜像"))
from run_real_baseline import CFG, EXPECTED, OCD, save, sha

STARTUP = ROOT / "v160_cold_boot.tcl"
HELPER = FOLDER / "cadence_test.tcl"
BODY = FOLDER / "cadence_matched_dmi.tcl"
PINNED = {
    OCD: EXPECTED[OCD],
    CFG: EXPECTED[CFG],
    STARTUP: "F71B3FC66D97AC8BB2382EEB862524C77D01BC5FA39D1FB359817AD83265075C",
    HELPER: "E8AD1E28F367309714860616C55A576EB1F7E37C0F6CEBD2E8EF04476A272FEB",
    BODY: "5794734053D8C66F3BF642B61C5E989C80EB33C36C8DD8407823280BAA3202B7",
}
SCAN = re.compile(r"\b\d+b\s+(?:\d+i\s+)?([-rw?])\s+[0-9a-f]+\s+@[0-9a-f]+\s+->", re.I)
EDGE = re.compile(r"\bMATCHED_(BEGIN|END) (\d+) (quiet|dmi|sba)\s*$")
ROW = re.compile(r"\bMATCHED_WINDOW (\d+) (quiet|dmi|sba)((?: \d+){7})\s*$")
ORDER = "quiet dmi sba dmi sba quiet sba quiet dmi".split()


def build_source():
    if any(sha(p) != digest for p, digest in PINNED.items()):
        raise RuntimeError("Pinned input hash mismatch")
    startup = STARTUP.read_text(encoding="utf-8").split("dump_image", 1)[0]
    controls = HELPER.read_text(encoding="utf-8").split("proc run_window", 1)[0]
    controls = controls.split("proc check_controls", 1)[1]
    read_word = r"""
proc read_word {addr} {
    set raw [capture [format "mdw 0x%08X" $addr]]
    set pattern [format {^\s*0x%08x:\s+([0-9a-f]{8})\s*$} $addr]
    foreach line [split $raw "\n"] {
        if {[regexp -nocase $pattern $line -> hex]} {
            scan $hex %x value
            return [expr {$value & 0xffffffff}]
        }
    }
    error "MDW_PARSE <$raw>"
}
"""
    source = startup + read_word + "proc check_controls" + controls + BODY.read_text(encoding="utf-8")
    if (re.search(r"\b(?:halt|resume|reset|mww|mwh|mwb|load_image|write_memory)\b", source, re.I)
            or source.count("riscv dmi_write") != 1 or "dmi_configure_read 0x3c" in source):
        raise RuntimeError("Unexpected command in generated Tcl")
    return source


def parse(raw):
    rows = []
    trace = {}
    current = None
    for line in raw.splitlines():
        is_echo = line.startswith(("User :", "MATCHED_"))
        edge = EDGE.search(line) if is_echo else None
        if edge:
            action, index, mode = edge.groups()
            key = (int(index), mode)
            if action == "BEGIN" and current is None and key not in trace:
                trace[key] = []
                current = key
            elif action == "END" and current == key:
                current = None
            else:
                raise RuntimeError("Unexpected scan trace marker order")
        if current is not None:
            scan = SCAN.search(line)
            if scan:
                trace[current].append(scan.group(1))
        row = ROW.search(line) if is_echo else None
        if row:
            idx, mode, numbers = row.groups()
            ms, ops, over, before, after, copy_before, copy_after = map(int, numbers.split())
            scans = trace.get((int(idx), mode), [])
            rows.append({"index": int(idx), "mode": mode, "duration_ms": ms, "dmi_commands": ops,
                         "dmi_scans": len(scans), "scan_reads": scans.count("r"), "scan_writes": scans.count("w"),
                         "scan_nops": scans.count("-"), "overruns": over, "original_before": before,
                         "original_after": after, "copy_before": copy_before, "copy_after": copy_after,
                         "original_delta": after-before, "copy_delta": copy_after-copy_before})
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--parse-run", type=Path)
    args = parser.parse_args()
    if args.parse_run is not None:
        evaluate(args.parse_run, None, offline=True)
        return
    source = build_source()
    names = subprocess.run(
        ["powershell", "-NoProfile", "-Command", "(Get-Process -ErrorAction Stop).ProcessName"],
        check=True, capture_output=True, timeout=20,
    ).stdout
    if re.search(rb"(openocd|pyocd|probe-rs|daplink|cmsis-dap|[a-z0-9-]+-gdb)", names, re.I):
        raise RuntimeError("Active debug process")
    run = FOLDER / datetime.now().strftime("matched_dmi_%Y%m%d_%H%M%S_%f")
    run.mkdir()
    tcl = run / "run.tcl"
    tcl.write_text(source, encoding="utf-8")
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + tcl.as_posix() + "}"]
    save(run / "command.json", {"argv": argv, "cwd": str(OCD.parent),
                                "sha256": {str(p): sha(p) for p in (*PINNED, tcl)}})
    print("RUN_DIR=" + str(run), flush=True)
    log = run / "openocd.log"
    with log.open("xb") as output:
        try:
            code = subprocess.run(argv, cwd=OCD.parent, stdout=output, stderr=subprocess.STDOUT,
                                  timeout=55).returncode
        except subprocess.TimeoutExpired:
            code = None
    save(run / "process_exit.json", {"exit_code": code})
    evaluate(run, code)


def evaluate(run, code, *, offline=False):
    log = run / "openocd.log"
    raw = log.read_text(encoding="utf-8", errors="replace")
    rows = parse(raw)
    finished = ((code == 0 or offline) and "Error:" not in raw and not re.search(r"MATCHED_ERROR=", raw)
                and any(line.endswith("MATCHED_COMPLETE") for line in raw.splitlines())
                and [r["index"] for r in rows] == list(range(9)) and [r["mode"] for r in rows] == ORDER)
    matched = finished and all(r["dmi_scans"] == (0 if r["mode"] == "quiet" else 108)
                               and r["dmi_commands"] == (0 if r["mode"] == "quiet" else 54)
                               and r["duration_ms"] >= 2100 and r["overruns"] == 0 for r in rows)
    summary = {}
    for mode in ("quiet", "dmi", "sba"):
        group = [r for r in rows if r["mode"] == mode]
        if group:
            summary[mode] = {"original_deltas": [r["original_delta"] for r in group],
                             "copy_deltas": [r["copy_delta"] for r in group],
                             "dmi_scans": [r["dmi_scans"] for r in group],
                             "average_original_delta": mean(r["original_delta"] for r in group)}
    save(run / "result.json", {"complete": finished, "scan_matched": matched, "exit_code": code,
                               "summary": summary, "windows": rows, "log_sha256": sha(log)})
    print("\n".join(line for line in raw.splitlines()
                    if line.startswith(("User :", "MATCHED_")) and ("MATCHED_ERROR=" in line or ROW.search(line))))
    print(summary)
    if not matched:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
