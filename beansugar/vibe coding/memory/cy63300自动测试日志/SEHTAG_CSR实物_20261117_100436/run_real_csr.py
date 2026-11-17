import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys

HERE = Path(__file__).resolve().parent
BASE = HERE.parent / "基线镜像"
sys.path.insert(0, str(BASE))
from run_real_baseline import CFG, EXPECTED, OCD, V160_TCL, run_phase, save, sha

BASELINE = BASE / "program_20261117_095417_595953/independent_readback/readback.bin"
IMAGE = HERE / "firmware.bin"
FLASH_MARK = HERE / "SEHTAG_CSR_FLASH_20261117_01.attempted.json"
TRIGGER_MARK = HERE / "SEHTAG_CSR_ARM_20261117_01.attempted.json"
PINNED = {
    **{p: EXPECTED[p] for p in (OCD, CFG, V160_TCL)},
    BASELINE: "A5605F98BF115C70F49E2245079E0C5271CD0D91CE5ACA4B78C441AC9ADEC938",
    IMAGE: "744B59D77584A40ABC34C02C659F4F1C29FCBDBFDAAF6CD4A3E51EB5BA6DA6B7",
}


def audit():
    for path, expected in PINNED.items():
        if sha(path) != expected:
            raise RuntimeError(f"SHA256 mismatch: {path}")
    before = BASELINE.read_bytes()
    image = IMAGE.read_bytes()
    if len(before) != 0x10000 or before[0x200:] != b"\xff" * 0xfe00 or len(image) != 240:
        raise RuntimeError("Expected a single nonblank Flash page and 240-byte image")
    source = V160_TCL.read_text(encoding="utf-8")
    for old, new in (
        ("$trigger != 0 && $trigger != 0x200 && $trigger != 0x400 && $trigger != 0x600 && $trigger != 0x800", "$trigger != 0"),
        ("0x00000A00", "0x00000200"),
        ("0x00000A8C", "0x000000F0"),
        ("bytes=2700", "bytes=240"),
    ):
        if source.count(old) != 1:
            raise RuntimeError(f"Reference Tcl mismatched near {old}")
        source = source.replace(old, new)
    return before, image, source


def program(run, baseline, image, tcl):
    if FLASH_MARK.exists():
        raise RuntimeError("Flash stage already attempted")
    candidate = run / "candidate.bin"
    candidate.write_bytes(image)
    before = run_phase(run, tcl, candidate, "pre_erase", "snapshot", 0x10000)
    if before != baseline:
        raise RuntimeError("Live Flash differs from the archived SRAM baseline")
    save(FLASH_MARK, {"run": str(run), "image_sha256": sha(candidate)})
    first_word = struct.unpack_from("<I", before)[0]
    page = run_phase(run, tcl, candidate, "erase_0000", "erase", 0x200,
                     sentinel=(0, first_word))
    if page != b"\xff" * 0x200:
        raise RuntimeError("Page 0 is not blank after one erase")
    programmed = run_phase(run, tcl, candidate, "program", "program", len(image),
                           sentinel=(0, 0xFFFFFFFF), program_bytes=len(image))
    if programmed != image:
        raise RuntimeError("Probe prefix verification failed")
    actual = run_phase(run, tcl, candidate, "independent_readback", "snapshot", 0x10000)
    if actual != image + baseline[len(image):]:
        raise RuntimeError("Independent readback does not match the expected sector")
    save(run / "program_result.json", {"verified": True, "bytes": len(image),
         "sector_sha256": sha(run / "independent_readback/readback.bin")})
    print("PASS_CSR_IMAGE_VERIFIED", flush=True)


def trigger(run):
    if TRIGGER_MARK.exists():
        raise RuntimeError("CSR trigger already attempted")
    flash_run = Path(json.loads(FLASH_MARK.read_text(encoding="utf-8"))["run"])
    if not json.loads((flash_run / "program_result.json").read_text(encoding="utf-8"))["verified"]:
        raise RuntimeError("Missing successful Flash verification")
    client_list = subprocess.run(
        ["powershell", "-NoProfile", "-Command", "(Get-Process -ErrorAction Stop).ProcessName"],
        capture_output=True, check=True, timeout=20,
    ).stdout
    if re.search(rb"(openocd|pyocd|probe-rs|daplink|cmsis-dap|[a-z0-9-]+-gdb)", client_list, re.I):
        raise RuntimeError("Active debug process")
    tcl = HERE / "trigger_once.tcl"
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + tcl.as_posix() + "}"]
    save(run / "command.json", {"argv": argv, "cwd": str(OCD.parent), "tcl_sha256": sha(tcl)})
    save(TRIGGER_MARK, {"run": str(run), "tcl_sha256": sha(tcl)})
    log = run / "openocd.log"
    with log.open("xb") as output:
        rc = subprocess.run(argv, cwd=OCD.parent, stdout=output, stderr=subprocess.STDOUT, timeout=45).returncode
    raw = log.read_text(encoding="utf-8", errors="replace")
    lines = raw.splitlines()
    attempts = lines.count("SEHTAG_ARM_REQUEST addr=0x2000F014 value=0x53454152")
    outcomes = re.findall(r"^SEHTAG_OUTCOME=(\w+)$", raw, re.M)
    completed = rc == 0 and attempts == 1 and not re.search(r"Error:|SEHTAG_ERROR=", raw, re.I)
    status = outcomes[0] if completed and len(outcomes) == 1 else "UNKNOWN" if attempts else "BLOCKED_BEFORE_TRIGGER"
    save(run / "result.json", {"status": status, "trigger_attempts_logged": attempts,
                               "exit_code": rc, "log_sha256": sha(log)})
    print(raw)
    print("STATUS=" + status)
    if status != "CSR_TOGGLE_RESTORED":
        raise RuntimeError(f"CSR result: {status}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=("audit", "program", "trigger"))
    phase = parser.parse_args().phase
    baseline, image, source = audit()
    if phase == "audit":
        print("AUDIT_PASS 240-byte probe, one Flash page, pinned V160 Tcl")
        return
    run = HERE / datetime.now().strftime(phase + "_%Y%m%d_%H%M%S_%f")
    run.mkdir()
    print(f"RUN_DIR={run}", flush=True)
    try:
        if phase == "program":
            tcl = run / "flash_probe.tcl"
            tcl.write_text(source, encoding="utf-8")
            program(run, baseline, image, tcl)
        else:
            trigger(run)
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        save(run / "stop.json", {"error": str(exc)})
        raise


if __name__ == "__main__":
    main()
