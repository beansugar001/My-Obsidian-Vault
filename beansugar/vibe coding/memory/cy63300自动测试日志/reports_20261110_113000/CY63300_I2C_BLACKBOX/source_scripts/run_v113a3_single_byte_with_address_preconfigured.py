from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

PROJECT = Path(r"C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX")
OCD_DIR = Path(r"D:\project\tools\tinyriscv-master\tools\openocd")
OCD = OCD_DIR / "openocd.exe"
CFG = PROJECT / "03_experiments" / "bbx_v76a_100k.cfg"
TCL = PROJECT / "03_experiments" / "v113a3_single_byte_with_address_preconfigured.tcl"
STAGE = "BBX_V113A3_SINGLE_BYTE_ADDR_PRECONFIGURED_20261110_01"
MARK = PROJECT / "markers" / f"{STAGE}.attempted.json"
RUNS = PROJECT / "runs_local_v109"
PINNED = {
    "openocd": "EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27",
    "cfg": "CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1",
}
ALLOWLIST = [
    ("0x40002808", "0x00000000"),
    ("0x40002828", "0x00000002"),
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def host_snapshot():
    query = r'''$names=@('openocd','pyocd','JLinkGDBServerCL','JLinkGDBServer','JLinkExe','ST-LINK_gdbserver','STLinkServer','STM32CubeProgrammer','probe-rs','riscv-none-embed-gdb','riscv64-unknown-elf-gdb','arm-none-eabi-gdb','gdb');$p=@(Get-Process -ErrorAction Stop|Where-Object{$names -contains $_.ProcessName}|Select-Object Id,ProcessName);$n=@(netstat -ano -p tcp|Select-String -Pattern "\sLISTENING\s*$"|ForEach-Object{$f=@($_.Line -split "\s+"|Where-Object{$_});if($f.Count -ge 5){$port=[int](($f[1]-split ":")[-1]);if($port -in @(3333,4444,6666)){[pscustomobject]@{LocalAddress=$f[1];LocalPort=$port;OwningProcess=[int]$f[4]}}}});ConvertTo-Json -Compress -Depth 4 -InputObject @{processes=$p;listeners=$n}'''
    result = subprocess.run(
        ["powershell", "-NoProfile", "-Command", query],
        capture_output=True,
        text=True,
        timeout=25,
    )
    if result.returncode:
        raise RuntimeError(f"HOST_QUERY_FAILED rc={result.returncode}: {result.stderr}")
    data = json.loads(result.stdout)
    processes = data.get("processes") or []
    listeners = data.get("listeners") or []
    if isinstance(processes, dict):
        processes = [processes]
    if isinstance(listeners, dict):
        listeners = [listeners]
    return processes, listeners


def stop(code: int, reason: str) -> int:
    print(f"BLOCKED_{reason}")
    return code


def main() -> int:
    for file in (OCD, CFG, TCL):
        if not file.is_file():
            return stop(2, f"MISSING_FILE:{file}")
    for key, file in (("openocd", OCD), ("cfg", CFG)):
        actual = sha(file)
        if actual != PINNED[key]:
            return stop(2, f"PINNED_HASH_MISMATCH:{key}:{actual}")

    tcl = TCL.read_text(encoding="utf-8")
    if re.search(r"(?im)^\s*(?:reset|resume|flash|erase|load_image|mww|mwh|mwb)\b", tcl):
        return stop(2, "FORBIDDEN_COMMAND_IN_TCL")
    actual_writes = [
        (a.upper(), v.upper())
        for a, v in re.findall(
            r"(?i)\bv113a3_wr\s+(0x[0-9a-f]+)\s+(0x[0-9a-f]+)\s+\S+", tcl
        )
    ]
    expected_writes = [(a.upper(), v.upper()) for a, v in ALLOWLIST]
    if sorted(actual_writes) != sorted(expected_writes):
        return stop(2, f"WRITE_ALLOWLIST_MISMATCH:{actual_writes}")
    if len(re.findall(r"(?im)^\s*v113a3_wr\s+0x40002808\s+", tcl)) != 1:
        return stop(2, "TX_FIFO_WRITE_BUDGET_NOT_ONE")
    if len(re.findall(r"(?im)^\s*v113a3_wr\s+0x40002828\s+0x00000002\s+", tcl)) != 1:
        return stop(2, "STOP_WRITE_BUDGET_NOT_ONE")

    try:
        processes, listeners = host_snapshot()
    except Exception as exc:
        return stop(3, f"HOST_QUERY_FAILED:{exc}")
    if processes or listeners:
        print(json.dumps({"processes": processes, "listeners": listeners}, indent=2))
        return stop(4, "DEBUG_CLIENT_OR_PORT_CONFLICT")
    if MARK.exists():
        return stop(5, f"MARKER_ALREADY_EXISTS:{MARK}")

    now = datetime.now().astimezone()
    run_dir = RUNS / f"{STAGE}_{now.strftime('%Y%m%d_%H%M%S_%f')}"
    run_dir.mkdir(parents=True, exist_ok=False)
    MARK.parent.mkdir(parents=True, exist_ok=True)
    try:
        with MARK.open("x", encoding="utf-8") as marker:
            json.dump(
                {
                    "stage": STAGE,
                    "created_local": now.isoformat(),
                    "target_mmio_write_allowlist": ALLOWLIST,
                    "max_target_mmio_writes": len(ALLOWLIST),
                    "max_tx_fifo_writes": 1,
                    "max_stop_requests": 1,
                    "halt_request_budget": 1,
                    "retries": 0,
                    "reset_resume_flash_nvr_power_cycle": "forbidden",
                    "notes": "Single address-before-enable ordering trial; marker remains even on failure.",
                },
                marker,
                indent=2,
            )
            marker.write("\n")
    except FileExistsError:
        return stop(5, "MARKER_RACE")

    argv = [
        str(OCD),
        "-f",
        str(CFG).replace("\\", "/"),
        "-c",
        f"source {str(TCL).replace(chr(92), '/')}",
    ]
    metadata = {
        "stage": STAGE,
        "argv": argv,
        "cwd": str(OCD_DIR),
        "started_local": now.isoformat(),
        "timeout_s": 240,
        "retry": "none",
        "host_processes": processes,
        "host_listeners": listeners,
        "sha256": {
            "openocd": sha(OCD),
            "cfg": sha(CFG),
            "tcl": sha(TCL),
            "python": sha(Path(__file__)),
        },
    }
    (run_dir / "command.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    try:
        proc = subprocess.run(argv, cwd=OCD_DIR, capture_output=True, timeout=240)
        return_code, stdout, stderr = proc.returncode, proc.stdout, proc.stderr
    except subprocess.TimeoutExpired as exc:
        return_code = None
        stdout = exc.stdout or b""
        stderr = exc.stderr or b""
        (run_dir / "timeout.txt").write_text(
            "OpenOCD timeout; full evidence retained; no retry or recovery.\n", encoding="utf-8"
        )
    (run_dir / "openocd.stdout.log").write_bytes(stdout)
    (run_dir / "openocd.stderr.log").write_bytes(stderr)
    combined = stdout + (b"\n--- STDERR ---\n" if stderr else b"") + stderr
    (run_dir / "openocd.combined.log").write_bytes(combined)
    text = combined.decode("utf-8", errors="replace")
    matches = re.findall(
        r"(?m)^V113A3_RESULT=(\S+) OUTCOME=(.*?) HALT_COUNT=(\d+) TARGET_MMIO_WRITE_COUNT=(\d+) STOP_WRITE_COUNT=(\d+)\s*$",
        text,
    )
    result = {
        "stage": STAGE,
        "return_code": return_code,
        "complete_marker": "V113A3_COMPLETE" in text,
        "status": matches[-1][0] if matches else "INCOMPLETE_OR_UNKNOWN",
        "outcome": matches[-1][1] if matches else None,
        "halt_count": int(matches[-1][2]) if matches else None,
        "target_mmio_write_count": int(matches[-1][3]) if matches else None,
        "stop_write_count": int(matches[-1][4]) if matches else None,
        "host_processes": processes,
        "host_listeners": listeners,
        "log_sha256": {
            name: sha(run_dir / name)
            for name in ("openocd.stdout.log", "openocd.stderr.log", "openocd.combined.log")
        },
        "finished_local": datetime.now().astimezone().isoformat(),
    }
    (run_dir / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    print(f"RUN_DIR={run_dir}")
    return 0 if return_code == 0 and result["complete_marker"] else 1


if __name__ == "__main__":
    sys.exit(main())
