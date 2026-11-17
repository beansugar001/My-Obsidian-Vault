from __future__ import annotations

import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
from datetime import datetime

ROOT = pathlib.Path(r"C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX")
STAGE_DIR = ROOT / "I2C_NEXT_PHASE_20261110_01"
RUNS = ROOT / "runs_local_i2c_next"
MARKERS = ROOT / "markers"
STAGE = "BBX_V138_PADMUX_READONLY_20261110_01"
OPENOCD_DIR = pathlib.Path(r"D:\project\tools\tinyriscv-master\tools\openocd")
OCD = OPENOCD_DIR / "openocd.exe"
CFG = ROOT / "V116_CPU_STORE" / "v116b_flash_cpu_probe.cfg"
TCL = STAGE_DIR / "v138_mux_readonly.tcl"
PINNED = {
    "openocd": "EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27",
    "cfg": "1275374EA7E2E976B7E0F86D48EE2E9389C344B4A8C36D38F215D5E1D36656B4",
}


def sha(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def check_host() -> tuple[list, list]:
    ps = pathlib.Path(os.environ.get("WINDIR", r"C:\Windows")) / "System32/WindowsPowerShell/v1.0/powershell.exe"
    script = r'''$names=@('openocd','pyocd','JLinkGDBServerCL','JLinkGDBServer','JLinkExe','JLinkRTTViewer','ST-LINK_gdbserver','STLinkServer','STM32_Programmer_CLI','probe-rs','riscv-none-embed-gdb','riscv64-unknown-elf-gdb','arm-none-eabi-gdb','gdb');$p=@(Get-CimInstance Win32_Process|Where-Object{$names -contains $_.Name}|Select-Object ProcessId,Name,ExecutablePath,CommandLine);$n=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue|Where-Object{$_.LocalPort -in @(3333,4444,6666)}|Select-Object LocalAddress,LocalPort,OwningProcess);ConvertTo-Json -Compress -Depth 4 -InputObject @{processes=$p;listeners=$n}'''
    cp = subprocess.run([str(ps), "-NoProfile", "-Command", script], capture_output=True, text=True, timeout=30)
    if cp.returncode:
        raise RuntimeError(f"HOST_QUERY_FAILED rc={cp.returncode} stderr={cp.stderr}")
    result = json.loads(cp.stdout)
    processes = result.get("processes") or []
    listeners = result.get("listeners") or []
    return ([processes] if isinstance(processes, dict) else processes,
            [listeners] if isinstance(listeners, dict) else listeners)


def audit() -> str | None:
    for path in (OCD, CFG, TCL):
        if not path.is_file():
            return f"MISSING:{path}"
    if sha(OCD) != PINNED["openocd"]:
        return "OPENOCD_SHA256_MISMATCH"
    if sha(CFG) != PINNED["cfg"]:
        return "CONFIG_SHA256_MISMATCH"
    text = TCL.read_text(encoding="utf-8")
    if text.count("halt 2000") != 1:
        return "HALT_REQUEST_BUDGET_NOT_ONE"
    if re.search(r"(?im)^\s*(mww|mwh|mwb|resume|reset|flash|erase|load_image)\b", text):
        return "FORBIDDEN_COMMAND_IN_TCL"
    for needed in ("TARGET_MMIO_WRITES=0", "FIFO_WRITES=0", "I2C_EN_WRITES=0", "STAGE_COMPLETE"):
        if needed not in text:
            return f"MISSING_STOP_MARKER:{needed}"
    return None


def main() -> int:
    if sys.argv[1:] != ["--execute"]:
        err = audit()
        print("OFFLINE_AUDIT_PASS_NO_HARDWARE" if not err else f"BLOCKED:{err}")
        return 0 if not err else 2
    err = audit()
    if err:
        print(f"BLOCKED:{err}")
        return 2
    try:
        processes, listeners = check_host()
    except Exception as exc:
        print(f"BLOCKED_HOST_CHECK:{exc!r}")
        return 3
    if processes or listeners:
        print("BLOCKED_DEBUG_CLIENT_OR_PORT_CONFLICT")
        print(json.dumps({"processes": processes, "listeners": listeners}, indent=2))
        return 4
    marker = MARKERS / f"{STAGE}.attempted.json"
    if marker.exists():
        print(f"BLOCKED_MARKER_ALREADY_EXISTS:{marker}")
        return 5
    started = datetime.now().astimezone()
    run = RUNS / f"{STAGE}_{started.strftime('%Y%m%d_%H%M%S_%f')}"
    run.mkdir(parents=True, exist_ok=False)
    MARKERS.mkdir(parents=True, exist_ok=True)
    try:
        with marker.open("x", encoding="utf-8") as stream:
            json.dump({"stage": STAGE, "attempted": True, "target_mmio_writes": 0,
                       "halt_request_budget": 1, "created_local": started.isoformat()}, stream, indent=2)
            stream.write("\n")
    except FileExistsError:
        print(f"BLOCKED_MARKER_ALREADY_EXISTS:{marker}")
        return 5
    argv = [str(OCD), "-f", str(CFG).replace("\\", "/"), "-c", "source " + str(TCL).replace("\\", "/")]
    command = {"stage": STAGE, "argv": argv, "cwd": str(OPENOCD_DIR),
               "started_local": started.isoformat(), "probe_serial_required": "07000001006700343500000a4e57354aa5a5a5a597969908",
               "marker": str(marker), "sha256": {"openocd": sha(OCD), "cfg": sha(CFG), "tcl": sha(TCL)}}
    (run / "command.json").write_text(json.dumps(command, indent=2) + "\n", encoding="utf-8")
    timed_out = False
    try:
        completed = subprocess.run(argv, cwd=OPENOCD_DIR, capture_output=True, timeout=90)
        rc, out, err_bytes = completed.returncode, completed.stdout, completed.stderr
    except subprocess.TimeoutExpired as exc:
        rc, out, err_bytes, timed_out = None, exc.stdout or b"", exc.stderr or b"", True
        (run / "timeout.txt").write_text("OpenOCD timeout; preserved; no retry/reset/resume.\n", encoding="utf-8")
    (run / "openocd.stdout.log").write_bytes(out)
    (run / "openocd.stderr.log").write_bytes(err_bytes)
    combined = out + b"\n--- STDERR ---\n" + err_bytes
    (run / "openocd.combined.log").write_bytes(combined)
    log = combined.decode("utf-8", errors="replace")
    stage_match = re.findall(r"(?m)^STAGE_RESULT=(\S+)", log)
    result = {"stage": STAGE, "run_dir": str(run), "marker": str(marker), "exit_code": rc,
              "timed_out": timed_out, "complete": "STAGE_COMPLETE" in log,
              "status": stage_match[-1] if stage_match else "INCOMPLETE_OR_UNKNOWN",
              "target_mmio_writes": 0, "reset_resume_flash_nvr": 0,
              "halt_request_budget": 1,
              "sha256": {name: sha(run / name) for name in ("openocd.stdout.log", "openocd.stderr.log", "openocd.combined.log")}}
    (run / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if rc == 0 and result["complete"] and result["status"] == "PASS_CLEAN_I2C_BASELINE" else 1


if __name__ == "__main__":
    raise SystemExit(main())

