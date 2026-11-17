from __future__ import annotations

import argparse
from datetime import datetime
from hashlib import sha256
import json
import os
from pathlib import Path
import re
import struct
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OCD = Path(r"D:\project\tools\tinyriscv-master\tools\openocd\openocd.exe")
BLACKBOX = ROOT / "CY63300_I2C_BLACKBOX"
CFG = BLACKBOX / "03_experiments/bbx_v76a_100k.cfg"
V160_TCL = BLACKBOX / "V160_CPU_OLED_REFRESH/flash_v160_address_park.tcl"
BACKUP = HERE.parent / "sector0_backup_20261116_212350_312731/sector0.bin"
IMAGE = HERE / "firmware.bin"
ATTEMPT = HERE / "SEHTAG_BASELINE_FLASH_20261117_01.attempted.json"
SECTOR = 0x10000
PREFIX = 0xC00
PAGE = 0x200
EXPECTED = {
    OCD: "EECE42DE2378E4A7D2D0D71D1178D8B35E4C67839FE2C4D5EA964C2561127E27",
    CFG: "CB6064F0866A495C067C634FAB91C9A2084AE1805E171C6BCA5758F3A241A4A1",
    V160_TCL: "55B0279B35911DA1082885E615F007898EC764EE5D2503F1D5930C93D3BEA560",
    BACKUP: "0808DA861C1BBD7B03BB88A3ECB625798B0A0797F114788529498EEC5428CA9C",
    IMAGE: "EFD4837FE3CE916690714E976254B740F37B2460A2F1531F4460ABCF9E5F4DCC",
}


def sha(path):
    return sha256(path.read_bytes()).hexdigest().upper()


def save(path, data):
    with path.open("x", encoding="utf-8") as output:
        json.dump(data, output, ensure_ascii=False, indent=2)
        output.write("\n")


def dirty_pages(data):
    return [addr for addr in range(0, len(data), PAGE) if data[addr:addr + PAGE] != b"\xff" * PAGE]


def audit():
    for path, digest in EXPECTED.items():
        if sha(path) != digest:
            raise RuntimeError(f"SHA256 mismatch: {path}")
    backup = BACKUP.read_bytes()
    image = IMAGE.read_bytes()
    if len(image) != 136 or len(backup) != SECTOR or dirty_pages(backup) != list(range(0, PREFIX, PAGE)):
        raise RuntimeError("Unexpected image size or nonblank pages")

    source = V160_TCL.read_text(encoding="utf-8")
    for original, replacement in [
        ("$trigger != 0x800}", "$trigger != 0x800 && $trigger != 0xA00}"),
        ("0x00000A00", "0x00000C00"),
        ("bytes=2700", "bytes=136"),
        ("0x00000A8C", "0x00000088"),
    ]:
        if source.count(original) != 1:
            raise RuntimeError(f"Unexpected reference Tcl source near {original}")
        source = source.replace(original, replacement)
    return backup, image, source


def run_phase(run, tcl, image, name, phase, length, *, trigger=0, sentinel=None):
    folder = run / name
    folder.mkdir()
    dump = folder / "readback.bin"
    log = folder / "openocd.log"
    procs = subprocess.run(
        ["powershell", "-NoProfile", "-Command", "(Get-Process -ErrorAction Stop).ProcessName"],
        capture_output=True, check=True, timeout=20,
    ).stdout
    if re.search(rb"(openocd|pyocd|probe-rs|daplink|cmsis-dap|[a-z0-9-]+-gdb)", procs, re.I):
        raise RuntimeError("Active debug process")
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + tcl.as_posix() + "}"]
    opts = {
        "V160B_PHASE": phase,
        "V160B_DUMP": dump.as_posix(),
        "V160B_IMAGE": image.as_posix(),
        "V160B_TRIGGER": hex(trigger),
    }
    if sentinel is not None:
        addr, word = sentinel
        opts.update(V160B_SENTINEL_ADDR=hex(addr), V160B_SENTINEL_WORD=hex(word))
    save(folder / "command.json", {"argv": argv, "cwd": str(OCD.parent), "env": opts, "tcl_sha256": sha(tcl)})
    print(name, flush=True)
    with log.open("xb") as output:
        rc = subprocess.run(argv, cwd=OCD.parent, env={**os.environ, **opts},
                            stdout=output, stderr=subprocess.STDOUT, timeout=240).returncode
    text = log.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    valid = (
        rc == 0 and lines.count(f"V160B_COMPLETE phase={phase} rc=0") == 1
        and not re.search(r"Error:|V160B_ERROR=", text, re.I)
        and dump.is_file() and dump.stat().st_size == length
        and lines.count(f"V160B_ERASE_TRIGGER=0x{trigger:08X}") == (phase == "erase")
        and lines.count("V160B_PROGRAM_BEGIN address=0x0 bytes=136") == (phase == "program")
    )
    save(folder / "result.json", {"pass": valid, "exit_code": rc, "log_sha256": sha(log),
                                  "readback_sha256": sha(dump) if dump.is_file() else None})
    if not valid:
        raise RuntimeError(f"OpenOCD step failed: {log}")
    return dump.read_bytes()


def program(run, backup, image, tcl):
    if ATTEMPT.exists():
        raise RuntimeError(f"Already attempted: {ATTEMPT}")
    candidate = run / "candidate.bin"
    candidate.write_bytes(image)
    before = run_phase(run, tcl, candidate, "pre_erase", "snapshot", SECTOR)
    if before != backup:
        raise RuntimeError("Live Flash differs from V160 backup")
    save(ATTEMPT, {"run": str(run), "image_sha256": sha(candidate), "size": len(image)})
    current = before[:PREFIX]
    for addr in dirty_pages(backup):
        if addr not in dirty_pages(current):
            continue
        word_addr = next(i for i in range(addr, addr + PAGE, 4) if current[i:i+4] != b"\xff" * 4)
        after = run_phase(run, tcl, candidate, f"erase_{addr:04x}", "erase", PREFIX,
                          trigger=addr, sentinel=(word_addr, struct.unpack_from("<I", current, word_addr)[0]))
        if addr in dirty_pages(after) or any(new not in (old, 0xFF) for old, new in zip(current, after)):
            raise RuntimeError(f"Unexpected erase result at {addr:#x}")
        current = after
    if dirty_pages(current):
        raise RuntimeError("Startup prefix remains nonblank")
    programmed = run_phase(run, tcl, candidate, "program", "program", len(image), sentinel=(0, 0xFFFFFFFF))
    if programmed != image:
        raise RuntimeError("Programmed prefix mismatch")
    expected = image + b"\xff" * (SECTOR - len(image))
    actual = run_phase(run, tcl, candidate, "independent_readback", "snapshot", SECTOR)
    if actual != expected:
        raise RuntimeError("Independent sector readback mismatch")
    save(run / "program_result.json", {"status": "PASS_PROGRAMMED_AND_VERIFIED",
                                       "image_bytes": len(image), "sector_sha256": sha256(actual).hexdigest(),
                                       "boot_executed": False})
    print("PASS_PROGRAMMED_AND_VERIFIED", flush=True)


def mailbox(run, tcl):
    raw = run_phase(run, tcl, IMAGE, "mailbox", "mailbox", 68)
    magic, first, second, _, status, scratch = struct.unpack_from("<6I", raw)
    words = (magic, first, second, status, scratch)
    expected = (0x53454231, 0x13579BDF, 0x2468ACE0, 0x5345600D, 0x2468ACE0)
    result = {"status": "PASS_REAL_SRAM" if words == expected else "FAIL_REAL_SRAM",
              **{k: f"0x{v:08X}" for k, v in zip(("magic", "first", "second", "done", "scratch"), words)}}
    save(run / "mailbox_result.json", result)
    print(json.dumps(result), flush=True)
    if words != expected:
        raise RuntimeError("SRAM mailbox did not meet acceptance criteria")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=("audit", "program", "mailbox"))
    args = parser.parse_args()
    backup, image, source = audit()
    if args.phase == "audit":
        print(f"AUDIT_PASS image_bytes={len(image)} erase_pages={list(map(hex, dirty_pages(backup)))}")
        return
    if args.phase == "mailbox":
        program_run = Path(json.loads(ATTEMPT.read_text(encoding="utf-8"))["run"])
        if json.loads((program_run / "program_result.json").read_text(encoding="utf-8"))["status"] != "PASS_PROGRAMMED_AND_VERIFIED":
            raise RuntimeError("No verified programming result")
    run = HERE / datetime.now().strftime(args.phase + "_%Y%m%d_%H%M%S_%f")
    run.mkdir()
    tcl = run / "flash_baseline.tcl"
    tcl.write_text(source, encoding="utf-8")
    print(f"RUN_DIR={run}", flush=True)
    try:
        if args.phase == "program":
            program(run, backup, image, tcl)
        else:
            mailbox(run, tcl)
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        save(run / "stop.json", {"error": str(exc)})
        raise


if __name__ == "__main__":
    main()
