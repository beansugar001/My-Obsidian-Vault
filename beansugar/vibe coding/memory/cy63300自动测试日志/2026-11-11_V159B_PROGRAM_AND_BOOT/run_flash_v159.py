
import argparse
import hashlib
import json
import os
import re
import struct
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT / "V158_HARDWARE_I2C_OLED_HELLO"))
from run_cy63300 import CFG, OCD, OCD_DIR, PINNED, host_snapshot

TCL = HERE / "flash_v159.tcl"
BASE = HERE / "runs" / "snapshot_20261111_154612_684305" / "main_sector0_64KiB.bin"
IMAGE = HERE / "hello.bin"
MARKER = ROOT / "markers" / "BBX_V159B_SECTOR0_PROGRAM_20261111_01.attempted.json"
SECTOR_SIZE = 65536
IMAGE_SIZE = 2120
HASHES = {
    OCD: PINNED[OCD],
    CFG: PINNED[CFG],
    TCL: "3D934ABC9A577E5DD8CB77746498C7707BA842D12376F70EF7DC0905F24DC57A",
    BASE: "21EAD7524AF6034378484B8107082250B0E3C9E13B915407A6A829F0F6BFCBBF",
    IMAGE: "A24DA9A83E19366AF803FE4640533895C3344D87370B221F093919EE8FC2E60A",
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def write_json(path, value):
    with path.open("x", encoding="utf-8") as output:
        json.dump(value, output, indent=2, ensure_ascii=False)
        output.write("\n")


def audit():
    for path, expected in HASHES.items():
        if sha(path) != expected:
            raise RuntimeError(f"SHA256 mismatch: {path}")
    baseline = BASE.read_bytes()
    image = IMAGE.read_bytes()
    if len(baseline) != SECTOR_SIZE or len(image) != IMAGE_SIZE or any(b != 0xFF for b in baseline[1088:]):
        raise RuntimeError("Unexpected baseline or image layout")
    return baseline, image


def run_phase(parent, phase, label, expected=None, trigger=None):
    run = parent / label
    run.mkdir()
    dump = run / "readback.bin"
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + TCL.as_posix() + "}"]
    opts = {
        "V159B_PHASE": phase, "V159B_DUMP": dump.as_posix(),
        "V159B_IMAGE": IMAGE.as_posix(),
    }
    if expected is not None:
        opts["V159B_EXPECTED"] = expected.as_posix()
    if trigger is not None:
        opts["V159B_TRIGGER"] = hex(trigger)
    host = host_snapshot()
    write_json(run / "command.json", {"argv": argv, "cwd": str(OCD_DIR), "env": opts, "host": host})
    if host["processes"] or host["listeners"]:
        raise RuntimeError(f"Debug client conflict: {host}")
    log = run / "openocd.log"
    print(f"V159B phase {label} in {run}", flush=True)
    with log.open("xb") as handle:
        rc = subprocess.run(argv, cwd=OCD_DIR, env={**os.environ, **opts},
                            stdout=handle, stderr=subprocess.STDOUT, timeout=420).returncode
    lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
    complete = f"V159B_COMPLETE phase={phase} rc=0"
    errors = [line for line in lines if re.search(r"Error:|V159B_ERROR=", line, re.I)]
    triggers = [line for line in lines if line.startswith("V159B_ERASE_TRIGGER=")]
    programming = [line for line in lines if line.startswith("V159B_PROGRAM_BEGIN ")]
    valid = (rc == 0 and lines.count(complete) == 1 and not errors
             and dump.is_file() and dump.stat().st_size == (56 if phase == "mailbox" else SECTOR_SIZE)
             and len(triggers) == (1 if phase == "erase" else 0)
             and len(programming) == (1 if phase == "program" else 0))
    meta = {
        "phase": phase, "valid": valid, "rc": rc, "errors": errors, "erase_triggers": triggers,
        "programming": programming, "sha256_log": sha(log),
        "sha256_dump": sha(dump) if dump.is_file() else None,
    }
    write_json(run / "result.json", meta)
    print(json.dumps(meta, indent=2), flush=True)
    if not valid:
        raise RuntimeError(f"Phase failed: {label}")
    return dump


def dirty_blocks(data):
    return [offset for offset in range(0, SECTOR_SIZE, 0x200)
            if data[offset:offset + 0x200] != b"\xff" * 0x200]


def check_erase(before, after, trigger):
    if any(new not in (old, 0xFF) for old, new in zip(before, after)):
        raise RuntimeError("Erase readback contains unexpected changes")
    if after[trigger:trigger + 0x200] != b"\xff" * 0x200:
        raise RuntimeError(f"Selected block still nonblank: {trigger:#x}")


def program(baseline, image, run):
    if MARKER.exists():
        raise RuntimeError(f"Consumed marker: {MARKER}")
    previous = run_phase(run, "snapshot", "00_pre_erase")
    current = previous.read_bytes()
    if current != baseline:
        raise RuntimeError("Live Flash differs from approved baseline")
    write_json(MARKER, {
        "stage": MARKER.stem, "run": str(run),
        "erase_range": "0x00000000-0x0000FFFF", "candidate_triggers": dirty_blocks(baseline),
        "program_start": 0, "program_bytes": IMAGE_SIZE, "program_sha256": HASHES[IMAGE],
    })
    for offset in dirty_blocks(baseline):
        if offset not in dirty_blocks(current):
            continue
        after = run_phase(run, "erase", f"erase_{offset:04x}", previous, offset)
        after_bytes = after.read_bytes()
        check_erase(current, after_bytes, offset)
        previous, current = after, after_bytes
    if dirty_blocks(current):
        raise RuntimeError("Sector remains nonblank")
    after = run_phase(run, "program", "program", previous)
    expected = image + b"\xff" * (SECTOR_SIZE - IMAGE_SIZE)
    if after.read_bytes() != expected:
        raise RuntimeError("Programmed sector does not match image plus blank tail")
    independent = run_phase(run, "snapshot", "independent_readback")
    if independent.read_bytes() != expected:
        raise RuntimeError("Independent readback mismatch")
    write_json(run / "program_result.json", {
        "status": "PASS_PROGRAMMED_AND_VERIFIED", "image_bytes": IMAGE_SIZE,
        "image_sha256": HASHES[IMAGE], "sector_sha256": sha(independent),
        "boot_executed": False,
    })
    print("PASS_PROGRAMMED_AND_VERIFIED", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=("audit", "program", "mailbox"))
    args = parser.parse_args()
    baseline, image = audit()
    blocks = dirty_blocks(baseline)
    if blocks != [0, 0x200, 0x400]:
        raise RuntimeError(f"Unexpected approved erase targets: {blocks}")
    if args.phase == "audit":
        blank = b"\xff" * SECTOR_SIZE
        check_erase(baseline, blank, 0)
        try:
            check_erase(baseline, baseline, 0)
        except RuntimeError:
            pass
        else:
            raise RuntimeError("Failed to detect an incomplete erase")
        print(f"AUDIT_PASS image={len(image)} dirty_blocks={[hex(x) for x in blocks]}")
        return
    now = datetime.now(timezone(timedelta(hours=8)))
    run = HERE / "runs" / now.strftime(f"{args.phase}_%Y%m%d_%H%M%S_%f")
    run.mkdir(parents=True)
    try:
        if args.phase == "program":
            program(baseline, image, run)
        else:
            data = run_phase(run, "mailbox", "mailbox_read").read_bytes()
            keys = ("magic", "stage", "result", "address", "expected", "value", "fifo", "sta",
                    "raw", "frame", "byte", "tx_writes", "stops", "done")
            report = {key: f"0x{word:08X}" for key, word in zip(keys, struct.unpack("<14I", data))}
            write_json(run / "mailbox.json", report)
            print(json.dumps(report, indent=2))
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        write_json(run / "stop.json", {"error": str(exc)})
        raise


if __name__ == "__main__":
    main()

