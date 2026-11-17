import argparse
from datetime import datetime
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PREVIOUS = HERE.parent / "寄存器指令对照"
sys.path.insert(0, str(PREVIOUS))
from run_real_instruction import CFG, OCD, PINNED, V160_TCL, flash_tcl, observe, program, save, sha

BEFORE = PREVIOUS / "program_20261117_104119_320676/independent_readback/readback.bin"
IMAGE = HERE / "firmware.bin"
MARKER = HERE / "SEHTAG_LW_BRANCH_FLASH_20261117_01.attempted.json"
HASHES = {
    **{p: PINNED[p] for p in (OCD, CFG, V160_TCL)},
    BEFORE: "1C9E931829EC1F340E5CB78059DA377FF0BDB07146CD1F697D9992FB0467FC72",
    IMAGE: "066E3830DD6E94BFDD9B70C8CE55F50CFEB85A4E65D664064D0F6A25A46CF531",
}
EXPECTED = {
    "magic": 0x4C425000,
    "register_value": 0x13579000,
    "register_path": 0x54414000,
    "short_value": 0x13579000,
    "short_path": 0x54414000,
    "paced_value": 0x13579000,
    "paced_path": 0x54414000,
    "compare_value": 0x53454000,
    "expected_input": 0x13579000,
    "done": 0x4C426000,
    "unused_28": None,
    "unused_2c": None,
    "scratch": 0x13579000,
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
    if len(before) != 0x10000 or before[0x200:] != b"\xff" * 0xfe00 or len(image) != 288:
        raise RuntimeError("Unexpected startup image layout")
    source = flash_tcl(len(image))
    if phase == "audit":
        print("AUDIT_PASS 288 bytes, one startup page, pinned input hashes")
        return
    run = HERE / datetime.now().strftime(phase + "_%Y%m%d_%H%M%S_%f")
    run.mkdir()
    print(f"RUN_DIR={run}", flush=True)
    try:
        if phase == "program":
            tcl = run / "flash_branch.tcl"
            tcl.write_text(source, encoding="utf-8")
            program(run, before, image, tcl, MARKER)
        else:
            observe(run, IMAGE, MARKER, EXPECTED)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        save(run / "stop.json", {"error": str(error)})
        raise


if __name__ == "__main__":
    main()
