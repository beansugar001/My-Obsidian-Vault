from __future__ import annotations
import hashlib,json,re,subprocess,sys
from datetime import datetime
from pathlib import Path
PROJECT=Path(r"C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX");OCD_DIR=Path(r"D:\project\tools\tinyriscv-master\tools\openocd");OCD=OCD_DIR/"openocd.exe";CFG=PROJECT/"03_experiments"/"bbx_v76a_100k.cfg";TCL=Path(r"C:\Users\24796\Documents\组\v109e_i2c_enable_idle.tcl");STAGE="BBX_V109E_I2C_ENABLE_IDLE_01";MARK=PROJECT/"markers"/f"{STAGE}.attempted.json";RUNS=PROJECT/"runs_local_v109";PINNED={"openocd":"EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27","cfg":"CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1"}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def host_snapshot():
 q=r'''$names=@('openocd','pyocd','JLinkGDBServerCL','JLinkGDBServer','JLinkExe','ST-LINK_gdbserver','STLinkServer','STM32CubeProgrammer','probe-rs','riscv-none-embed-gdb','riscv64-unknown-elf-gdb','arm-none-eabi-gdb','gdb');$p=@(Get-Process -ErrorAction Stop|Where-Object{$names -contains $_.ProcessName}|Select-Object Id,ProcessName);$n=@(netstat -ano -p tcp|Select-String -Pattern "\sLISTENING\s*$"|ForEach-Object{$f=@($_.Line -split "\s+"|Where-Object{$_});if($f.Count -ge 5){$port=[int](($f[1]-split ":")[-1]);if($port -in @(3333,4444,6666)){[pscustomobject]@{LocalAddress=$f[1];LocalPort=$port;OwningProcess=[int]$f[4]}}}});ConvertTo-Json -Compress -Depth 4 -InputObject @{processes=$p;listeners=$n}'''
 p=subprocess.run(["powershell","-NoProfile","-Command",q],capture_output=True,text=True,timeout=25)
 if p.returncode:raise RuntimeError(f"HOST_QUERY_FAILED rc={p.returncode} {p.stderr}")
 d=json.loads(p.stdout);ps=d.get("processes") or [];ls=d.get("listeners") or []
 if isinstance(ps,dict):ps=[ps]
 if isinstance(ls,dict):ls=[ls]
 return ps,ls
def main():
 for f in (OCD,CFG,TCL):
  if not f.is_file():print(f"BLOCKED_MISSING_FILE:{f}");return 2
 if sha(OCD)!=PINNED["openocd"] or sha(CFG)!=PINNED["cfg"]:print("BLOCKED_PINNED_HASH_MISMATCH");return 2
 t=TCL.read_text(encoding="utf-8")
 if re.search(r"(?im)^\s*(?:reset|resume|flash|erase|load_image|mww|mwh|mwb)\b",t):print("BLOCKED_FORBIDDEN_COMMAND");return 2
 w=re.findall(r"(?im)^\s*v109e_wr\s+(0x[0-9a-f]+)\s+(0x[0-9a-f]+)\s+(\S+)",t);expected=[("0x40002800","0x0000000D","I2C_EN_ONLY")]
 if [(a.upper(),v.upper(),n) for a,v,n in w] != [(a.upper(),v.upper(),n) for a,v,n in expected]:print(f"BLOCKED_WRITE_ALLOWLIST:{w}");return 2
 try:ps,ls=host_snapshot()
 except Exception as e:print(f"BLOCKED_HOST_QUERY:{e}");return 3
 if ps or ls:print("BLOCKED_DEBUG_CONFLICT "+json.dumps({"processes":ps,"listeners":ls},indent=2));return 4
 if MARK.exists():print(f"BLOCKED_MARKER_EXISTS:{MARK}");return 5
 now=datetime.now().astimezone();run=RUNS/f"{STAGE}_{now.strftime('%Y%m%d_%H%M%S_%f')}";run.mkdir(parents=True,exist_ok=False);MARK.parent.mkdir(parents=True,exist_ok=True)
 try:
  with MARK.open("x",encoding="utf-8") as f:json.dump({"stage":STAGE,"created_local":now.isoformat(),"target_mmio_write_budget":1,"only_target_write":{"address":"0x40002800","value":"0x0000000D"},"halt_request_budget":1,"retry":"none","FIFO_payload_written":False},f,indent=2);f.write("\n")
 except FileExistsError:print("BLOCKED_MARKER_RACE");return 5
 argv=[str(OCD),"-f",str(CFG).replace("\\","/"),"-c",f"source {str(TCL).replace(chr(92),'/')}" ];meta={"stage":STAGE,"argv":argv,"cwd":str(OCD_DIR),"started_local":now.isoformat(),"timeout_s":120,"retry":"none","host_processes":ps,"host_listeners":ls,"sha256":{str(x):sha(x) for x in (OCD,CFG,TCL,Path(__file__))}};(run/"command.json").write_text(json.dumps(meta,indent=2)+"\n",encoding="utf-8")
 try:p=subprocess.run(argv,cwd=OCD_DIR,capture_output=True,timeout=120);rc,out,err=p.returncode,p.stdout,p.stderr
 except subprocess.TimeoutExpired as e:rc=None;out=e.stdout or b"";err=e.stderr or b"";(run/"timeout.txt").write_text("Timed out; evidence retained; no retry.\n",encoding="utf-8")
 (run/"openocd.stdout.log").write_bytes(out);(run/"openocd.stderr.log").write_bytes(err);raw=out+(b"\n--- STDERR ---\n" if err else b"")+err;(run/"openocd.combined.log").write_bytes(raw);s=raw.decode("utf-8",errors="replace");m=re.findall(r"(?m)^V109E_RESULT=(\S+) HALT_COUNT=(\d+) TARGET_MMIO_WRITE_COUNT=(\d+)\s*$",s);res={"stage":STAGE,"return_code":rc,"complete":"V109E_COMPLETE" in s,"status":m[-1][0] if m else "INCOMPLETE_OR_UNKNOWN","halt_count":int(m[-1][1]) if m else None,"target_mmio_write_count":int(m[-1][2]) if m else None,"host_processes":ps,"host_listeners":ls,"log_sha256":{n:sha(run/n) for n in ("openocd.stdout.log","openocd.stderr.log","openocd.combined.log")},"finished_local":datetime.now().astimezone().isoformat()};(run/"result.json").write_text(json.dumps(res,indent=2)+"\n",encoding="utf-8");print(json.dumps(res,indent=2));print(f"RUN_DIR={run}");return 0 if rc==0 and res["complete"] else 1
if __name__=="__main__":sys.exit(main())