from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
EXP = ROOT / "03_experiments"
OCD_DIR = Path(r"D:\project\tools\tinyriscv-master\tools\openocd")
OCD = OCD_DIR / "openocd.exe"
CFG = EXP / "bbx_v76a_100k.cfg"
TCL = EXP / "v114_progbuf_readback_addi_once.tcl"
STAGE = "BBX_V114_PROGBUF_READBACK_ADDI_01_20261110"
MARKER = ROOT / "markers" / f"{STAGE}.attempted.json"
RUNS = ROOT / "runs_local_v109"
PINS = {
    "openocd": "EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27",
    "cfg": "CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1",
    "tcl": "2BEE3AF2F8CBA21FBCCD420476357882EC0AC7718734FACF01CDD06229BF5215",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def host_snapshot() -> tuple[list[dict], list[dict]]:
    query = r'''$names=@('openocd','pyocd','JLinkGDBServerCL','JLinkGDBServer','JLinkExe','ST-LINK_gdbserver','STLinkServer','STM32CubeProgrammer','probe-rs','riscv-none-embed-gdb','riscv64-unknown-elf-gdb','arm-none-eabi-gdb','gdb');$p=@(Get-CimInstance Win32_Process|Where-Object{$names -contains $_.Name.ToLowerInvariant()}|Select-Object ProcessId,Name,ExecutablePath,CommandLine);$n=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue|Where-Object{$_.LocalPort -in @(3333,4444,6666)}|Select-Object LocalAddress,LocalPort,OwningProcess);ConvertTo-Json -Compress -Depth 4 -InputObject @{processes=$p;listeners=$n}'''
    proc = subprocess.run(["powershell", "-NoProfile", "-Command", query], capture_output=True, text=True, timeout=25)
    if proc.returncode:
        raise RuntimeError(f"HOST_CHECK_FAILED rc={proc.returncode}: {proc.stderr}")
    data = json.loads(proc.stdout)
    procs, listeners = data.get("processes") or [], data.get("listeners") or []
    if isinstance(procs, dict):
        procs = [procs]
    if isinstance(listeners, dict):
        listeners = [listeners]
    return procs, listeners


def audit() -> list[str]:
    issues: list[str] = []
    for label, path in (("OpenOCD", OCD), ("config", CFG), ("Tcl", TCL)):
        if not path.is_file():
            issues.append(f"MISSING_{label}:{path}")
    if issues:
        return issues
    for key, path in (("openocd", OCD), ("cfg", CFG), ("tcl", TCL)):
        actual = sha(path)
        if actual != PINS[key]:
            issues.append(f"PINNED_HASH_MISMATCH:{key}:{actual}")
    cfg = CFG.read_text(encoding="utf-8")
    for directive in ("gdb_port disabled", "telnet_port disabled", "tcl_port disabled", "transport select jtag"):
        if directive not in cfg:
            issues.append(f"CONFIG_MISSING:{directive}")
    tcl = TCL.read_text(encoding="utf-8")
    if re.search(r"(?im)^\s*(?:reset|resume|flash|erase|load_image|mww|mwh|mwb)\b", tcl):
        issues.append("FORBIDDEN_TARGET_OR_FLASH_COMMAND")
    if re.search(r"0x4[0-9a-f]{7}|0x200[0-9a-f]{4,7}", tcl, re.I):
        issues.append("TARGET_MMIO_OR_MEMORY_ADDRESS_LITERAL_PRESENT")
    raw_dmi_writes = re.findall(r"(?im)^\s*riscv\s+dmi_write\s+", tcl)
    if len(raw_dmi_writes) != 1 or not re.search(r"(?s)proc\s+v114_write\s+\{reg\s+value\s+label\}.*?riscv dmi_write", tcl):
        issues.append("DMI_WRITE_NOT_CONFINED_TO_SINGLE_AUDITED_HELPER")
    if not all(token in tcl for token in (
        "V114_AUTH_REQUIRED", "0x00138393", "V114_PROGBUF0_AFTER_WRITE",
        "PROGBUF_NOT_VERIFIED_STOP_BEFORE_EXEC", "V114_RESULT=",
        "V114_COMPLETE", "0x00000013 FINAL_SAFE_NOP",
    )):
        issues.append("REQUIRED_V114_SAFETY_OR_RESULT_CHECK_MISSING")
    if len(re.findall(r"(?im)^\s*incr\s+::v114_postexec_count\s*$", tcl)) != 1:
        issues.append("POSTEXEC_BUDGET_NOT_EXACTLY_ONE")
    if MARKER.exists():
        issues.append(f"STAGE_MARKER_ALREADY_EXISTS:{MARKER}")
    return issues


def execute() -> int:
    issues = audit()
    if issues:
        print("OFFLINE_AUDIT_BLOCKED\n" + "\n".join(issues))
        return 2
    try:
        procs, listeners = host_snapshot()
    except Exception as exc:
        print(f"BLOCKED_HOST_CHECK:{exc}")
        return 3
    if procs or listeners:
        print("BLOCKED_DEBUG_CLIENT_OR_PORT_CONFLICT")
        print(json.dumps({"processes": procs, "listeners": listeners}, indent=2))
        return 4

    started = datetime.now().astimezone()
    run = RUNS / f"{STAGE}_{started.strftime('%Y%m%d_%H%M%S_%f')}"
    run.mkdir(parents=True, exist_ok=False)
    MARKER.parent.mkdir(parents=True, exist_ok=True)
    marker = {
        "stage": STAGE,
        "created_local": started.isoformat(),
        "target_memory_writes": 0,
        "target_mmio_writes": 0,
        "flash_nvr_writes": 0,
        "postexec_budget": 1,
        "halt_request_budget": 1,
        "reset_resume_retry_power_cycle": "forbidden",
        "temporary_debug_state": ["x7", "DPC", "PROGBUF0"],
    }
    try:
        with MARKER.open("x", encoding="utf-8") as f:
            json.dump(marker, f, indent=2)
            f.write("\n")
    except FileExistsError:
        print(f"BLOCKED_STAGE_ALREADY_CONSUMED:{MARKER}")
        return 5

    argv = [str(OCD), "-f", str(CFG).replace("\\", "/"), "-c", "set ::v114_progbuf_authorized 1", "-c", f"source {str(TCL).replace(chr(92), '/')}"]
    metadata = {
        "stage": STAGE,
        "argv": argv,
        "cwd": str(OCD_DIR),
        "started_local": started.isoformat(),
        "timeout_s": 120,
        "retry": "none",
        "host_processes": procs,
        "host_listeners": listeners,
        "sha256": {"openocd": sha(OCD), "cfg": sha(CFG), "tcl": sha(TCL), "python": sha(Path(__file__))},
    }
    (run / "command.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    try:
        proc = subprocess.run(argv, cwd=OCD_DIR, capture_output=True, timeout=120)
        rc, stdout, stderr = proc.returncode, proc.stdout, proc.stderr
    except subprocess.TimeoutExpired as exc:
        rc, stdout, stderr = None, exc.stdout or b"", exc.stderr or b""
        (run / "timeout.txt").write_text("Timeout; logs retained. No retry/reset/resume. Restore status may be unknown.\n", encoding="utf-8")
    (run / "openocd.stdout.log").write_bytes(stdout)
    (run / "openocd.stderr.log").write_bytes(stderr)
    raw = stdout + (b"\n--- STDERR ---\n" if stderr else b"") + stderr
    (run / "openocd.combined.log").write_bytes(raw)
    text = raw.decode("utf-8", errors="replace")
    result_match = re.findall(r"(?m)^V114_RESULT=(\S+) POSTEXEC_COUNT=(\d+) HALT_COUNT=(\d+)\s*$", text)
    result = {
        "stage": STAGE,
        "return_code": rc,
        "complete_marker": "V114_COMPLETE" in text,
        "status": result_match[-1][0] if result_match else "INCOMPLETE_OR_UNKNOWN",
        "postexec_count": int(result_match[-1][1]) if result_match else None,
        "halt_count": int(result_match[-1][2]) if result_match else None,
        "target_memory_writes": 0,
        "target_mmio_writes": 0,
        "log_sha256": {name: sha(run / name) for name in ("openocd.stdout.log", "openocd.stderr.log", "openocd.combined.log")},
        "finished_local": datetime.now().astimezone().isoformat(),
    }
    (run / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    print(f"RUN_DIR={run}")
    return 0 if rc == 0 and result["complete_marker"] else 1


if __name__ == "__main__":
    if "--execute" not in sys.argv:
        problems = audit()
        print("OFFLINE_AUDIT_PASS; no hardware command sent" if not problems else "OFFLINE_AUDIT_BLOCKED\n" + "\n".join(problems))
        sys.exit(0 if not problems else 2)
    sys.exit(execute())

