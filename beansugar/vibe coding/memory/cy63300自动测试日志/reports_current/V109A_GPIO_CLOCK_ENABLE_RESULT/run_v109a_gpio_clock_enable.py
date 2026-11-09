from __future__ import annotations
import hashlib, json, re, subprocess, sys
from datetime import datetime
from pathlib import Path

PROJECT=Path(r"C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX")
OCD_DIR=Path(r"D:\project\tools\tinyriscv-master\tools\openocd")
OCD=OCD_DIR/"openocd.exe"
CFG=PROJECT/"03_experiments"/"bbx_v76a_100k.cfg"
TCL=Path(r"C:\Users\24796\Documents\组\v109a_gpio_clock_enable.tcl")
STAGE="BBX_V109A_GPIO_CLOCK_ENABLE_01"
MARKER=PROJECT/"markers"/f"{STAGE}.attempted.json"
RUNS=PROJECT/"runs"
PINNED={"openocd":"EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27","cfg":"CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1"}

def sha(p:Path)->str:return hashlib.sha256(p.read_bytes()).hexdigest().upper()

def host_snapshot():
    q=r'''
$names=@('openocd','pyocd','JLinkGDBServerCL','JLinkGDBServer','JLinkExe','ST-LINK_gdbserver','STLinkServer','STM32CubeProgrammer','probe-rs','riscv-none-embed-gdb','riscv64-unknown-elf-gdb','arm-none-eabi-gdb','gdb')
$p=@(Get-Process -ErrorAction Stop | Where-Object { $names -contains $_.ProcessName } | Select-Object Id,ProcessName)
$n=@(Get-NetTCPConnection -State Listen -ErrorAction Stop | Where-Object { $_.LocalPort -in @(3333,4444,6666) } | Select-Object LocalAddress,LocalPort,OwningProcess)
ConvertTo-Json -Compress -Depth 4 -InputObject @{processes=$p;listeners=$n}
'''
    p=subprocess.run(["powershell","-NoProfile","-Command",q],capture_output=True,text=True,timeout=25)
    if p.returncode:raise RuntimeError(f"HOST_QUERY_FAILED rc={p.returncode} {p.stderr}")
    d=json.loads(p.stdout);procs=d.get("processes") or [];ports=d.get("listeners") or []
    if isinstance(procs,dict):procs=[procs]
    if isinstance(ports,dict):ports=[ports]
    return procs,ports

def main()->int:
    for p in (OCD,CFG,TCL):
        if not p.is_file():print(f"BLOCKED_MISSING_FILE:{p}");return 2
    if sha(OCD)!=PINNED["openocd"] or sha(CFG)!=PINNED["cfg"]:print("BLOCKED_PINNED_HASH_MISMATCH");return 2
    t=TCL.read_text(encoding="utf-8")
    if re.search(r"(?im)^\s*(?:reset|resume|flash|erase|load_image|mww|mwh|mwb)\b",t):print("BLOCKED_FORBIDDEN_TARGET_COMMAND");return 2
    writes=re.findall(r"(?im)^\s*v109a_dmi_write\s+0x3c\s+(\S+)",t)
    if writes!=["0x00000001"]:print(f"BLOCKED_SBDATA0_WRITE_BUDGET:{writes}");return 2
    if "set ::v109a_target_write_count 0" not in t or "V109A_TARGET_MMIO_WRITE_ATTEMPT" not in t:print("BLOCKED_WRITE_COUNTER_MISSING");return 2
    try:procs,ports=host_snapshot()
    except Exception as e:print(f"BLOCKED_HOST_SNAPSHOT:{e}");return 3
    if procs or ports:print("BLOCKED_DEBUG_CLIENT_CONFLICT "+json.dumps({"processes":procs,"listeners":ports},indent=2));return 4
    if MARKER.exists():print(f"BLOCKED_STAGE_MARKER_EXISTS:{MARKER}");return 5
    now=datetime.now().astimezone();run=RUNS/f"{STAGE}_{now.strftime('%Y%m%d_%H%M%S_%f')}";run.mkdir(parents=True,exist_ok=False);MARKER.parent.mkdir(parents=True,exist_ok=True)
    try:
        with MARKER.open("x",encoding="utf-8") as f:
            json.dump({"stage":STAGE,"created_local":now.isoformat(),"target_mmio_write_budget":1,"only_target_write":{"address":"0x4002180C","value":"0x00000001"},"halt_request_budget":0,"retry":"none"},f,indent=2);f.write("\n")
    except FileExistsError:print("BLOCKED_MARKER_RACE");return 5
    argv=[str(OCD),"-f",str(CFG).replace("\\","/"),"-c",f"source {str(TCL).replace(chr(92),'/')}" ]
    meta={"stage":STAGE,"argv":argv,"cwd":str(OCD_DIR),"started_local":now.isoformat(),"timeout_s":120,"retry":"none","host_processes":procs,"host_listeners":ports,"known_nonconflicting_quartus_jtagserver":{"service":"Altera JTAG Server","pid":16884,"listener":"0.0.0.0:1309"},"sha256":{str(p):sha(p) for p in (OCD,CFG,TCL,Path(__file__))}}
    (run/"command.json").write_text(json.dumps(meta,indent=2)+"\n",encoding="utf-8")
    try:p=subprocess.run(argv,cwd=OCD_DIR,capture_output=True,timeout=120);rc,out,err=p.returncode,p.stdout,p.stderr
    except subprocess.TimeoutExpired as e:rc=None;out=e.stdout or b"";err=e.stderr or b"";(run/"timeout.txt").write_text("Timeout; partial logs retained; no retry.\n",encoding="utf-8")
    (run/"openocd.stdout.log").write_bytes(out);(run/"openocd.stderr.log").write_bytes(err);combined=out+(b"\n--- STDERR ---\n" if err else b"")+err;(run/"openocd.combined.log").write_bytes(combined);s=combined.decode("utf-8",errors="replace")
    m=re.findall(r"(?m)^V109A_RESULT=(\S+) TARGET_MMIO_WRITE_COUNT=(\d+) GPIO=(\S+)\s*$",s)
    r={"stage":STAGE,"return_code":rc,"complete":"V109A_COMPLETE" in s,"status":m[-1][0] if m else "INCOMPLETE_OR_UNKNOWN","target_mmio_write_count":int(m[-1][1]) if m else None,"gpio_snapshot":m[-1][2] if m else None,"host_processes":procs,"host_listeners":ports,"log_sha256":{n:sha(run/n) for n in ("openocd.stdout.log","openocd.stderr.log","openocd.combined.log")},"finished_local":datetime.now().astimezone().isoformat()}
    (run/"result.json").write_text(json.dumps(r,indent=2)+"\n",encoding="utf-8");print(json.dumps(r,indent=2));print(f"RUN_DIR={run}")
    return 0 if rc==0 and r["complete"] and r["target_mmio_write_count"]==1 else 1

if __name__=="__main__":sys.exit(main())
