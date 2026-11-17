import argparse
import hashlib
import json
import re
import subprocess
from datetime import datetime, timedelta, timezone
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
OCD_DIR = Path(r"D:\project\tools\tinyriscv-master\tools\openocd")
OCD = OCD_DIR / "openocd.exe"
CFG = ROOT / "03_experiments" / "bbx_v76a_100k.cfg"
TCL = HERE / "v140_cold_pad1.tcl"
STAGE = "BBX_V140_COLD_PAD1_AF6_20261111_01"
MARKER = ROOT / "markers" / f"{STAGE}.attempted.json"
RUNS = HERE / "runs"
LOCAL_TZ = timezone(timedelta(hours=8))
PINNED = {
    OCD: "EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27",
    CFG: "CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1",
    TCL: "6FA0D0CDA85FCB84BEBCD27D4CF7ED3E926461ADA7101F5C1D8858D2BC671FA5",
}
PASS = {"TX_DRAINED_STOP_IDLE", "TX_EMPTY_AND_IDLE"}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def audit():
    for path, expected in PINNED.items():
        if sha256(path) != expected:
            raise RuntimeError(f"PINNED_HASH_MISMATCH:{path}")
    if MARKER.exists():
        raise RuntimeError(f"MARKER_ALREADY_EXISTS:{MARKER}")


def host_snapshot():
    query = r"""
$ErrorActionPreference = 'Stop'
$names = @('openocd','pyocd','JLinkGDBServerCL','JLinkGDBServer','JLinkExe',
    'ST-LINK_gdbserver','STLinkServer','STM32CubeProgrammer','probe-rs',
    'riscv-none-embed-gdb','riscv64-unknown-elf-gdb','arm-none-eabi-gdb','gdb')
$processes = @(Get-CimInstance Win32_Process | Where-Object {
    $base = [IO.Path]::GetFileNameWithoutExtension($_.Name)
    $names -contains $base -or
    ($base -match '^pythonw?\d*$' -and $_.CommandLine -match 'dap_tdo_loopback|pyocd')
} | Select-Object ProcessId,Name,ExecutablePath)
$listeners = @(Get-NetTCPConnection -State Listen | Where-Object {
    $_.LocalPort -in @(3333,4444,6666)
} | Select-Object LocalAddress,LocalPort,OwningProcess)
ConvertTo-Json -Compress -Depth 4 -InputObject @{processes=$processes;listeners=$listeners}
"""
    result = subprocess.run(
        ["powershell", "-NoProfile", "-Command", query],
        capture_output=True, text=True, timeout=30,
    )
    if result.returncode != 0:
        raise RuntimeError(f"HOST_QUERY_FAILED:{result.stderr.strip()}")
    return json.loads(result.stdout)


def save_json(path, data):
    with path.open("x", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def run_target(run, argv):
    stdout = run / "openocd.stdout.log"
    stderr = run / "openocd.stderr.log"
    rc = None
    failure = None
    with stdout.open("xb") as out, stderr.open("xb") as err:
        try:
            rc = subprocess.run(
                argv, cwd=OCD_DIR, stdout=out, stderr=err, timeout=300,
            ).returncode
        except (OSError, subprocess.TimeoutExpired) as exc:
            failure = str(exc)
    combined = run / "openocd.combined.log"
    raw = stdout.read_bytes() + b"\n--- STDERR ---\n" + stderr.read_bytes()
    combined.write_bytes(raw)
    log = raw.decode("utf-8", errors="replace")
    results = re.findall(r"(?m)^V140_RESULT=(\S+) HALTS=(\d+) WRITES=(\d+)\r?$", log)
    completed = log.splitlines().count("V140_COMPLETE") == 1
    attempts = re.findall(r"(?m)^V140_WRITE_ATTEMPT count=(\d+) (\S+)", log)
    halt_attempts = log.splitlines().count("V140_HALT_ATTEMPT")
    consistent = False
    status = "INCOMPLETE_OR_UNKNOWN"
    if len(results) == 1 and completed and rc == 0:
        declared, halts, writes = results[0]
        consistent = (
            int(halts) == halt_attempts <= 1
            and int(writes) == len(attempts) <= 19
            and [int(count) for count, _ in attempts] == list(range(1, len(attempts) + 1))
        )
        if consistent:
            status = declared
    errors = re.findall(r"(?m)^V140_ERROR=([^\r\n]*)", log)
    samples = [line for line in log.splitlines() if line.startswith("V140_SAMPLE ")]
    result = {
        "stage": STAGE,
        "status": status,
        "return_code": rc,
        "process_error": failure,
        "complete": completed,
        "counts_verified": consistent,
        "logged_halt_attempts": halt_attempts,
        "logged_write_attempts": len(attempts),
        "tx_fifo_attempts": sum(label == "ONE_CONTROL_BYTE" for _, label in attempts),
        "stop_attempts": sum(label == "STOP_AFTER_DRAIN" for _, label in attempts),
        "errors": errors,
        "sample_count": len(samples),
        "first_sample": samples[0] if samples else None,
        "last_sample": samples[-1] if samples else None,
        "log_sha256": {path.name: sha256(path) for path in (stdout, stderr, combined)},
        "finished": datetime.now(LOCAL_TZ).isoformat(),
    }
    save_json(run / "result.json", result)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if status in PASS else 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    try:
        audit()
        if not args.execute:
            print("V140_OFFLINE_AUDIT_PASS")
            return 0
        host = host_snapshot()
        if host["processes"] or host["listeners"]:
            raise RuntimeError(f"DEBUG_CONFLICT:{json.dumps(host)}")
        audit()
        started = datetime.now(LOCAL_TZ)
        run = RUNS / started.strftime("%Y%m%d_%H%M%S_%f")
        run.mkdir(parents=True)
        argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + TCL.as_posix() + "}"]
        meta = {
            "stage": STAGE,
            "started": started.isoformat(),
            "argv": argv,
            "cwd": str(OCD_DIR),
            "host": host,
            "sha256": {str(path): sha256(path) for path in (*PINNED, Path(__file__))},
        }
        save_json(run / "command.json", meta)
        save_json(MARKER, {
            "stage": STAGE, "run": str(run), "started": started.isoformat(),
            "max_init_writes": 17, "max_fifo_writes": 1, "max_conditional_stop": 1,
            "max_halt": 1, "tcl_sha256": PINNED[TCL],
        })
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as exc:
        print(f"V140_START_BLOCKED:{exc}")
        return 2
    print(f"RUN_DIR={run}", flush=True)
    return run_target(run, argv)


if __name__ == "__main__":
    raise SystemExit(main())
