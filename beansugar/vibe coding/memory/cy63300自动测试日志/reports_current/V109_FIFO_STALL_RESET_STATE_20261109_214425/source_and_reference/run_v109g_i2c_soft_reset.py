from __future__ import annotations
import hashlib,json,re,subprocess,sys
from datetime import datetime
from pathlib import Path
P=Path(r"C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX");D=Path(r"D:\project\tools\tinyriscv-master\tools\openocd");O=D/"openocd.exe";C=P/"03_experiments"/"bbx_v76a_100k.cfg";T=Path(r"C:\Users\24796\Documents\组\v109g_i2c_soft_reset.tcl");S="BBX_V109G_I2C_SOFT_RESET_01";M=P/"markers"/f"{S}.attempted.json";R=P/"runs_local_v109";PIN={"openocd":"EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27","cfg":"CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1"}
def h(x):return hashlib.sha256(x.read_bytes()).hexdigest().upper()
def snap():
 q=r'''$n=@('openocd','pyocd','JLinkGDBServerCL','JLinkGDBServer','JLinkExe','ST-LINK_gdbserver','STLinkServer','STM32CubeProgrammer','probe-rs','riscv-none-embed-gdb','riscv64-unknown-elf-gdb','arm-none-eabi-gdb','gdb');$p=@(Get-Process -ErrorAction Stop|Where-Object{$n -contains $_.ProcessName}|Select-Object Id,ProcessName);$l=@(netstat -ano -p tcp|Select-String -Pattern "\sLISTENING\s*$"|ForEach-Object{$f=@($_.Line -split "\s+"|Where-Object{$_});if($f.Count-ge 5){$port=[int](($f[1]-split ":")[-1]);if($port-in @(3333,4444,6666)){[pscustomobject]@{Port=$port;PID=[int]$f[4]}}}});ConvertTo-Json -Compress -InputObject @{p=$p;l=$l}'''
 z=subprocess.run(["powershell","-NoProfile","-Command",q],capture_output=True,text=True,timeout=25)
 if z.returncode:raise RuntimeError(z.stderr)
 j=json.loads(z.stdout);return j.get("p") or [],j.get("l") or []
def main():
 for x in (O,C,T):
  if not x.is_file():print("BLOCKED_MISSING_FILE",x);return 2
 if h(O)!=PIN["openocd"] or h(C)!=PIN["cfg"]:print("BLOCKED_PINNED_HASH_MISMATCH");return 2
 s=T.read_text(encoding="utf-8")
 if re.search(r"(?im)^\s*(?:reset|resume|flash|erase|load_image|mww|mwh|mwb)\b",s):print("BLOCKED_FORBIDDEN_COMMAND");return 2
 w=re.findall(r"(?im)\bv109g_wr\s+(0x[0-9a-f]+)\s+(0x[0-9a-f]+)\s+(\w+)",s);ex=[("0x40021810","0x00000020","I2C_SOFT_RESET_ASSERT"),("0x40021810","0x00000000","I2C_SOFT_RESET_RELEASE")]
 if [(a.upper(),v.upper(),n) for a,v,n in w] != [(a.upper(),v.upper(),n) for a,v,n in ex]:print("BLOCKED_WRITE_ALLOWLIST",w);return 2
 try:p,l=snap()
 except Exception as e:print("BLOCKED_HOST_QUERY",e);return 3
 if p or l:print("BLOCKED_DEBUG_CONFLICT",json.dumps({"p":p,"l":l}));return 4
 if M.exists():print("BLOCKED_MARKER_EXISTS",M);return 5
 now=datetime.now().astimezone();run=R/f"{S}_{now.strftime('%Y%m%d_%H%M%S_%f')}";run.mkdir(parents=True,exist_ok=False)
 try:
  with M.open("x",encoding="utf-8") as f:json.dump({"stage":S,"target_write_budget":2,"allowlist":ex,"halt_budget":1,"retry":"none"},f,indent=2);f.write("\n")
 except FileExistsError:print("BLOCKED_MARKER_RACE");return 5
 argv=[str(O),"-f",str(C).replace("\\","/"),"-c",f"source {str(T).replace(chr(92),'/')}" ];(run/"command.json").write_text(json.dumps({"argv":argv,"cwd":str(D),"stage":S,"started":now.isoformat(),"host_processes":p,"listeners":l,"sha256":{str(x):h(x) for x in (O,C,T,Path(__file__))}},indent=2)+"\n",encoding="utf-8")
 try:z=subprocess.run(argv,cwd=D,capture_output=True,timeout=120);rc,out,err=z.returncode,z.stdout,z.stderr
 except subprocess.TimeoutExpired as e:rc=None;out=e.stdout or b"";err=e.stderr or b""
 (run/"openocd.stdout.log").write_bytes(out);(run/"openocd.stderr.log").write_bytes(err);raw=out+(b"\n--- STDERR ---\n" if err else b"")+err;(run/"openocd.combined.log").write_bytes(raw);txt=raw.decode("utf-8",errors="replace");m=re.findall(r"(?m)^V109G_RESULT=(\S+) HALT_COUNT=(\d+) TARGET_MMIO_WRITE_COUNT=(\d+)\s*$",txt);res={"stage":S,"return_code":rc,"complete":"V109G_COMPLETE" in txt,"status":m[-1][0] if m else "INCOMPLETE_OR_UNKNOWN","halt_count":int(m[-1][1]) if m else None,"target_mmio_write_count":int(m[-1][2]) if m else None,"sha256":{n:h(run/n) for n in ("openocd.stdout.log","openocd.stderr.log","openocd.combined.log")}};(run/"result.json").write_text(json.dumps(res,indent=2)+"\n",encoding="utf-8");print(json.dumps(res,indent=2));print("RUN_DIR="+str(run));return 0 if rc==0 and res["complete"] else 1
if __name__=="__main__":sys.exit(main())