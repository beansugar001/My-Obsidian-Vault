import argparse
from datetime import datetime
from pathlib import Path
import re
import subprocess
import sys

from run_real_active_low import CFG, HASHES, OCD, save, sha

HERE = Path(__file__).resolve().parent
STARTUP = HERE.parent / "v160_cold_boot.tcl"
HELPER = HERE.parent / "双地址计数对照/cadence_test.tcl"
BODY = HERE / "observe_active_low.tcl"
PINNED = {
    **HASHES,
    STARTUP: "F71B3FC66D97AC8BB2382EEB862524C77D01BC5FA39D1FB359817AD83265075C",
    HELPER: "E8AD1E28F367309714860616C55A576EB1F7E37C0F6CEBD2E8EF04476A272FEB",
}
SAMPLES = ("INITIAL", "BEFORE_ACTIVE", "AFTER_ACTIVE", "FINAL")
FIELDS = ("odr", "dir", "magic", "first_count", "second_count", "second_copy", "done")


def source():
    for p, digest in PINNED.items():
        if sha(p) != digest:
            raise RuntimeError(f"Pinned file changed: {p}")
    tcl = (
        STARTUP.read_text(encoding="utf-8").split("dump_image", 1)[0]
        + HELPER.read_text(encoding="utf-8").split("proc check_controls", 1)[0]
        + BODY.read_text(encoding="ascii")
    )
    if re.search(r"\b(halt|resume|reset|mww|mwh|mwb|dmi_write|load_image|flash|write_memory)\b", tcl, re.I):
        raise RuntimeError("Unexpected command in sampling Tcl")
    return tcl


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    tcl = source()
    if not args.execute:
        print("READ_ONLY_AUDIT_PASS")
        return
    names = subprocess.run(
        ["powershell", "-NoProfile", "-Command", "(Get-Process -ErrorAction Stop).ProcessName"],
        check=True, capture_output=True, timeout=20,
    ).stdout
    if re.search(rb"^(openocd|pyocd|probe-rs|JLink[^\r\n]*|[^\r\n]*-gdb)\r?$", names, re.I | re.M):
        raise RuntimeError("Active debug process")
    run = HERE / datetime.now().strftime("observe_%Y%m%d_%H%M%S_%f")
    run.mkdir()
    path = run / "run.tcl"
    path.write_text(tcl, encoding="utf-8")
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + path.as_posix() + "}"]
    save(run / "command.json", {"argv": argv, "cwd": str(OCD.parent), "tcl_sha256": sha(path)})
    print("RUN_DIR=" + str(run), flush=True)
    log = run / "openocd.log"
    with log.open("xb") as out:
        try:
            code = subprocess.run(argv, cwd=OCD.parent, stdout=out, stderr=subprocess.STDOUT,
                                  timeout=45).returncode
        except subprocess.TimeoutExpired:
            code = None
    raw = log.read_text(encoding="utf-8", errors="replace")
    rows = re.findall(r"^SYNC_STATE (\w+)((?: [0-9A-F]{8}){7})$", raw, re.M)
    reads = re.findall(r"^SYNC_ACTIVE_READS (\d+) (\d+)$", raw, re.M)
    complete = (code == 0 and "Error:" not in raw and "SYNC_ERROR=" not in raw
                and raw.splitlines().count("SYNC_COMPLETE") == 1
                and tuple(label for label, _ in rows) == SAMPLES
                and len(reads) == 1 and int(reads[0][0]) > 0 and int(reads[0][1]) >= 10000)
    result = {
        "complete": complete, "exit_code": code, "reads_and_ms": reads,
        "samples": {label: dict(zip(FIELDS, values.split())) for label, values in rows},
        "log_sha256": sha(log),
    }
    save(run / "result.json", result)
    print("\n".join(line for line in raw.splitlines() if line.startswith("SYNC_")))
    if not complete:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
