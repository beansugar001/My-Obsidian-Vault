import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


ROOT = Path(__file__).resolve().parent
OCD_ROOT = Path(r"D:\project\tools\xpack-openocd-0.12.0-7")
OCD = OCD_ROOT / "bin" / "openocd.exe"
SCRIPTS = OCD_ROOT / "openocd" / "scripts"
IMAGE_SHA256 = "2A3F6DE80E8E7BA17405B80070538026745A95804E2C5E01965746DD743D0E9F"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=("load", "arm", "read"))
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    image = ROOT / "capture.bin"
    if image.stat().st_size != 416 or digest(image) != IMAGE_SHA256:
        raise RuntimeError("Capture image audit failed")
    if not args.execute:
        print("V143_SRAM_IMAGE_AUDIT_PASS")
        return 0
    check = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "@(Get-Process -Name openocd -ErrorAction SilentlyContinue).Count"],
        capture_output=True, check=True, text=True, timeout=10,
    )
    if check.stdout.strip() != "0":
        raise RuntimeError("Another OpenOCD instance is running")
    now = datetime.now(timezone(timedelta(hours=8)))
    run = ROOT / "runs" / f"{args.phase}_{now.strftime('%Y%m%d_%H%M%S_%f')}"
    run.mkdir(parents=True)
    for name in ("capture.bin", "stm32_capture.tcl"):
        shutil.copyfile(ROOT / name, run / name)
    argv = [
        str(OCD), "-s", SCRIPTS.as_posix(),
        "-c", "gdb port disabled", "-c", "telnet port disabled", "-c", "tcl port disabled",
        "-f", "interface/stlink.cfg", "-c", "transport select swd",
        "-f", "target/stm32f1x.cfg", "-c", "stm32f1x.cpu configure -event examine-end {}",
        "-c", "stm32f1x.cpu configure -work-area-size 0",
        "-c", f"set v143_phase {args.phase}", "-f", "stm32_capture.tcl",
    ]
    meta = {
        "argv": argv, "cwd": str(run), "started": now.isoformat(),
        "sha256": {name: digest(run / name) for name in ("capture.bin", "stm32_capture.tcl")},
    }
    (run / "command.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"RUN_DIR={run}", flush=True)
    log = run / "openocd.log"
    with log.open("xb") as handle:
        result = subprocess.run(argv, cwd=run, stdout=handle, stderr=subprocess.STDOUT, timeout=35)
    text = log.read_text(encoding="utf-8", errors="replace")
    print(text)
    return 0 if result.returncode == 0 and f"V143_COMPLETE phase={args.phase} rc=0" in text else 1


if __name__ == "__main__":
    raise SystemExit(main())
