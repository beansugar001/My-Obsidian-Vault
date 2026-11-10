import csv, hashlib, json, os, pathlib, socket, subprocess, sys
from datetime import datetime

ROOT = pathlib.Path(r"C:\Users\24796\Documents\组\CY63300_I2C_BLACKBOX")
BASE = ROOT / "SRAM_CPU_EXEC_PLAN_20261110" / "V119_SRAM_CANARY"
MARKERS = ROOT / "markers"
RUNS = ROOT / "runs_local_v119"
OCD_DIR = pathlib.Path(r"D:\project\tools\tinyriscv-master\tools\openocd")
OCD = OCD_DIR / "openocd.exe"
CFG = ROOT / "V116_CPU_STORE" / "v116b_flash_cpu_probe.cfg"
TCL = BASE / "v119_sram_canary_once.tcl"
IMAGE = BASE / "sram_canary.bin"
STAGE = "BBX_V119B_SRAM_CANARY_20261110_01"
EXPECTED_IMAGE_SHA = "E53B8FEACE6CBCB573A4DE242F870567ACEEFBED3A202C7A96671DF5282FA971"


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest().upper()


def stop(msg):
    print("BLOCKED:" + msg)
    raise SystemExit(2)

if len(sys.argv) != 2 or sys.argv[1] != "--execute":
    print("Usage: python run_v119_sram_canary_once.py --execute")
    raise SystemExit(2)

for p in (OCD, CFG, TCL, IMAGE):
    if not p.is_file():
        stop("INPUT_MISSING:" + str(p))
if IMAGE.stat().st_size != 76 or sha(IMAGE) != EXPECTED_IMAGE_SHA:
    stop("CANARY_IDENTITY_MISMATCH")
if sha(OCD) != "EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27":
    stop("OPENOCD_HASH_MISMATCH")

# Mutual exclusion: Altera JTAGServer on TCP/1309 is not a CMSIS-DAP client;
# all OpenOCD/J-Link/GDB/pyOCD clients and standard OpenOCD listeners block.
try:
    powershell = os.environ.get("WINDIR", r"C:\Windows") + r"\System32\WindowsPowerShell\v1.0\powershell.exe"
    query = subprocess.run([powershell, "-NoProfile", "-Command", "(Get-Process | Select-Object -ExpandProperty ProcessName) -join '`n'"], capture_output=True, text=True, check=True)
    names = {line.strip().lower() + ".exe" for line in query.stdout.splitlines() if line.strip()}
except Exception as e:
    stop("PROCESS_SNAPSHOT_UNAVAILABLE:" + type(e).__name__)
conflicts = sorted(n for n in names if n in {"openocd.exe", "jlink.exe", "jlinkgdbservercl.exe", "jlinkgdbserver.exe", "riscv-none-embed-gdb.exe", "riscv64-unknown-elf-gdb.exe", "gdb.exe", "pyocd.exe"})
if conflicts:
    stop("DEBUG_CLIENT_CONFLICT:" + ",".join(conflicts))
for port in (3333, 4444, 6666):
    s = socket.socket()
    try:
        s.bind(("127.0.0.1", port))
    except OSError:
        stop("OPENOCD_PORT_CONFLICT:" + str(port))
    finally:
        s.close()

MARKERS.mkdir(parents=True, exist_ok=True)
RUNS.mkdir(parents=True, exist_ok=True)
marker = MARKERS / (STAGE + ".attempted.json")
try:
    with marker.open("x", encoding="utf-8") as f:
        json.dump({"stage": STAGE, "created_local": datetime.now().astimezone().isoformat(), "image_sha256": EXPECTED_IMAGE_SHA, "attempted": True, "note": "Exclusive marker; never reuse or delete."}, f, indent=2)
        f.write("\n")
except FileExistsError:
    stop("STAGE_MARKER_ALREADY_EXISTS")

run = RUNS / (STAGE + "_" + datetime.now().strftime("%Y%m%d_%H%M%S_%f"))
run.mkdir()
preimage = run / "sram_preimage_0x20008000_76.bin"
args = [str(OCD), "-f", str(CFG).replace("\\", "/"), "-c", "set ::v119_authorized 1", "-c", "source " + str(TCL).replace("\\", "/")]
env = os.environ.copy()
env["V119_IMAGE"] = str(IMAGE).replace("\\", "/")
env["V119_PREIMAGE"] = str(preimage).replace("\\", "/")
meta = {"stage": STAGE, "argv": args, "cwd": str(OCD_DIR), "image_bytes": IMAGE.stat().st_size,
        "image_sha256": sha(IMAGE), "tcl_sha256": sha(TCL), "config_sha256": sha(CFG),
        "openocd_sha256": sha(OCD), "started_local": datetime.now().astimezone().isoformat(),
        "process_snapshot": sorted(names), "known_altera_jtagserver_ignored": True,
        "target_writes_allowed": "SRAM 0x20008000..0x2000804B only, then restore saved bytes",
        "prohibited": ["target MMIO", "Flash/NVR", "reset", "power-cycle", "retry"]}
(run / "command.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")

print("EXECUTING_ONCE", STAGE)
print("RUN_DIR", run)
try:
    cp = subprocess.run(args, cwd=str(OCD_DIR), env=env, capture_output=True, text=True, timeout=90)
    out, err, rc = cp.stdout, cp.stderr, cp.returncode
    timed_out = False
except subprocess.TimeoutExpired as e:
    out = e.stdout.decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
    err = e.stderr.decode(errors="replace") if isinstance(e.stderr, bytes) else (e.stderr or "")
    rc = None
    timed_out = True
(run / "openocd.stdout.log").write_text(out, encoding="utf-8", errors="replace")
(run / "openocd.stderr.log").write_text(err, encoding="utf-8", errors="replace")
combined = "--- STDOUT ---\n" + out + "\n--- STDERR ---\n" + err
(run / "openocd.combined.log").write_text(combined, encoding="utf-8", errors="replace")
combined_u = combined.upper()
status = None
for line in combined.splitlines():
    if line.startswith("V119_RESULT="):
        status = line.split("=", 1)[1].split()[0]
if timed_out:
    status = "OPENOCD_TIMEOUT_UNKNOWN"
result = {"stage": STAGE, "run_dir": str(run), "openocd_exit_code": rc,
          "timed_out": timed_out, "status": status or "INCOMPLETE_OR_UNKNOWN",
          "resume_requested_at_most_once": "V119_RESUME_REQUESTS=1" in combined,
          "pc_mismatch_seen": "WRITTEN PC" in combined_u and "DOES NOT MATCH" in combined_u,
          "canary_verify_pass": "V119_CANARY_VERIFY_PASS" in combined,
          "unique_mailbox_match": "V119_UNIQUE_MAILBOX_MATCH=1" in combined,
          "preimage_saved": "V119_SRAM_PREIMAGE_SAVED" in combined,
          "preimage_restored": "V119_SRAM_PREIMAGE_RESTORE_PASS" in combined,
          "target_mmio_writes": 0, "flash_nvr_writes": 0,
          "nvr_touched": False, "reset_resume_retries": 0,
          "logs_sha256": {n: sha(run / n) for n in ("openocd.stdout.log", "openocd.stderr.log", "openocd.combined.log")}}
(run / "result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
print("STATUS", result["status"])
print("EXIT", rc, "PC_MISMATCH", result["pc_mismatch_seen"], "MAILBOX", result["unique_mailbox_match"], "RESTORED", result["preimage_restored"])
print("RESULT", run / "result.json")
raise SystemExit(0 if result["status"] == "SRAM_CANARY_PASS" else 1)



