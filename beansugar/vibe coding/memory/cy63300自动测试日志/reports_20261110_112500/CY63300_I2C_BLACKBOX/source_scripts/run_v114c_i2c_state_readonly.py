from __future__ import annotations
import hashlib,json,re,subprocess,sys
from datetime import datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parent; EXP=ROOT/"03_experiments"
OCD_DIR=Path(r"D:\project\tools\tinyriscv-master\tools\openocd");OCD=OCD_DIR/"openocd.exe"
CFG=EXP/"bbx_v76a_100k.cfg";TCL=EXP/"v114c_i2c_state_readonly.tcl"
STAGE="BBX_V114C_POST_DPC_I2C_READONLY_01_20261110";MARK=ROOT/"markers"/f"{STAGE}.attempted.json";RUNS=ROOT/"runs_local_v109"
PINS={"openocd":"EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27","cfg":"CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1","tcl":"231D9E4FA4A49E9C5947FAEA2C32AF472C941D88FBF54A8D0328C5ECAE06FB4B"}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def audit():
 e=[]
 for k,p in (("openocd",OCD),("cfg",CFG),("tcl",TCL)):
  if not p.is_file():e.append(f"MISSING:{p}")
  elif sha(p)!=PINS[k]:e.append(f"HASH_MISMATCH:{k}")
 if TCL.is_file():
  t=TCL.read_text(encoding="utf-8")
  if re.search(r"(?im)^\s*(?:reset|resume|flash|erase|load_image|mww|mwh|mwb)\b",t):e.append("FORBIDDEN_COMMAND")
  if not all(x in t for x in ("V114C_AUTH_REQUIRED","0x4002180C","0x40002858","V114C_COMPLETE")):e.append("READONLY_SEQUENCE_INCOMPLETE")
 if MARK.exists():e.append("MARKER_ALREADY_EXISTS")
 return e
def host():
 q=r'''$names=@('openocd','pyocd','JLinkGDBServerCL','JLinkGDBServer','JLinkExe','ST-LINK_gdbserver','STLinkServer','STM32CubeProgrammer','probe-rs','riscv-none-embed-gdb','riscv64-unknown-elf-gdb','arm-none-eabi-gdb','gdb');$p=@(Get-CimInstance Win32_Process|Where-Object{$names -contains $_.Name.ToLowerInvariant()}|Select-Object ProcessId,Name,ExecutablePath,CommandLine);$n=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue|Where-Object{$_.LocalPort -in @(3333,4444,6666)}|Select-Object LocalAddress,LocalPort,OwningProcess);ConvertTo-Json -Compress -Depth 4 -InputObject @{processes=$p;listeners=$n}'''
 r=subprocess.run(["powershell","-NoProfile","-Command",q],capture_output=True,text=True,timeout=25)
 if r.returncode:raise RuntimeError(r.stderr)
 d=json.loads(r.stdout);p=d.get("processes") or [];n=d.get("listeners") or []
 return ([p] if isinstance(p,dict) else p),([n] if isinstance(n,dict) else n)
def main():
 e=audit()
 if e:print("BLOCKED_STATIC_AUDIT\n"+"\n".join(e));return 2
 try:p,n=host()
 except Exception as x:print(f"BLOCKED_HOST_CHECK:{x}");return 3
 if p or n:print("BLOCKED_DEBUG_CONFLICT",json.dumps({"processes":p,"listeners":n},indent=2));return 4
 now=datetime.now().astimezone();run=RUNS/f"{STAGE}_{now.strftime('%Y%m%d_%H%M%S_%f')}";run.mkdir(parents=True,exist_ok=False);MARK.parent.mkdir(parents=True,exist_ok=True)
 try:
  with MARK.open("x",encoding="utf-8") as f:json.dump({"stage":STAGE,"created_local":now.isoformat(),"target_mmio_writes":0,"target_memory_writes":0,"cpu_must_be_halted":True,"retry":False},f,indent=2);f.write("\n")
 except FileExistsError:print("BLOCKED_MARKER_RACE");return 5
 argv=[str(OCD),"-f",str(CFG).replace("\\","/"),"-c","set ::v114c_authorized 1","-c",f"source {str(TCL).replace(chr(92),'/')}" ]
 (run/"command.json").write_text(json.dumps({"stage":STAGE,"argv":argv,"cwd":str(OCD_DIR),"sha256":{"openocd":sha(OCD),"cfg":sha(CFG),"tcl":sha(TCL),"python":sha(Path(__file__))},"host_processes":p,"host_listeners":n,"started_local":now.isoformat()},indent=2)+"\n",encoding="utf-8")
 try:r=subprocess.run(argv,cwd=OCD_DIR,capture_output=True,timeout=120);rc,out,err=r.returncode,r.stdout,r.stderr
 except subprocess.TimeoutExpired as x:rc=None;out=x.stdout or b"";err=x.stderr or b"";(run/"timeout.txt").write_text("Timeout; no retry or recovery.\n",encoding="utf-8")
 (run/"openocd.stdout.log").write_bytes(out);(run/"openocd.stderr.log").write_bytes(err);raw=out+(b"\n--- STDERR ---\n" if err else b"")+err;(run/"openocd.combined.log").write_bytes(raw);s=raw.decode("utf-8",errors="replace")
 m=re.findall(r"(?m)^V114C_RESULT=(\S+) MMIO_READ_COUNT=(\d+) FINAL_SBCS_RC=(\d+) DETAIL=(.*?)\s*$",s)
 result={"stage":STAGE,"return_code":rc,"complete_marker":"V114C_COMPLETE" in s,"status":m[-1][0] if m else "INCOMPLETE_OR_UNKNOWN","mmio_read_count":int(m[-1][1]) if m else None,"final_sbcs_rc":int(m[-1][2]) if m else None,"target_mmio_writes":0,"target_memory_writes":0,"log_sha256":{"stdout":sha(run/"openocd.stdout.log"),"stderr":sha(run/"openocd.stderr.log"),"combined":sha(run/"openocd.combined.log")},"finished_local":datetime.now().astimezone().isoformat()}
 (run/"result.json").write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8");print(json.dumps(result,indent=2));print(f"RUN_DIR={run}");return 0 if rc==0 and result["complete_marker"] else 1
if __name__=="__main__":
 if "--execute" not in sys.argv:
  e=audit();print("OFFLINE_AUDIT_PASS; no hardware command sent" if not e else "OFFLINE_AUDIT_BLOCKED\n"+"\n".join(e));sys.exit(0 if not e else 2)
 sys.exit(main())

