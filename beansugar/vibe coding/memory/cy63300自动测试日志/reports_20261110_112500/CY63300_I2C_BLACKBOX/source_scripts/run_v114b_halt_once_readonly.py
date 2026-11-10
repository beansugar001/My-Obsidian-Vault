from __future__ import annotations
import hashlib, json, re, subprocess, sys
from datetime import datetime
from pathlib import Path

ROOT=Path(__file__).resolve().parent
OCD_DIR=Path(r"D:\project\tools\tinyriscv-master\tools\openocd")
OCD=OCD_DIR/"openocd.exe"
CFG=ROOT/"03_experiments"/"bbx_v76a_100k.cfg"
TCL=ROOT/"03_experiments"/"v114b_halt_once_readonly.tcl"
STAGE="BBX_V114B_POST_DPC_HALT_READONLY_01_20261110"
MARK=ROOT/"markers"/f"{STAGE}.attempted.json"
RUNS=ROOT/"runs_local_v109"
PINS={"openocd":"EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27","cfg":"CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1","tcl":"71F456D3D5449DD75E44F7D4A5AE121033BD24B8DF8C1F04FF78A71F9746157E"}
def sha(p:Path)->str:return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def host():
 q=r'''$names=@('openocd','pyocd','JLinkGDBServerCL','JLinkGDBServer','JLinkExe','ST-LINK_gdbserver','STLinkServer','STM32CubeProgrammer','probe-rs','riscv-none-embed-gdb','riscv64-unknown-elf-gdb','arm-none-eabi-gdb','gdb');$p=@(Get-CimInstance Win32_Process|Where-Object{$names -contains $_.Name.ToLowerInvariant()}|Select-Object ProcessId,Name,ExecutablePath,CommandLine);$n=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue|Where-Object{$_.LocalPort -in @(3333,4444,6666)}|Select-Object LocalAddress,LocalPort,OwningProcess);ConvertTo-Json -Compress -Depth 4 -InputObject @{processes=$p;listeners=$n}'''
 r=subprocess.run(["powershell","-NoProfile","-Command",q],capture_output=True,text=True,timeout=25)
 if r.returncode:raise RuntimeError(r.stderr)
 d=json.loads(r.stdout);p=d.get("processes") or [];n=d.get("listeners") or []
 return ([p] if isinstance(p,dict) else p),([n] if isinstance(n,dict) else n)
def audit():
 e=[]
 for k,p in (("openocd",OCD),("cfg",CFG),("tcl",TCL)):
  if not p.is_file():e.append(f"MISSING:{p}")
  elif sha(p)!=PINS[k]:e.append(f"HASH_MISMATCH:{k}:{sha(p)}")
 if TCL.is_file():
  t=TCL.read_text(encoding="utf-8")
  if re.search(r"(?im)^\s*(?:reset|resume|flash|erase|load_image|mww|mwh|mwb)\b",t):e.append("FORBIDDEN_COMMAND")
  if re.search(r"0x4[0-9a-f]{7}|0x200[0-9a-f]{4,7}",t,re.I):e.append("MMIO_OR_MEMORY_ADDRESS_PRESENT")
  if not all(x in t for x in ("halt 2000","riscv dmi_read 0x11","V114B_COMPLETE")):e.append("READONLY_GATE_MISSING")
 if MARK.exists():e.append(f"MARKER_EXISTS:{MARK}")
 return e
def main():
 e=audit()
 if e:print("BLOCKED_STATIC_AUDIT\n"+"\n".join(e));return 2
 try:p,n=host()
 except Exception as x:print(f"BLOCKED_HOST_CHECK:{x}");return 3
 if p or n:print("BLOCKED_DEBUG_CONFLICT",json.dumps({"processes":p,"listeners":n},indent=2));return 4
 now=datetime.now().astimezone();run=RUNS/f"{STAGE}_{now.strftime('%Y%m%d_%H%M%S_%f')}";run.mkdir(parents=True,exist_ok=False);MARK.parent.mkdir(parents=True,exist_ok=True)
 try:
  with MARK.open("x",encoding="utf-8") as f:json.dump({"stage":STAGE,"created_local":now.isoformat(),"target_mmio_writes":0,"target_memory_writes":0,"halt_budget":1,"reset_resume_retry":False},f,indent=2);f.write("\n")
 except FileExistsError:print("BLOCKED_MARKER_RACE");return 5
 argv=[str(OCD),"-f",str(CFG).replace("\\","/"),"-c","set ::v114b_authorized 1","-c",f"source {str(TCL).replace(chr(92),'/')}" ]
 meta={"stage":STAGE,"argv":argv,"cwd":str(OCD_DIR),"sha256":{"openocd":sha(OCD),"cfg":sha(CFG),"tcl":sha(TCL),"python":sha(Path(__file__))},"host_processes":p,"host_listeners":n,"started_local":now.isoformat(),"retry":"none"}
 (run/"command.json").write_text(json.dumps(meta,indent=2)+"\n",encoding="utf-8")
 try:r=subprocess.run(argv,cwd=OCD_DIR,capture_output=True,timeout=120);rc,out,err=r.returncode,r.stdout,r.stderr
 except subprocess.TimeoutExpired as x:rc=None;out=x.stdout or b"";err=x.stderr or b"";(run/"timeout.txt").write_text("Timeout; no retry or further action.\n",encoding="utf-8")
 (run/"openocd.stdout.log").write_bytes(out);(run/"openocd.stderr.log").write_bytes(err);raw=out+(b"\n--- STDERR ---\n" if err else b"")+err;(run/"openocd.combined.log").write_bytes(raw);s=raw.decode("utf-8",errors="replace")
 m=re.findall(r"(?m)^V114B_RESULT=(\S+) HALT_COUNT=(\d+)\s*$",s)
 result={"stage":STAGE,"return_code":rc,"complete_marker":"V114B_COMPLETE" in s,"status":m[-1][0] if m else "INCOMPLETE_OR_UNKNOWN","halt_count":int(m[-1][1]) if m else None,"target_mmio_writes":0,"target_memory_writes":0,"log_sha256":{"stdout":sha(run/"openocd.stdout.log"),"stderr":sha(run/"openocd.stderr.log"),"combined":sha(run/"openocd.combined.log")},"finished_local":datetime.now().astimezone().isoformat()}
 (run/"result.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8");print(json.dumps(result,indent=2));print(f"RUN_DIR={run}");return 0 if rc==0 and result["complete_marker"] else 1
if __name__=="__main__":
 if "--execute" not in sys.argv:
  x=audit();print("OFFLINE_AUDIT_PASS; no hardware command sent" if not x else "OFFLINE_AUDIT_BLOCKED\n"+"\n".join(x));sys.exit(0 if not x else 2)
 sys.exit(main())

