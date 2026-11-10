from __future__ import annotations
import hashlib,json,re,subprocess,sys
from datetime import datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parent;OCD_DIR=Path(r"D:\project\tools\tinyriscv-master\tools\openocd");OCD=OCD_DIR/"openocd.exe";CFG=ROOT/"03_experiments"/"bbx_v76a_100k.cfg";TCL=ROOT/"03_experiments"/"v115f_single_byte_after_enable_addr.tcl";STAGE="BBX_V115F_SINGLE_BYTE_ENABLE_ADDR_ORDER_20261110_01";MARK=ROOT/"markers"/f"{STAGE}.attempted.json";RUNS=ROOT/"runs_local_v109";PINS={"openocd":"EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27","cfg":"CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1"}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def host():
 q=r'''$names=@('openocd','pyocd','JLinkGDBServerCL','JLinkGDBServer','JLinkExe','ST-LINK_gdbserver','STLinkServer','STM32CubeProgrammer','probe-rs','riscv-none-embed-gdb','riscv64-unknown-elf-gdb','arm-none-eabi-gdb','gdb');$p=@(Get-CimInstance Win32_Process|Where-Object{$names -contains $_.Name.ToLowerInvariant()}|Select-Object ProcessId,Name,ExecutablePath,CommandLine);$n=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue|Where-Object{$_.LocalPort -in @(3333,4444,6666)}|Select-Object LocalAddress,LocalPort,OwningProcess);ConvertTo-Json -Compress -Depth 4 -InputObject @{processes=$p;listeners=$n}''';r=subprocess.run(["powershell","-NoProfile","-Command",q],capture_output=True,text=True,timeout=30)
 if r.returncode:raise RuntimeError(r.stderr)
 d=json.loads(r.stdout);p=d.get("processes") or [];n=d.get("listeners") or [];return ([p] if isinstance(p,dict) else p),([n] if isinstance(n,dict) else n)
def audit():
 e=[]
 for k,p in (("openocd",OCD),("cfg",CFG),("tcl",TCL)):
  if not p.is_file():e.append(f"MISSING:{k}:{p}")
  elif k in PINS and sha(p)!=PINS[k]:e.append(f"HASH_MISMATCH:{k}:{sha(p)}")
 if TCL.is_file():
  t=TCL.read_text(encoding="utf-8")
  if t.count("v115f_wr 0x40002808 0x00000000 ONE_CONTROL_BYTE")!=1:e.append("TX_FIFO_WRITE_BUDGET_MISMATCH")
  if t.count("v115f_wr 0x40002828 0x00000002 SINGLE_STOP_AFTER_")!=2:e.append("CONDITIONAL_STOP_BUDGET_MISMATCH")
  if re.search(r"(?im)^\s*(?:mww|mwh|mwb|reset|resume|flash|erase|load_image)\b",t):e.append("FORBIDDEN_COMMAND")
 if MARK.exists():e.append(f"MARKER_EXISTS:{MARK}")
 return e
def main():
 e=audit()
 if e:print("OFFLINE_AUDIT_BLOCKED\n"+"\n".join(e));return 2
 if "--execute" not in sys.argv:print("OFFLINE_AUDIT_PASS; no target accessed");return 0
 try:p,n=host()
 except Exception as x:print(f"HOST_QUERY_BLOCKED:{x}");return 3
 if p or n:print("BLOCKED_DEBUG_CONFLICT\n"+json.dumps({"processes":p,"listeners":n},indent=2));return 4
 now=datetime.now().astimezone();run=RUNS/f"{STAGE}_{now.strftime('%Y%m%d_%H%M%S_%f')}";run.mkdir(parents=True,exist_ok=False);MARK.parent.mkdir(parents=True,exist_ok=True)
 try:
  with MARK.open("x",encoding="utf-8") as f:json.dump({"stage":STAGE,"started_local":now.isoformat(),"tx_fifo_allowlist":[["0x40002808","0x00000000"]],"max_tx_fifo_writes":1,"max_stop_writes":1,"max_halt_requests":1,"reset_resume_flash_retry":"forbidden"},f,indent=2);f.write("\n")
 except FileExistsError:print("BLOCKED_MARKER_RACE");return 5
 argv=[str(OCD),"-f",str(CFG).replace("\\","/"),"-c",f"source {str(TCL).replace(chr(92),'/')}" ];meta={"stage":STAGE,"argv":argv,"cwd":str(OCD_DIR),"started_local":now.isoformat(),"host_processes":p,"listeners":n,"sha256":{"openocd":sha(OCD),"cfg":sha(CFG),"tcl":sha(TCL),"runner":sha(Path(__file__))}};(run/"command.json").write_text(json.dumps(meta,indent=2)+"\n",encoding="utf-8")
 try:r=subprocess.run(argv,cwd=OCD_DIR,capture_output=True,timeout=300);rc,out,err=r.returncode,r.stdout,r.stderr
 except subprocess.TimeoutExpired as x:rc=None;out=x.stdout or b"";err=x.stderr or b"";(run/"timeout.txt").write_text("Timeout; evidence retained; no retry.\n",encoding="utf-8")
 (run/"openocd.stdout.log").write_bytes(out);(run/"openocd.stderr.log").write_bytes(err);raw=out+(b"\n--- STDERR ---\n" if err else b"")+err;(run/"openocd.combined.log").write_bytes(raw);s=raw.decode("utf-8",errors="replace");m=re.findall(r"(?m)^V115F_RESULT=(\S+) HALT_COUNT=(\d+) TARGET_MMIO_WRITE_COUNT=(\d+) STOP_WRITE_COUNT=(\d+)\s*$",s)
 res={"stage":STAGE,"return_code":rc,"completion_marker":"V115F_COMPLETE" in s,"status":m[-1][0] if m else "INCOMPLETE_OR_UNKNOWN","halt_count":int(m[-1][1]) if m else None,"target_mmio_write_count":int(m[-1][2]) if m else None,"stop_write_count":int(m[-1][3]) if m else None,"log_sha256":{n:sha(run/n) for n in ("openocd.stdout.log","openocd.stderr.log","openocd.combined.log")},"finished_local":datetime.now().astimezone().isoformat()};(run/"result.json").write_text(json.dumps(res,indent=2)+"\n",encoding="utf-8");print(json.dumps(res,indent=2));print(f"RUN_DIR={run}");return 0 if rc==0 and res["completion_marker"] else 1
if __name__=="__main__":sys.exit(main())
