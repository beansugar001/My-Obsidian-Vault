from __future__ import annotations
import hashlib, json, re, subprocess, sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OCD_DIR = Path(r"D:\project\tools\tinyriscv-master\tools\openocd")
OCD = OCD_DIR / "openocd.exe"
CFG = ROOT / "03_experiments" / "bbx_v76a_100k.cfg"
TCL = ROOT / "03_experiments" / "v109i_native_reset_release_once.tcl"
STAGE = "BBX_V109I_NATIVE_MWW_RESET_RELEASE_01"
MARK = ROOT / "markers" / f"{STAGE}.attempted.json"
RUNS = ROOT / "runs_local_v109"
PINS = {"openocd": "EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27",
        "cfg": "CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1"}

def sha(p: Path) -> str: return hashlib.sha256(p.read_bytes()).hexdigest().upper()

def host_snapshot():
    q = r'''$names=@('openocd','pyocd','JLinkGDBServerCL','JLinkGDBServer','JLinkExe','ST-LINK_gdbserver','STLinkServer','STM32CubeProgrammer','probe-rs','riscv-none-embed-gdb','riscv64-unknown-elf-gdb','arm-none-eabi-gdb','gdb'); $p=@(Get-Process -ErrorAction Stop | Where-Object {$names -contains $_.ProcessName} | Select-Object Id,ProcessName); $n=@(netstat -ano -p tcp | Select-String -Pattern "\sLISTENING\s*$" | ForEach-Object { $f=@($_.Line -split "\s+" | Where-Object {$_}); if($f.Count -ge 5) { $port=[int](($f[1] -split ":")[-1]); if($port -in @(3333,4444,6666)) { [pscustomobject]@{LocalAddress=$f[1];LocalPort=$port;OwningProcess=[int]$f[4]} } } }); ConvertTo-Json -Compress -Depth 4 -InputObject @{processes=$p;listeners=$n}'''
    p = subprocess.run(["powershell", "-NoProfile", "-Command", q], capture_output=True, text=True, timeout=25)
    if p.returncode: raise RuntimeError(f"HOST_QUERY_FAILED rc={p.returncode} {p.stderr}")
    d = json.loads(p.stdout); ps, ls = d.get("processes") or [], d.get("listeners") or []
    if isinstance(ps, dict): ps = [ps]
    if isinstance(ls, dict): ls = [ls]
    return ps, ls

def main() -> int:
    for p in (OCD, CFG, TCL):
        if not p.is_file(): print(f"BLOCKED_MISSING:{p}"); return 2
    if sha(OCD) != PINS["openocd"] or sha(CFG) != PINS["cfg"]: print("BLOCKED_PIN_MISMATCH"); return 2
    t = TCL.read_text(encoding="utf-8")
    if t.count("mww 0x40021810 0x00000000") != 1 or re.search(r"(?im)^\s*(?:reset|resume|flash|erase|program|load_image|mwb|mwh)\b", t):
        print("BLOCKED_WRITE_BUDGET_OR_FORBIDDEN_COMMAND"); return 2
    if MARK.exists(): print(f"BLOCKED_STAGE_CONSUMED:{MARK}"); return 5
    try: ps, ls = host_snapshot()
    except Exception as e: print(f"BLOCKED_HOST_QUERY:{e}"); return 3
    if ps or ls: print("BLOCKED_DEBUG_CONFLICT " + json.dumps({"processes": ps, "listeners": ls}, indent=2)); return 4
    now = datetime.now().astimezone(); run = RUNS / f"{STAGE}_{now.strftime('%Y%m%d_%H%M%S_%f')}"
    run.mkdir(parents=True, exist_ok=False); MARK.parent.mkdir(parents=True, exist_ok=True)
    try:
        with MARK.open("x", encoding="utf-8") as f:
            json.dump({"stage": STAGE, "created_local": now.isoformat(), "allowlist": {"0x40021810": ["0x00000000"]},
                       "target_mmio_write_budget": 1, "restore_or_retry": False}, f, indent=2); f.write("\n")
    except FileExistsError: print("BLOCKED_MARKER_RACE"); return 5
    argv = [str(OCD), "-f", str(CFG).replace("\\", "/"), "-c", f"source {str(TCL).replace(chr(92), '/')}"]
    meta = {"stage": STAGE, "argv": argv, "cwd": str(OCD_DIR), "started_local": now.isoformat(), "host_processes": ps,
            "host_listeners": ls, "sha256": {str(p): sha(p) for p in (OCD, CFG, TCL, Path(__file__))}, "retry": "none"}
    (run / "command.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    try:
        p = subprocess.run(argv, cwd=OCD_DIR, capture_output=True, timeout=120); rc, out, err = p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired as e:
        rc, out, err = None, e.stdout or b"", e.stderr or b""
        (run / "timeout.txt").write_text("Timeout; preserve target state; no retry/reset/resume.\n", encoding="utf-8")
    (run / "openocd.stdout.log").write_bytes(out); (run / "openocd.stderr.log").write_bytes(err)
    raw = out + (b"\n--- STDERR ---\n" if err else b"") + err
    (run / "openocd.combined.log").write_bytes(raw); s = raw.decode("utf-8", errors="replace")
    m = re.search(r"(?m)^V109I_RESULT=(\S+) HALT_COUNT=(\d+) TARGET_MMIO_WRITE_COUNT=(\d+)\s*$", s)
    res = {"stage": STAGE, "return_code": rc, "complete": "V109I_COMPLETE" in s, "status": m.group(1) if m else "INCOMPLETE_OR_UNKNOWN",
           "halt_count": int(m.group(2)) if m else None, "target_mmio_write_count": int(m.group(3)) if m else None,
           "log_sha256": {n: sha(run / n) for n in ("openocd.stdout.log", "openocd.stderr.log", "openocd.combined.log")},
           "finished_local": datetime.now().astimezone().isoformat()}
    (run / "result.json").write_text(json.dumps(res, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(res, indent=2)); print(f"RUN_DIR={run}")
    return 0 if rc == 0 and res["complete"] and res["status"] == "PASS_RESET_RELEASED_NATIVE_MWW" and res["target_mmio_write_count"] == 1 else 1

if __name__ == "__main__": sys.exit(main())
