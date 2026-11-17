import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess


ROOT = Path(__file__).resolve().parent
OCD_ROOT = Path(r"D:\project\tools\xpack-openocd-0.12.0-7")
OCD = OCD_ROOT / "bin" / "openocd.exe"
SCRIPTS = OCD_ROOT / "openocd" / "scripts"
STAGE = "V142_STM32_ACK_SRAM_02"
MARKER = ROOT / f"{STAGE}.attempted.json"
PROGRAM = "stm32_ack_probe_state_fix.tcl"
FLASH_BYTES = 0x10000


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def audit():
    image = (ROOT / "probe.bin").read_bytes()
    elf = (ROOT / "probe.axf").read_bytes()
    if len(image) != 0x340 or struct.unpack_from("<I", elf, 24)[0] != 0x2000325D:
        raise ValueError("SRAM image size or entry mismatch")
    if digest(ROOT / "probe.bin") != "D3832A236D07054CB2951DD29A647A5713E069942C2AD52C1A4A3A64C0E69708":
        raise ValueError("Reviewed SRAM image hash mismatch")
    original = ROOT / "original_project.bin"
    if digest(original) != "13618CEB6DD21E1C1293B8101638D3664704357482407509F6FDB7106E3363B4":
        raise ValueError("Project flash reference hash mismatch")
    script = (ROOT / PROGRAM).read_text(encoding="utf-8")
    if re.search(r"(?m)^\s*(?:flash|program|erase|stm32f1x\s+(?:lock|unlock))\s", script):
        raise ValueError("Nonvolatile command")
    if not OCD.is_file() or not SCRIPTS.is_dir():
        raise ValueError("ST-Link OpenOCD installation missing")
    if MARKER.exists():
        raise ValueError("Stage has already been attempted")


def parse_mailbox(path):
    magic, stage, cfgr, half, *words = struct.unpack("<20I", path.read_bytes())
    if (magic, stage, half) != (0x14203303, 3, 720):
        raise ValueError(f"Probe mailbox incomplete: magic={magic:#x}, stage={stage}")
    samples = []
    for address, index in ((0x3C, 0), (0x3D, 8)):
        addr, idle_before, a0, a1, a2, idle_after, outcome, cycles = words[index:index + 8]
        expected_pins = {1: (0x100,) * 3, 2: (0x300,) * 3}
        if addr != address or idle_before != 0x300 or idle_after != 0x300:
            raise ValueError(f"Invalid address or bus idle for {address:#x}")
        if expected_pins.get(outcome) != (a0, a1, a2) or cycles < 19 * half:
            raise ValueError(f"Invalid ACK sampling or duration for {address:#x}")
        samples.append({
            "address": f"0x{address:02X}", "address_byte": f"0x{address << 1:02X}",
            "ack": outcome == 1, "ack_input_samples": [a0, a1, a2],
            "before": idle_before, "after": idle_after, "elapsed_cycles": cycles,
        })
    return {"rcc_cfgr": f"0x{cfgr:08X}", "half_period_cycles": half, "samples": samples}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    audit()
    if not args.execute:
        print("V142_OFFLINE_AUDIT_PASS")
        return 0
    current = subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "@(Get-Process -Name openocd -ErrorAction SilentlyContinue).Count"],
        capture_output=True, text=True, check=True, timeout=10,
    )
    if current.stdout.strip() != "0":
        raise RuntimeError("Existing OpenOCD process")
    now = datetime.now(timezone(timedelta(hours=8)))
    run = ROOT / "runs" / now.strftime("%Y%m%d_%H%M%S_%f")
    run.mkdir(parents=True)
    for name in (PROGRAM, "original_project.bin", "probe.bin"):
        shutil.copyfile(ROOT / name, run / name)
    argv = [
        str(OCD), "-s", SCRIPTS.as_posix(), "-c", "gdb port disabled",
        "-c", "telnet port disabled", "-c", "tcl port disabled",
        "-f", "interface/stlink.cfg", "-c", "transport select swd",
        "-f", "target/stm32f1x.cfg", "-c", "stm32f1x.cpu configure -event examine-end {}",
        "-c", "stm32f1x.cpu configure -work-area-size 0", "-f", PROGRAM,
    ]
    meta = {"argv": argv, "cwd": str(run), "started": now.isoformat(),
            "sha256": {name: digest(run / name) for name in (PROGRAM, "probe.bin", "original_project.bin")}}
    (run / "command.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")
    with MARKER.open("x", encoding="utf-8") as handle:
        json.dump({"stage": STAGE, "run": str(run), "started": now.isoformat()}, handle, ensure_ascii=False)
    print(f"RUN_DIR={run}", flush=True)
    out = run / "openocd.stdout.log"
    err = run / "openocd.stderr.log"
    rc = None
    problem = None
    with out.open("xb") as stdout, err.open("xb") as stderr:
        try:
            rc = subprocess.run(argv, cwd=run, stdout=stdout, stderr=stderr, timeout=45).returncode
        except (OSError, subprocess.TimeoutExpired) as exc:
            problem = str(exc)
    combined = run / "openocd.combined.log"
    combined.write_bytes(out.read_bytes() + b"\n--- STDERR ---\n" + err.read_bytes())
    text = combined.read_text(encoding="utf-8", errors="replace")
    before = run / "flash_before.bin"
    after = run / "flash_after.bin"
    flash_equal = (
        before.is_file() and after.is_file()
        and before.stat().st_size == after.stat().st_size == FLASH_BYTES
        and digest(before) == digest(after)
    )
    ref = (run / "original_project.bin").read_bytes()
    result = {
        "stage": STAGE, "returncode": rc, "process_error": problem,
        "flash_equal": flash_equal,
        "flash_matches_project": before.is_file() and before.read_bytes().startswith(ref),
        "flash_sha256": digest(before) if before.is_file() else None,
        "restored_running": "V142_FLASH_APP_RUNNING" in text,
        "log_sha256": digest(combined),
    }
    try:
        result["mailbox"] = parse_mailbox(run / "ack_mailbox.bin")
    except (OSError, ValueError, struct.error) as exc:
        result["mailbox_error"] = str(exc)
    result["success"] = (
        rc == 0 and "V142_COMPLETE probe_rc=0 restart_rc=0" in text
        and result["restored_running"] and result["flash_matches_project"]
        and flash_equal and "mailbox" in result
    )
    (run / "result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0 if result["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
