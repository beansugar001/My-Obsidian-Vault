
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

here = Path(__file__).resolve().parent
root = here.parent
sys.path.insert(0, str(root / "V158_HARDWARE_I2C_OLED_HELLO"))
from run_cy63300 import CFG, OCD, OCD_DIR, PINNED, host_snapshot

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def main():
    tcl = here / "snapshot.tcl"
    if any(sha(path) != PINNED[path] for path in (OCD, CFG)):
        raise RuntimeError("OpenOCD or config SHA256 mismatch")
    forbidden = r"\b(?:mww|mwh|mwb|write_memory|dmi_write|load_image|flash|reset|resume)\b"
    source = "\n".join(line for line in tcl.read_text().splitlines() if not line.lstrip().startswith("#"))
    if re.search(forbidden, source, flags=re.IGNORECASE):
        raise RuntimeError("Unexpected operation in snapshot script")
    host = host_snapshot()
    if host["processes"] or host["listeners"]:
        raise RuntimeError(f"Debug client conflict: {host}")
    now = datetime.now(timezone(timedelta(hours=8)))
    run = here / "runs" / now.strftime("snapshot_%Y%m%d_%H%M%S_%f")
    run.mkdir(parents=True)
    snapshot = run / "main_sector0_64KiB.bin"
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + tcl.as_posix() + "}"]
    meta = {
        "argv": argv, "cwd": str(OCD_DIR), "started": now.isoformat(), "host": host,
        "snapshot": str(snapshot),
        "sha256": {str(path): sha(path) for path in (OCD, CFG, tcl)},
    }
    (run / "command.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"RUN_DIR={run}", flush=True)
    log = run / "openocd.log"
    with log.open("xb") as handle:
        rc = subprocess.run(
            argv, cwd=OCD_DIR, env={**os.environ, "V160_SNAPSHOT": snapshot.as_posix()},
            stdout=handle, stderr=subprocess.STDOUT, timeout=210,
        ).returncode
    output = log.read_text(encoding="utf-8", errors="replace")
    passed = (rc == 0 and output.splitlines().count("V160_PREFLIGHT=PASS") == 1
              and output.splitlines().count("V160_PREFLIGHT_COMPLETE") == 1
              and not re.search(r"Error:|V160_ERROR=", output, re.I)
              and snapshot.is_file() and snapshot.stat().st_size == 65536)
    baseline = "B5DFAD5E728FB320DC5497CE69CB563C20DBAD588364E5D75BC093DF8175F9CB"
    snapshot_sha = sha(snapshot) if snapshot.is_file() else None
    status = "PASS_V159_BASELINE_MATCH" if passed and snapshot_sha == baseline else (
        "FAIL_BASELINE_MISMATCH" if passed else "FAIL_READ_ONLY"
    )
    result = {"status": status, "expected_v159_sector_sha256": baseline,
              "return_code": rc, "sha256_log": sha(log),
              "sha256_snapshot": snapshot_sha,
              "halts_logged": output.splitlines().count("V160_HALT_ATTEMPT"),
              "target_write_count": 0}
    (run / "result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(output)
    print(json.dumps(result, indent=2))
    return 0 if status == "PASS_V159_BASELINE_MATCH" else 1

if __name__ == "__main__":
    raise SystemExit(main())

