from __future__ import annotations

import hashlib
import json
import os
import pathlib
import re
import socket
import subprocess
import sys
from datetime import datetime

ROOT = pathlib.Path(r"C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX")
BASE = ROOT / "SRAM_CPU_EXEC_PLAN_20261110" / "V119_SRAM_CANARY"
MARKERS = ROOT / "markers"
RUNS = ROOT / "runs_local_v119"
OCD_DIR = pathlib.Path(r"D:\project\tools\tinyriscv-master\tools\openocd")
OCD = OCD_DIR / "openocd.exe"
CFG = ROOT / "V116_CPU_STORE" / "v116b_flash_cpu_probe.cfg"
TCL = BASE / "v119b_dpc_gated_start.tcl"
IMAGE = BASE / "sram_canary.bin"
STAGE = "BBX_V119B_SRAM_DPC_GATED_START_20261110_01"
EXPECTED_IMAGE_SHA = "E53B8FEACE6CBCB573A4DE242F870567ACEEFBED3A202C7A96671DF5282FA971"
EXPECTED_OCD_SHA = "EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27"
EXPECTED_SERIAL = "07000001006700343500000a4e57354aa5a5a5a597969908"


def sha(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest().upper()


def blocked(message: str, code: int = 2) -> int:
    print("BLOCKED:" + message)
    return code


def host_snapshot() -> tuple[list[dict], list[dict]]:
    ps = pathlib.Path(os.environ.get("WINDIR", r"C:\Windows")) / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe"
    query = r'''$names=@('openocd','pyocd','JLinkGDBServerCL','JLinkGDBServer','JLinkExe','ST-LINK_gdbserver','STLinkServer','STM32CubeProgrammer','probe-rs','riscv-none-embed-gdb','riscv64-unknown-elf-gdb','arm-none-eabi-gdb','gdb');$p=@(Get-CimInstance Win32_Process|Where-Object{$names -contains $_.Name.ToLowerInvariant()}|Select-Object ProcessId,Name,ExecutablePath,CommandLine);$n=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue|Where-Object{$_.LocalPort -in @(3333,4444,6666)}|Select-Object LocalAddress,LocalPort,OwningProcess);ConvertTo-Json -Compress -Depth 4 -InputObject @{processes=$p;listeners=$n}'''
    proc = subprocess.run([str(ps), "-NoProfile", "-Command", query], capture_output=True, text=True, timeout=25)
    if proc.returncode:
        raise RuntimeError(f"PROCESS_QUERY_FAILED rc={proc.returncode}: {proc.stderr}")
    data = json.loads(proc.stdout)
    procs, listeners = data.get("processes") or [], data.get("listeners") or []
    if isinstance(procs, dict):
        procs = [procs]
    if isinstance(listeners, dict):
        listeners = [listeners]
    return procs, listeners


def static_audit() -> list[str]:
    issues = []
    for p in (OCD, CFG, TCL, IMAGE):
        if not p.is_file():
            issues.append(f"MISSING:{p}")
    if issues:
        return issues
    if sha(OCD) != EXPECTED_OCD_SHA:
        issues.append("OPENOCD_SHA256_MISMATCH")
    if sha(IMAGE) != EXPECTED_IMAGE_SHA or IMAGE.stat().st_size != 76:
        issues.append("CANARY_IMAGE_IDENTITY_MISMATCH")
    tcl = TCL.read_text(encoding="utf-8")
    checks = {
        "auth gate": "V119B_AUTH_REQUIRED",
        "IDCODE gate": "0x1e200a6f",
        "serial gate": EXPECTED_SERIAL,
        "single DPC entry": "v119b_csr_write_once 0x7B1 $::v119b_entry DPC_ENTRY",
        "DPC readback gate": "DPC_ENTRY_READBACK_MISMATCH_NO_RESUME",
        "no-address resume": "resume\n",
        "completion marker": "V119B_COMPLETE",
        "SRAM bounds": "0x20008000",
        "mailbox address": "0x2000F000",
        "no MMIO count": "TARGET_MMIO_WRITES=0",
    }
    for name, token in checks.items():
        if token not in tcl:
            issues.append("TCL_MISSING:" + name)
    if re.search(r"(?im)^\s*(?:reset|flash|erase|mww|mwh|mwb)\b", tcl):
        issues.append("FORBIDDEN_RESET_FLASH_OR_NATIVE_MMIO_COMMAND")
    if re.search(r"(?im)^[ \t]*resume[ \t]+\S+", tcl):
        issues.append("ADDRESS_FORM_RESUME_FORBIDDEN")
    if re.search(r"0x400[0-9a-f]{5}", tcl, re.I):
        issues.append("MMIO_LITERAL_PRESENT")
    if tcl.count("v119b_csr_write_once 0x7B1 $::v119b_entry DPC_ENTRY") != 1:
        issues.append("DPC_WRITE_BUDGET_NOT_ONE")
    if len(re.findall(r"(?im)^[ \t]*resume[ \t]*$", tcl)) != 1:
        issues.append("RESUME_CURRENT_BUDGET_NOT_ONE")
    if sha(CFG) != "1275374EA7E2E976B7E0F86D48EE2E9389C344B4A8C36D38F215D5E1D36656B4":
        issues.append("CONFIG_SHA256_MISMATCH")
    return issues


def execute() -> int:
    issues = static_audit()
    if issues:
        print("OFFLINE_AUDIT_BLOCKED\n" + "\n".join(issues))
        return 2
    try:
        processes, listeners = host_snapshot()
    except Exception as exc:
        return blocked("HOST_SNAPSHOT_FAILED:" + repr(exc), 3)
    if processes or listeners:
        print("BLOCKED_DEBUG_CLIENT_OR_PORT_CONFLICT")
        print(json.dumps({"processes": processes, "listeners": listeners}, indent=2))
        return 4

    marker = MARKERS / f"{STAGE}.attempted.json"
    if marker.exists():
        return blocked("STAGE_MARKER_ALREADY_EXISTS")
    started = datetime.now().astimezone()
    run = RUNS / f"{STAGE}_{started.strftime('%Y%m%d_%H%M%S_%f')}"
    run.mkdir(parents=True, exist_ok=False)
    MARKERS.mkdir(parents=True, exist_ok=True)
    marker_data = {
        "stage": STAGE,
        "created_local": started.isoformat(),
        "attempted": True,
        "dpc_write_budget": 1,
        "no_argument_resume_budget": 1,
        "halt_request_budget": 2,
        "sram_load_bytes": 76,
        "sram_restore_bytes": 76,
        "cpu_mailbox_writes": 5,
        "mmio_writes": 0,
        "flash_nvr_writes": 0,
        "reset_power_cycle_retry": "forbidden",
    }
    try:
        with marker.open("x", encoding="utf-8") as f:
            json.dump(marker_data, f, indent=2)
            f.write("\n")
    except FileExistsError:
        return blocked("STAGE_MARKER_ALREADY_EXISTS")

    preimage = run / "sram_preimage_0x20008000_76.bin"
    mailbox_preimage = run / "mailbox_preimage_0x2000F000_20.bin"
    argv = [
        str(OCD), "-f", str(CFG).replace("\\", "/"),
        "-c", "set ::v119b_authorized 1",
        "-c", "source " + str(TCL).replace("\\", "/"),
    ]
    env = os.environ.copy()
    env["V119B_IMAGE"] = str(IMAGE).replace("\\", "/")
    env["V119B_PREIMAGE"] = str(preimage).replace("\\", "/")
    env["V119B_MAILBOX_PREIMAGE"] = str(mailbox_preimage).replace("\\", "/")
    (run / "command.json").write_text(json.dumps({
        "stage": STAGE,
        "argv": argv,
        "cwd": str(OCD_DIR),
        "started_local": started.isoformat(),
        "timeout_s": 120,
        "probe_serial_expected": EXPECTED_SERIAL,
        "sha256": {"openocd": sha(OCD), "config": sha(CFG), "tcl": sha(TCL), "image": sha(IMAGE)},
        "host_processes": processes,
        "host_listeners": listeners,
        "allowed_target_effects": ["one DPC CSR write to 0x20008000", "76-byte SRAM canary load and restore", "20-byte mailbox save and restore", "one no-argument resume only if DPC readback matches and hart remains halted", "one failsafe halt if needed"],
        "prohibited": ["MMIO", "Flash/NVR", "reset", "power-cycle", "retry", "address-form resume", "DPC restore"],
    }, indent=2) + "\n", encoding="utf-8")
    print("EXECUTING_ONCE", STAGE)
    print("RUN_DIR", run)
    try:
        cp = subprocess.run(argv, cwd=OCD_DIR, env=env, capture_output=True, timeout=120)
        rc, stdout, stderr, timeout = cp.returncode, cp.stdout, cp.stderr, False
    except subprocess.TimeoutExpired as exc:
        rc = None
        stdout = exc.stdout if isinstance(exc.stdout, bytes) else (exc.stdout or "").encode()
        stderr = exc.stderr if isinstance(exc.stderr, bytes) else (exc.stderr or "").encode()
        timeout = True
        (run / "timeout.txt").write_text("OpenOCD timeout; no retry/reset/resume. Preserve target state and logs.\n", encoding="utf-8")
    (run / "openocd.stdout.log").write_bytes(stdout)
    (run / "openocd.stderr.log").write_bytes(stderr)
    (run / "openocd.combined.log").write_bytes(stdout + b"\n--- STDERR ---\n" + stderr)
    combined = (stdout + b"\n" + stderr).decode("utf-8", errors="replace")
    status_match = re.findall(r"(?m)^V119B_RESULT=(\S+)", combined)
    result = {
        "stage": STAGE,
        "run_dir": str(run),
        "marker": str(marker),
        "openocd_exit_code": rc,
        "timed_out": timeout,
        "complete": "V119B_COMPLETE" in combined,
        "status": status_match[-1] if status_match else "INCOMPLETE_OR_UNKNOWN",
        "dpc_write_attempted": "V119B_CSR_WRITE_ONCE_BEGIN DPC_ENTRY" in combined,
        "dpc_readback": re.findall(r"(?m)^V119B_DPC_READBACK.*$", combined),
        "dpc_write_started_hart": "V119B_DPC_WRITE_STARTED_HART=1" in combined,
        "no_argument_resume_requested": "V119B_RESUME_CURRENT_ONCE" in combined,
        "mailbox_match": "MAILBOX_MATCH=1" in combined,
        "preimage_saved": "V119B_PREIMAGE_SAVED" in combined,
        "preimage_restored": "V119B_PREIMAGE_RESTORE_PASS" in combined,
        "mailbox_saved": "V119B_MAILBOX_PREIMAGE_SAVED" in combined,
        "mailbox_restored": "V119B_MAILBOX_PREIMAGE_RESTORE_PASS" in combined,
        "mmio_writes": 0,
        "flash_nvr_writes": 0,
        "logs_sha256": {n: sha(run / n) for n in ("openocd.stdout.log", "openocd.stderr.log", "openocd.combined.log")},
        "finished_local": datetime.now().astimezone().isoformat(),
    }
    (run / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if rc == 0 and result["complete"] and result["status"] == "SRAM_CANARY_PASS" else 1


if __name__ == "__main__":
    if sys.argv[1:] != ["--execute"]:
        problems = static_audit()
        print("OFFLINE_AUDIT_PASS_NO_HARDWARE" if not problems else "OFFLINE_AUDIT_BLOCKED\n" + "\n".join(problems))
        sys.exit(0 if not problems else 2)
    sys.exit(execute())
