import argparse
from datetime import datetime
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
PREVIOUS = HERE.parent / "寄存器指令对照"
sys.path.insert(0, str(PREVIOUS))
from run_real_instruction import CFG, OCD, PINNED, V160_TCL, flash_tcl, program, save, sha

BEFORE = HERE.parent / "GPIO静态校准/program_20261117_155339_084090/independent_readback/readback.bin"
IMAGE = HERE / "firmware.bin"
MARKER = HERE / "SEHTAG_GPIO_ACTIVE_LOW_FLASH_20261117_01.attempted.json"
HASHES = {
    **{p: PINNED[p] for p in (OCD, CFG, V160_TCL)},
    BEFORE: "912DDDA6816F0D705BFDEEFD3BD9812EDE6E5806D473BCD80051E61731054676",
    IMAGE: "A678367796DFC2DD3336158FCC9E97029FC84634C1C8739315C05B44F2F9DD79",
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
    if len(before) != 0x10000 or before[0x200:] != b"\xff" * 0xfe00 or len(image) != 496:
        raise RuntimeError("Unexpected startup image layout")
    source = flash_tcl(len(image))
    if phase == "audit":
        print("AUDIT_PASS 496 bytes, one startup page, pinned input hashes")
        return
    run = HERE / datetime.now().strftime(phase + "_%Y%m%d_%H%M%S_%f")
    run.mkdir()
    print(f"RUN_DIR={run}", flush=True)
    try:
        tcl = run / "flash_gpio_active_low.tcl"
        tcl.write_text(source, encoding="utf-8")
        program(run, before, image, tcl, MARKER)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        save(run / "stop.json", {"error": str(error)})
        raise


if __name__ == "__main__":
    main()
