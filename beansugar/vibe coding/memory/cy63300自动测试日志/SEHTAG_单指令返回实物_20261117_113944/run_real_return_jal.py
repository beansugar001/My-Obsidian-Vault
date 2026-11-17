import argparse
from datetime import datetime
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PREVIOUS = HERE.parent / "寄存器指令对照"
sys.path.insert(0, str(PREVIOUS))
from run_real_instruction import CFG, OCD, PINNED, V160_TCL, flash_tcl, observe, program, save, sha

BEFORE = HERE.parent / "返回路径对照/program_20261117_113122_312703/independent_readback/readback.bin"
IMAGE = HERE / "firmware.bin"
MARKER = HERE / "SEHTAG_RETURN_JAL_FLASH_20261117_01.attempted.json"
HASHES = {
    **{p: PINNED[p] for p in (OCD, CFG, V160_TCL)},
    BEFORE: "683D057D8AB5A875E1D532DB8C0371D0368182BC7E71925992CB2143AC285485",
    IMAGE: "DFED41D21FAA66EBD2919F45CDB62029A484C525BE8A5A13A65E7D2CBF35F642",
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
    if len(before) != 0x10000 or before[0x200:] != b"\xff" * 0xfe00 or len(image) != 372:
        raise RuntimeError("Unexpected startup image layout")
    if (before[:0x170] != image[:0x170] or before[0x174:len(image)] != image[0x174:] or
            before[0x170:0x174] != bytes.fromhex("67800900") or
            image[0x170:0x174] != bytes.fromhex("6ff0dfef")):
        raise RuntimeError("Image must differ by exactly the direct jump at 0x170")
    source = flash_tcl(len(image))
    if phase == "audit":
        print("AUDIT_PASS 372 bytes, one startup page, pinned input hashes")
        return
    run = HERE / datetime.now().strftime(phase + "_%Y%m%d_%H%M%S_%f")
    run.mkdir()
    print(f"RUN_DIR={run}", flush=True)
    try:
        if phase == "program":
            tcl = run / "flash_return_jal.tcl"
            tcl.write_text(source, encoding="utf-8")
            program(run, before, image, tcl, MARKER)
        else:
            observe(run, IMAGE, MARKER, EXPECTED)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        save(run / "stop.json", {"error": str(error)})
        raise


if __name__ == "__main__":
    main()
