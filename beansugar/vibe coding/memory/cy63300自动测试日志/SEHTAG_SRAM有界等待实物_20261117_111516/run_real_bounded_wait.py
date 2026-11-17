import argparse
from datetime import datetime
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PREVIOUS = HERE.parent / "寄存器指令对照"
sys.path.insert(0, str(PREVIOUS))
from run_real_instruction import CFG, OCD, PINNED, V160_TCL, flash_tcl, observe, program, save, sha

BEFORE = HERE.parent / "SRAM加载分支对照/program_20261117_110413_349813/independent_readback/readback.bin"
IMAGE = HERE / "firmware.bin"
MARKER = HERE / "SEHTAG_BOUNDED_WAIT_FLASH_20261117_01.attempted.json"
HASHES = {
    **{p: PINNED[p] for p in (OCD, CFG, V160_TCL)},
    BEFORE: "3D795D003895BE849C3B11114E3E15D86C30683C8E61E88ED09A0EF05DFD053D",
    IMAGE: "1D50070764CF7244AA25FD2B8B4447B9F48A583B9D05A78F85D872A605C5E164",
}
EXPECTED = {
    "magic": 0x4C575000,
    "fixed_count": 32,
    "fixed_last_value": 0x13579000,
    "fixed_exit_reason": 0x4C494000,
    "changed_count": 8,
    "changed_last_value": 0x53454000,
    "changed_exit_reason": 0x4D415000,
    "compare_value": 0x53454000,
    "initial_nonmatch": 0x13579000,
    "limit": 32,
    "change_after": 7,
    "done": 0x4C576000,
    "scratch": 0x53454000,
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=("audit", "program", "observe"))
    phase = parser.parse_args().phase
    for path, digest in HASHES.items():
        if sha(path) != digest:
            raise RuntimeError(f"SHA256 mismatch: {path}")
    before = BEFORE.read_bytes()
    image = IMAGE.read_bytes()
    if len(before) != 0x10000 or before[0x200:] != b"\xff" * 0xfe00 or len(image) != 312:
        raise RuntimeError("Unexpected startup image layout")
    source = flash_tcl(len(image))
    if phase == "audit":
        print("AUDIT_PASS 312 bytes, one startup page, pinned input hashes")
        return
    run = HERE / datetime.now().strftime(phase + "_%Y%m%d_%H%M%S_%f")
    run.mkdir()
    print(f"RUN_DIR={run}", flush=True)
    try:
        if phase == "program":
            tcl = run / "flash_bounded_wait.tcl"
            tcl.write_text(source, encoding="utf-8")
            program(run, before, image, tcl, MARKER)
        else:
            observe(run, IMAGE, MARKER, EXPECTED)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        save(run / "stop.json", {"error": str(error)})
        raise


if __name__ == "__main__":
    main()
