import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "单次触发探针"))
from run_real_csr import CFG, OCD, PINNED, V160_TCL, flash_tcl, program, save, sha

BEFORE = HERE.parent / "SRAM等待对照/program_20261117_101405_628826/independent_readback/readback.bin"
IMAGE = HERE / "firmware.bin"
FLASH_MARK = HERE / "SEHTAG_INSTRUCTION_FLASH_20261117_01.attempted.json"
INPUTS = {
    **{path: PINNED[path] for path in (OCD, CFG, V160_TCL)},
    BEFORE: "B7B81AB8C5D55E18ABDB8139F5BF8800E55DC61DBF36FFFC6E7D038620496DAD",
    IMAGE: "BDBBC404E911A7BF7FE44467D734AE79D76A068E0CA088081141F795374DBF2E",
}
EXPECTED = {
    "fixed_base": 0x57416000,
    "distinct_rd_add13": 0x5741600D,
    "fixed_base_copy": 0x57416000,
    "unchanged_source": 0x57416000,
    "spaced_inplace_add29": 0x5741601D,
    "beq_not_taken": 0x11111000,
    "bne_taken": 0x22222000,
    "matched_inplace_add13": 0x5741600D,
    "fixed_pattern": 0x2D5A7000,
    "done": 0x53457000,
}


def audit():
    for path, digest in INPUTS.items():
        if sha(path) != digest:
            raise RuntimeError(f"SHA256 mismatch: {path}")
    before, image = BEFORE.read_bytes(), IMAGE.read_bytes()
    if len(before) != 0x10000 or before[0x200:] != b"\xff" * 0xfe00 or len(image) != 196:
        raise RuntimeError("Unexpected startup image layout")
    return before, image


def observe(run):
    flash_run = Path(json.loads(FLASH_MARK.read_text(encoding="utf-8"))["run"])
    if not json.loads((flash_run / "program_result.json").read_text(encoding="utf-8"))["verified"]:
        raise RuntimeError("Missing successful Flash verification")
    clients = subprocess.run(
        ["powershell", "-NoProfile", "-Command", "(Get-Process -ErrorAction Stop).ProcessName"],
        capture_output=True, check=True, timeout=20,
    ).stdout
    if re.search(rb"(openocd|pyocd|probe-rs|daplink|cmsis-dap|[a-z0-9-]+-gdb)", clients, re.I):
        raise RuntimeError("Active debug process")
    startup = (HERE.parent / "v160_cold_boot.tcl").read_text(encoding="utf-8").split("dump_image", 1)[0]
    tcl = run / "sample_readonly.tcl"
    tcl.write_text(startup + r"""
for {set i 0} {$i < 8} {incr i} {
    if {[riscv.cpu curstate] ne "running"} {error HART_NOT_RUNNING}
    dump_image [format "%s/mailbox_%02d.bin" $::env(INSTRUCTION_LOG) $i] 0x2000F000 0x28
    for {set addr 0x2000F000} {$addr < 0x2000F028} {incr addr 4} {
        set output [capture [format "mdw 0x%08X" $addr]]
        set pattern [format {^\s*0x%08x:\s+([0-9a-f]{8})\s*$} $addr]
        if {![regexp -nocase $pattern $output -> value]} {error "BAD_READ $output"}
        echo [format "INSTRUCTION_WORD %02d %08X %s" $i $addr $value]
    }
    sleep 120
}
dump_image [format "%s/startup.bin" $::env(INSTRUCTION_LOG)] 0x0 0xC4
echo INSTRUCTION_SAMPLES_COMPLETE
shutdown
""", encoding="utf-8")
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + tcl.as_posix() + "}"]
    env = {"INSTRUCTION_LOG": run.as_posix()}
    save(run / "command.json", {"argv": argv, "cwd": str(OCD.parent), "env": env,
                                "tcl_sha256": sha(tcl)})
    log = run / "openocd.log"
    with log.open("xb") as log_file:
        rc = subprocess.run(argv, cwd=OCD.parent, env={**os.environ, **env}, stdout=log_file,
                            stderr=subprocess.STDOUT, timeout=55).returncode
    raw = log.read_text(encoding="utf-8", errors="replace")
    if rc != 0 or "Error:" in raw or raw.splitlines().count("INSTRUCTION_SAMPLES_COMPLETE") != 1:
        print(raw)
        raise RuntimeError("Read-only sampling incomplete")
    binaries = [run / f"mailbox_{i:02d}.bin" for i in range(8)]
    dumps = [struct.unpack("<10I", path.read_bytes()) for path in binaries]
    words = {int(i): {} for i in range(8)}
    for i, addr, value in re.findall(r"^INSTRUCTION_WORD (\d+) ([0-9A-F]{8}) ([0-9a-fA-F]{8})$", raw, re.M):
        words[int(i)][int(addr, 16)] = int(value, 16)
    singles = [tuple(sample.get(addr) for addr in range(0x2000F000, 0x2000F028, 4))
               for sample in words.values()]
    startup_ok = (run / "startup.bin").read_bytes() == IMAGE.read_bytes()
    values = {}
    for index, (field, expected) in enumerate(EXPECTED.items()):
        values[field] = {
            "expected": f"0x{expected:08X}",
            "block": [f"0x{sample[index]:08X}" for sample in dumps],
            "word": [f"0x{sample[index]:08X}" if sample[index] is not None else None for sample in singles],
        }
    result = {
        "startup_matches_image": startup_ok,
        "both_methods_equal_and_stable": all(s == dumps[0] for s in dumps + singles),
        "all_expected_in_all_reads": startup_ok and all(s == tuple(EXPECTED.values()) for s in dumps + singles),
        "values": values,
        "sha256": {path.name: sha(path) for path in [*binaries, run / "startup.bin", log]},
    }
    save(run / "result.json", result)
    for label, item in values.items():
        print(label, f'expected={item["expected"]}', "block=" + ",".join(sorted(set(item["block"]))),
              "word=" + ",".join(sorted(str(x) for x in set(item["word"]))))
    for label in ("startup_matches_image", "both_methods_equal_and_stable", "all_expected_in_all_reads"):
        print(f"{label}={result[label]}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=("audit", "program", "observe"))
    phase = parser.parse_args().phase
    before, image = audit()
    source = flash_tcl(len(image))
    if phase == "audit":
        print("AUDIT_PASS 196 bytes, one startup page, pinned input hashes")
        return
    run = HERE / datetime.now().strftime(phase + "_%Y%m%d_%H%M%S_%f")
    run.mkdir()
    print(f"RUN_DIR={run}", flush=True)
    try:
        if phase == "program":
            tcl = run / "flash_instruction.tcl"
            tcl.write_text(source, encoding="utf-8")
            program(run, before, image, tcl, FLASH_MARK)
        else:
            observe(run)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        save(run / "stop.json", {"error": str(error)})
        raise


if __name__ == "__main__":
    main()
