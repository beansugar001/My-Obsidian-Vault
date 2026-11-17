import argparse
from datetime import datetime
import json
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ORIG = HERE.parent / "单次触发探针"
sys.path.insert(0, str(ORIG))
from run_real_csr import CFG, OCD, PINNED, V160_TCL, flash_tcl, program, save, sha

BEFORE = ORIG / "program_20261117_100436_858400/independent_readback/readback.bin"
IMAGE = HERE / "firmware.bin"
FLASH_MARK = HERE / "SEHTAG_WAIT_FLASH_20261117_01.attempted.json"
WRITE_MARK = HERE / "SEHTAG_WAIT_TOKENS_20261117_01.attempted.json"
INPUTS = {
    **{path: PINNED[path] for path in (OCD, CFG, V160_TCL)},
    BEFORE: "3C25575736DC75A06CC59011B2FDA41701F9F0CA213DB00B24B97A29FE1500B1",
    IMAGE: "52BC806F7FCF73D13F829349A10C3649EC686710E1B40C3219253E2964E80E14",
}


def audit():
    for path, expected in INPUTS.items():
        if sha(path) != expected:
            raise RuntimeError(f"SHA256 mismatch: {path}")
    before, image = BEFORE.read_bytes(), IMAGE.read_bytes()
    if len(before) != 0x10000 or before[0x200:] != b"\xff" * 0xfe00 or len(image) != 172:
        raise RuntimeError("Unexpected startup image layout")
    return before, image


def test(run):
    if WRITE_MARK.exists():
        raise RuntimeError("SRAM token stage already attempted")
    flash_run = Path(json.loads(FLASH_MARK.read_text(encoding="utf-8"))["run"])
    if not json.loads((flash_run / "program_result.json").read_text(encoding="utf-8"))["verified"]:
        raise RuntimeError("Missing successful Flash verification")
    procs = subprocess.run(
        ["powershell", "-NoProfile", "-Command", "(Get-Process -ErrorAction Stop).ProcessName"],
        capture_output=True, check=True, timeout=20,
    ).stdout
    if re.search(rb"(openocd|pyocd|probe-rs|daplink|cmsis-dap|[a-z0-9-]+-gdb)", procs, re.I):
        raise RuntimeError("Active debug process")
    tcl = HERE / "wait_test.tcl"
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + tcl.as_posix() + "}"]
    save(run / "command.json", {"argv": argv, "cwd": str(OCD.parent), "tcl_sha256": sha(tcl)})
    save(WRITE_MARK, {"run": str(run), "tcl_sha256": sha(tcl)})
    log = run / "openocd.log"
    with log.open("xb") as output:
        rc = subprocess.run(argv, cwd=OCD.parent, stdout=output, stderr=subprocess.STDOUT, timeout=45).returncode
    raw = log.read_text(encoding="utf-8", errors="replace")
    attempts = re.findall(r"^WAIT_TOKEN_REQUEST value=(0x[0-9A-F]{8})$", raw, re.M)
    findings = re.findall(r"^WAIT_OUTCOME=(\w+)$", raw, re.M)
    status = findings[0] if rc == 0 and len(findings) == 1 and "Error:" not in raw else "STOPPED"
    save(run / "result.json", {"status": status, "write_attempts": attempts,
                               "exit_code": rc, "log_sha256": sha(log)})
    print(raw)
    print("STATUS=" + status)
    if status not in ("NORMAL_WAIT_AND_EXIT", "EXITED_BEFORE_HOST_TOKEN"):
        raise RuntimeError(f"Test result: {status}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=("audit", "program", "test"))
    phase = parser.parse_args().phase
    before, image = audit()
    source = flash_tcl(len(image))
    if phase == "audit":
        print("AUDIT_PASS 172-byte SRAM-only image, one startup page, pinned input hashes")
        return
    run = HERE / datetime.now().strftime(phase + "_%Y%m%d_%H%M%S_%f")
    run.mkdir()
    print(f"RUN_DIR={run}", flush=True)
    try:
        if phase == "program":
            tcl = run / "flash_wait.tcl"
            tcl.write_text(source, encoding="utf-8")
            program(run, before, image, tcl, FLASH_MARK)
        else:
            test(run)
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        save(run / "stop.json", {"error": str(error)})
        raise


if __name__ == "__main__":
    main()
