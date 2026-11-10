from __future__ import annotations
import hashlib, json, re, subprocess, sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OCD_DIR = Path(r"D:\project\tools\tinyriscv-master\tools\openocd")
OCD = OCD_DIR / "openocd.exe"
CFG = ROOT / "03_experiments" / "bbx_v76a_100k.cfg"
TCL = ROOT / "03_experiments" / "v112a2_gpio_pullup_signature.tcl"
STAGE = "BBX_V112A2_GPIO_PULLUP_SIGNATURE_01"
MARK = ROOT / "markers" / f"{STAGE}.attempted.json"
RUNS = ROOT / "runs_local_v109"
PINNED = {
    "openocd": "EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27",
    "cfg": "CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1",
}

def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest().upper()

def host_snapshot():
    query = r'''$names=@('openocd','pyocd','JLinkGDBServerCL','JLinkGDBServer','JLinkExe','ST-LINK_gdbserver','STLinkServer','STM32CubeProgrammer','probe-rs','riscv-none-embed-gdb','riscv64-unknown-elf-gdb','arm-none-eabi-gdb','gdb'); $p=@(Get-Process -ErrorAction Stop | Where-Object {$names -contains $_.ProcessName} | Select-Object Id,ProcessName); $n=@(netstat -ano -p tcp | Select-String -Pattern "\sLISTENING\s*$" | ForEach-Object { $f=@($_.Line -split "\s+" | Where-Object {$_}); if($f.Count -ge 5) { $port=[int](($f[1] -split ":")[-1]); if($port -in @(3333,4444,6666)) { [pscustomobject]@{LocalAddress=$f[1];LocalPort=$port;OwningProcess=[int]$f[4]} } } }); ConvertTo-Json -Compress -Depth 4 -InputObject @{processes=$p;listeners=$n}'''
    p = subprocess.run(["powershell", "-NoProfile", "-Command", query], capture_output=True, text=True, timeout=25)
    if p.returncode:
        raise RuntimeError(f"HOST_QUERY_FAILED rc={p.returncode}: {p.stderr}")
    d = json.loads(p.stdout)
    ps, listeners = d.get("processes") or [], d.get("listeners") or []
    if isinstance(ps, dict): ps = [ps]
    if isinstance(listeners, dict): listeners = [listeners]
    return ps, listeners

def main() -> int:
    for p in (OCD, CFG, TCL):
        if not p.is_file():
            print(f"BLOCKED_MISSING_FILE:{p}"); return 2
    if sha(OCD) != PINNED["openocd"] or sha(CFG) != PINNED["cfg"]:
        print("BLOCKED_PINNED_HASH_MISMATCH"); return 2
    tcl = TCL.read_text(encoding="utf-8")
    if re.search(r"(?im)^\s*(?:reset|resume|flash|erase|load_image|mww|mwh|mwb)\b", tcl):
        print("BLOCKED_FORBIDDEN_COMMAND"); return 2
    if re.search(r"(?i)0x400028(?:00|08|0C|10|14|20|24|28|38|3C|58)", tcl):
        print("BLOCKED_I2C_REGISTER_ACCESS"); return 2
    needed = ["set ::v112a2_serial \"07000001006700343500000a4e57354aa5a5a5a597969908\"",
              "if {$pupd != 0} {error \"PUPD_NOT_DEFAULT_ZERO_NO_WRITE\"}",
              "set ::v112a2_write_count 1", "0x4000015C value=0x00000300",
              "v112a2_dwrite 0x39 0x4000015C PUPD_ADDRESS",
              "v112a2_dwrite 0x3C 0x300 PUPD_DATA", "V112A2_COMPLETE"]
    if any(x not in tcl for x in needed):
        print("BLOCKED_TCL_WRITE_ALLOWLIST_AUDIT"); return 2
    if MARK.exists():
        print(f"BLOCKED_STAGE_ALREADY_CONSUMED:{MARK}"); return 5
    try:
        ps, listeners = host_snapshot()
    except Exception as e:
        print(f"BLOCKED_HOST_QUERY:{e}"); return 3
    if ps or listeners:
        print("BLOCKED_DEBUG_CLIENT_CONFLICT " + json.dumps({"processes": ps, "listeners": listeners}, indent=2)); return 4
    now = datetime.now().astimezone()
    run = RUNS / f"{STAGE}_{now.strftime('%Y%m%d_%H%M%S_%f')}"
    run.mkdir(parents=True, exist_ok=False)
    MARK.parent.mkdir(parents=True, exist_ok=True)
    try:
        with MARK.open("x", encoding="utf-8") as f:
            json.dump({"stage": STAGE, "created_local": now.isoformat(), "target_mmio_write_budget": 1,
                       "only_target_write": {"address": "0x4000015C", "value": "0x00000300"},
                       "i2c_controller_or_fifo_access": False, "frame_count": 0, "retry": "none"}, f, indent=2)
            f.write("\n")
    except FileExistsError:
        print("BLOCKED_MARKER_RACE"); return 5
    argv = [str(OCD), "-f", str(CFG).replace("\\", "/"), "-c", f"source {str(TCL).replace(chr(92), '/')}"]
    meta = {"stage": STAGE, "argv": argv, "cwd": str(OCD_DIR), "started_local": now.isoformat(),
            "host_processes": ps, "host_listeners": listeners, "retry": "none",
            "sha256": {str(p): sha(p) for p in (OCD, CFG, TCL, Path(__file__))}}
    (run / "command.json").write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    try:
        p = subprocess.run(argv, cwd=OCD_DIR, capture_output=True, timeout=120)
        rc, out, err = p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired as e:
        rc, out, err = None, e.stdout or b"", e.stderr or b""
        (run / "timeout.txt").write_text("Timeout; preserve target state; no retry.\n", encoding="utf-8")
    (run / "openocd.stdout.log").write_bytes(out)
    (run / "openocd.stderr.log").write_bytes(err)
    raw = out + (b"\n--- STDERR ---\n" if err else b"") + err
    (run / "openocd.combined.log").write_bytes(raw)
    text = raw.decode("utf-8", errors="replace")
    m = re.findall(r"(?m)^V112A2_RESULT=(\S+) WRITE_COUNT=(\d+) FINAL_SBCS=(\S+)\s*$", text)
    result = {"stage": STAGE, "return_code": rc, "complete": "V112A2_COMPLETE" in text,
              "status": m[-1][0] if m else "INCOMPLETE_OR_UNKNOWN",
              "target_mmio_write_count": int(m[-1][1]) if m else None,
              "final_sbcs": m[-1][2] if m else "UNKNOWN",
              "openocd_errors": bool(re.search(r"(?im)^Error:", text)),
              "log_sha256": {n: sha(run / n) for n in ("openocd.stdout.log", "openocd.stderr.log", "openocd.combined.log")},
              "finished_local": datetime.now().astimezone().isoformat()}
    (run / "result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2)); print(f"RUN_DIR={run}")
    return 0 if rc == 0 and result["complete"] and not result["openocd_errors"] else 1

if __name__ == "__main__":
    sys.exit(main())
