import argparse
from datetime import datetime
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PREVIOUS = HERE.parent / "寄存器指令对照"
sys.path.insert(0, str(PREVIOUS))
from run_real_instruction import CFG, OCD, PINNED, V160_TCL, flash_tcl, program, save, sha

BEFORE = HERE.parent / "双地址计数对照/program_20261117_124518_855667/independent_readback/readback.bin"
IMAGE = HERE / "firmware.bin"
MARKER = HERE / "SEHTAG_GPIO_MARKER_FLASH_20261117_01.attempted.json"
HASHES = {
    **{p: PINNED[p] for p in (OCD, CFG, V160_TCL)},
    BEFORE: "AE1EFB90046506E8009A013F12C59DD205D7C0AAB7A2CF3A80569EC15D490D97",
    IMAGE: "AA12A9CCA3A43A1B5B55556705E04D285305812D4635A8E5CBE37600B1D1E88E",
}
EXPECTED = {
    "magic": 0x52544000,
    "direct_count": 8,
    "direct_last_value": 0x53454000,
    "direct_exit_reason": 0x4D415000,
    "second_count": 8,
    "second_last_value": 0x53454000,
    "second_exit_reason": 0x4D415000,
    "direct_before_return": 0x52545000,
    "direct_after_return": 0x52546000,
    "second_before_return": 0x52545000,
    "second_after_return": 0x52546000,
    "done": 0x52547000,
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
    if len(before) != 0x10000 or before[0x200:] != b"\xff" * 0xfe00 or len(image) != 496:
        raise RuntimeError("Unexpected startup image layout")
    changes = [i for i, (old, new) in enumerate(zip(before[:372], image)) if old != new]
    permitted = set(range(0x00, 0x04)) | set(range(0x84, 0x88)) | set(range(0x138, 0x13C))
    if not changes or not set(changes) <= permitted:
        raise RuntimeError(f"Unexpected changes in the base image: {changes}")
    source = flash_tcl(len(image))
    if phase == "audit":
        print("AUDIT_PASS 496 bytes, one startup page, pinned input hashes")
        return
    run = HERE / datetime.now().strftime(phase + "_%Y%m%d_%H%M%S_%f")
    run.mkdir()
    print(f"RUN_DIR={run}", flush=True)
    try:
        if phase == "program":
            tcl = run / "flash_gpio_marker.tcl"
            tcl.write_text(source, encoding="utf-8")
            program(run, before, image, tcl, MARKER)
        else:
            sys.path.insert(0, str(HERE.parent / "双地址计数对照"))
            import observe_mirror as observer
            observer.observe_mirror(run, IMAGE, MARKER, EXPECTED)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        save(run / "stop.json", {"error": str(error)})
        raise


if __name__ == "__main__":
    main()
