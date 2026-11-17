import argparse
from datetime import datetime
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PREVIOUS = HERE.parent / "寄存器指令对照"
sys.path.insert(0, str(PREVIOUS))
from run_real_instruction import CFG, OCD, PINNED, V160_TCL, flash_tcl, program, save, sha

BEFORE = HERE.parent / "单指令返回对照/program_20261117_113944_242043/independent_readback/readback.bin"
IMAGE = HERE / "firmware.bin"
MARKER = HERE / "SEHTAG_COUNT_MIRROR_FLASH_20261117_01.attempted.json"
HASHES = {
    **{p: PINNED[p] for p in (OCD, CFG, V160_TCL)},
    BEFORE: "F83AADCF46FA79E0C6D3CA6ED3659EDF7B2F9AD800ABC7583B5A2F7906227BF3",
    IMAGE: "7E40DA0A3E73E5505784D24F94CAB52A7E46F028CA7646F137371D2346D70441",
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
    if (before[:0x124] != image[:0x124] or before[0x128:len(image)] != image[0x128:] or
            before[0x124:0x128] != bytes.fromhex("13000000") or
            image[0x124:0x128] != bytes.fromhex("23205911")):
        raise RuntimeError("Image must differ by exactly the mirror store at 0x124")
    source = flash_tcl(len(image))
    if phase == "audit":
        print("AUDIT_PASS 372 bytes, one startup page, pinned input hashes")
        return
    run = HERE / datetime.now().strftime(phase + "_%Y%m%d_%H%M%S_%f")
    run.mkdir()
    print(f"RUN_DIR={run}", flush=True)
    try:
        if phase == "program":
            tcl = run / "flash_count_mirror.tcl"
            tcl.write_text(source, encoding="utf-8")
            program(run, before, image, tcl, MARKER)
        else:
            from observe_mirror import observe_mirror
            observe_mirror(run, IMAGE, MARKER, EXPECTED)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        save(run / "stop.json", {"error": str(error)})
        raise


if __name__ == "__main__":
    main()
