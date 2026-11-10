from __future__ import annotations
import hashlib, json, re, subprocess, sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OCD_DIR = Path(r"D:\project\tools\tinyriscv-master\tools\openocd")
OCD = OCD_DIR / "openocd.exe"
CFG = ROOT / "03_experiments" / "bbx_v76a_100k.cfg"
TCL = ROOT / "03_experiments" / "v115a_post_replug_baseline.tcl"
STAGE = "BBX_V115A_POST_REPLUG_BASELINE_20261110_01"
MARK = ROOT / "markers" / f"{STAGE}.attempted.json"
RUNS = ROOT / "runs_local_v109"
PINS = {
    "openocd": "EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27",
    "cfg": "CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1",
}

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def host_snapshot():
    query = r'''$names=@('openocd','pyocd','JLinkGDBServerCL','JLinkGDBServer','JLinkExe','ST-LINK_gdbserver','STLinkServer','STM32CubeProgrammer','probe-rs','riscv-none-embed-gdb','riscv64-unknown-elf-gdb','arm-none-eabi-gdb','gdb');$p=@(Get-CimInstance Win32_Process|Where-Object{$names -contains $_.Name.ToLowerInvariant()}|Select-Object ProcessId,Name,ExecutablePath,CommandLine);$n=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue|Where-Object{$_.LocalPort -in @(3333,4444,6666)}|Select-Object LocalAddress,LocalPort,OwningProcess);ConvertTo-Json -Compress -Depth 4 -InputObject @{processes=$p;listeners=$n}'''
    r = subprocess.run(["powershell", "-NoProfile", "-Command", query], capture_output=True, text=True, timeout=30)
    if r.returncode:
        raise RuntimeError(f"HOST_SNAPSHOT_FAILED rc={r.returncode}: {r.stderr}")
    d = json.loads(r.stdout)
    ps, ns = d.get("processes") or [], d.get("listeners") or []
    return ([ps] if isinstance(ps, dict) else ps), ([ns] if isinstance(ns, dict) else ns)

def audit():
    errors = []
    for key, path in (("openocd", OCD), ("cfg", CFG), ("tcl", TCL)):
        if not path.is_file():
            errors.append(f"MISSING:{key}:{path}")
        elif key in PINS and sha(path) != PINS[key]:
            errors.append(f"PINNED_HASH_MISMATCH:{key}:{sha(path)}")
    if TCL.is_file():
        t = TCL.read_text(encoding="utf-8")
        if re.search(r"(?im)^\s*(?:mww|mwh|mwb|reset|resume|flash|erase|load_image)\b", t):
            errors.append("FORBIDDEN_TARGET_WRITE_OR_CONTROL_COMMAND")
        if "V115A_COMPLETE" not in t or "TARGET_MMIO_WRITE_COUNT=0" not in t:
            errors.append("COMPLETION_OR_ZERO_WRITE_ASSERTION_MISSING")
        if not all(x in t for x in ("0x4002180C", "0x40021810", "V115A_DMSTATUS", "riscv.cpu curstate")):
            errors.append("READONLY_BASELINE_GATES_MISSING")
    if MARK.exists():
        errors.append(f"MARKER_ALREADY_EXISTS:{MARK}")
    return errors

def main():
    errors = audit()
    if errors:
        print("OFFLINE_AUDIT_BLOCKED\n" + "\n".join(errors))
        return 2
    if "--execute-read-only" not in sys.argv:
        print("OFFLINE_AUDIT_PASS; no target accessed")
        print(json.dumps({"sha256": {"openocd": sha(OCD), "cfg": sha(CFG), "tcl": sha(TCL), "runner": sha(Path(__file__))}}, indent=2))
        return 0
    try:
        processes, listeners = host_snapshot()
    except Exception as exc:
        print(f"BLOCKED_HOST_SNAPSHOT:{exc}")
        return 3
    if processes or listeners:
        print("BLOCKED_DEBUG_CLIENT_OR_PORT_CONFLICT")
        print(json.dumps({"processes": processes, "listeners": listeners}, indent=2))
        return 4
    now = datetime.now().astimezone()
    run = RUNS / f"{STAGE}_{now.strftime('%Y%m%d_%H%M%S_%f')}"
    run.mkdir(parents=True, exist_ok=False)
    MARK.parent.mkdir(parents=True, exist_ok=True)
    try:
        with MARK.open("x", encoding="utf-8") as f:
            json.dump({"stage": STAGE, "started_local": now.isoformat(), "target_mmio_writes": 0,
                       "halt_request_budget": 1, "reset_resume_flash_retry": "forbidden"}, f, indent=2)
            f.write("\n")
    except FileExistsError:
        print("BLOCKED_MARKER_RACE; no target command started")
        return 5
    argv = [str(OCD), "-f", str(CFG).replace("\\", "/"), "-c", f"source {str(TCL).replace(chr(92), '/')}"]
    meta = {"stage": STAGE, "argv": argv, "cwd": str(OCD_DIR), "started_local": now.isoformat(),
            "host_processes": processes, "host_listeners": listeners,
            "sha256": {"openocd": sha(OCD), "cfg": sha(CFG), "tcl": sha(TCL), "runner": sha(Path(__file__))}}
    (run / "command.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    try:
        p = subprocess.run(argv, cwd=OCD_DIR, capture_output=True, timeout=180)
        rc, out, err = p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired as exc:
        rc, out, err = None, exc.stdout or b"", exc.stderr or b""
        (run / "timeout.txt").write_text("Timed out; evidence preserved; no retry.\n", encoding="utf-8")
    (run / "openocd.stdout.log").write_bytes(out)
    (run / "openocd.stderr.log").write_bytes(err)
    combined = out + (b"\n--- STDERR ---\n" if err else b"") + err
    (run / "openocd.combined.log").write_bytes(combined)
    s = combined.decode("utf-8", errors="replace")
    m = re.findall(r"(?m)^V115A_RESULT=(\S+) HALT_COUNT=(\d+) TARGET_MMIO_WRITE_COUNT=(\d+)\s*$", s)
    result = {"stage": STAGE, "return_code": rc, "completion_marker": "V115A_COMPLETE" in s,
              "status": m[-1][0] if m else "INCOMPLETE_OR_UNKNOWN",
              "halt_count": int(m[-1][1]) if m else None,
              "target_mmio_write_count": int(m[-1][2]) if m else None,
              "log_sha256": {n: sha(run / n) for n in ("openocd.stdout.log", "openocd.stderr.log", "openocd.combined.log")},
              "finished_local": datetime.now().astimezone().isoformat()}
    (run / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    print(f"RUN_DIR={run}")
    return 0 if rc == 0 and result["completion_marker"] else 1

if __name__ == "__main__":
    sys.exit(main())
