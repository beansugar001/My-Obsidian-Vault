import argparse
from datetime import datetime
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PREVIOUS = HERE.parent / "寄存器指令对照"
sys.path.insert(0, str(PREVIOUS))
from run_real_instruction import CFG, OCD, PINNED, V160_TCL, flash_tcl, program, save, sha

BEFORE = HERE.parent / "GPIO独立观测/program_20261117_153513_199667/independent_readback/readback.bin"
IMAGE = HERE / "firmware.bin"
MARKER = HERE / "SEHTAG_GPIO_CALIBRATION_FLASH_20261117_01.attempted.json"
HASHES = {
    **{p: PINNED[p] for p in (OCD, CFG, V160_TCL)},
    BEFORE: "1CF87E6B000EFC9E92F2635FA031FA302645A5F771F21108A583A98A5695ED63",
    IMAGE: "79B6580535DC975F42C9E7F0B2FB42722C2FE23F6BD174EAA1540BA4976CE459",
}



def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=("audit", "program"))
    phase = parser.parse_args().phase
    for path, digest in HASHES.items():
        if sha(path) != digest:
            raise RuntimeError(f"SHA256 mismatch: {path}")
    before = BEFORE.read_bytes()
    image = IMAGE.read_bytes()
    if len(before) != 0x10000 or before[0x200:] != b"\xff" * 0xfe00 or len(image) != 136:
        raise RuntimeError("Unexpected startup image layout")
    source = flash_tcl(len(image))
    if phase == "audit":
        print("AUDIT_PASS 136 bytes, one startup page, pinned input hashes")
        return
    run = HERE / datetime.now().strftime(phase + "_%Y%m%d_%H%M%S_%f")
    run.mkdir()
    print(f"RUN_DIR={run}", flush=True)
    try:
        tcl = run / "flash_gpio_calibration.tcl"
        tcl.write_text(source, encoding="utf-8")
        program(run, before, image, tcl, MARKER)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        save(run / "stop.json", {"error": str(error)})
        raise


if __name__ == "__main__":
    main()
