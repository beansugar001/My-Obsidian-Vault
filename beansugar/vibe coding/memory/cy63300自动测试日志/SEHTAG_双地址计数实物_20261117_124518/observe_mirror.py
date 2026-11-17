import json
import os
from pathlib import Path
import re
import struct
import subprocess

from run_real_instruction import CFG, OCD, save, sha

ADDRESSES = {
    "first": 0x2000F004,
    "first_copy": 0x2000F104,
    "second": 0x2000F010,
    "second_copy": 0x2000F110,
    "done": 0x2000F02C,
    "scratch": 0x2000F030,
}


def observe_mirror(run, image, marker, expected):
    flash_run = Path(json.loads(marker.read_text(encoding="utf-8"))["run"])
    if not json.loads((flash_run / "program_result.json").read_text(encoding="utf-8"))["verified"]:
        raise RuntimeError("Missing verified Flash programming result")
    clients = subprocess.run(
        ["powershell", "-NoProfile", "-Command", "(Get-Process -ErrorAction Stop).ProcessName"],
        capture_output=True, check=True, timeout=20,
    ).stdout
    if re.search(rb"(openocd|pyocd|probe-rs|daplink|cmsis-dap|[a-z0-9-]+-gdb)", clients, re.I):
        raise RuntimeError("Active debug process")
    preflight = (image.parent.parent / "v160_cold_boot.tcl").read_text(encoding="utf-8")
    source = preflight.split("dump_image", 1)[0] + r"""
proc read_word {sample field addr} {
    set output [capture [format "mdw 0x%08X" $addr]]
    set pattern [format {^\s*0x%08x:\s+([0-9a-f]{8})\s*$} $addr]
    if {![regexp -nocase $pattern $output -> value]} {error "READ_PARSE <$output>"}
    echo [format "MIRROR_WORD %02d %s %08X %s" $sample $field $addr $value]
}

dump_image "$::env(MIRROR_RUN)/mailbox_before.bin" 0x2000F000 0x34
for {set i 0} {$i < 12} {incr i} {
    if {[riscv.cpu curstate] ne "running"} {error HART_NOT_RUNNING}
    if {$i % 2 == 0} {
        set addresses {second 0x2000F010 second_copy 0x2000F110 second 0x2000F010}
    } else {
        set addresses {second_copy 0x2000F110 second 0x2000F010 second_copy 0x2000F110}
    }
    foreach {field addr} $addresses {
        read_word $i $field $addr
    }
    foreach {field addr} {first 0x2000F004 first_copy 0x2000F104 done 0x2000F02C scratch 0x2000F030} {
        read_word $i $field $addr
    }
    sleep 120
}
dump_image "$::env(MIRROR_RUN)/mailbox_after.bin" 0x2000F000 0x34
dump_image "$::env(MIRROR_RUN)/startup.bin" 0x00000000 0x174
echo MIRROR_SAMPLES_COMPLETE
shutdown
"""
    tcl = run / "observe_readonly.tcl"
    tcl.write_text(source, encoding="utf-8")
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + tcl.as_posix() + "}"]
    env = {"MIRROR_RUN": run.as_posix()}
    save(run / "command.json", {"argv": argv, "cwd": str(OCD.parent), "env": env,
                               "tcl_sha256": sha(tcl)})
    log = run / "openocd.log"
    with log.open("xb") as output:
        rc = subprocess.run(argv, cwd=OCD.parent, env={**os.environ, **env}, stdout=output,
                            stderr=subprocess.STDOUT, timeout=55).returncode
    raw = log.read_text(encoding="utf-8", errors="replace")
    if rc or "Error:" in raw or raw.splitlines().count("MIRROR_SAMPLES_COMPLETE") != 1:
        print(raw)
        raise RuntimeError("Read-only sampling incomplete")

    samples = {i: [] for i in range(12)}
    for seq, field, addr, value in re.findall(
        r"^MIRROR_WORD (\d+) (\w+) ([0-9A-F]{8}) ([0-9a-fA-F]{8})$", raw, re.M,
    ):
        if int(addr, 16) != ADDRESSES.get(field):
            raise RuntimeError("Logged address does not match its field")
        samples[int(seq)].append((field, int(value, 16)))
    control_fields = ["first", "first_copy", "done", "scratch"]
    for seq, sample in samples.items():
        expected_order = (["second", "second_copy", "second"] if seq % 2 == 0
                          else ["second_copy", "second", "second_copy"])
        if [field for field, _ in sample] != expected_order + control_fields:
            raise RuntimeError(f"Invalid read order in sample {seq}")
    values = {name: [v for reads in samples.values() for field, v in reads if field == name]
              for name in ADDRESSES}
    controls_ok = all(
        set(values[field]) == {value}
        for field, value in (("first", 8), ("first_copy", 8),
                             ("done", 0x52547000), ("scratch", 0x53454000))
    )
    summaries = {name: {"count": len(reads), "first": reads[0], "last": reads[-1],
                        "unique": len(set(reads)), "min": min(reads), "max": max(reads)}
                 for name, reads in values.items()}
    bins = [run / f"mailbox_{label}.bin" for label in ("before", "after")]
    checks = []
    for binary in bins:
        fields = dict(zip(expected, struct.unpack("<13I", binary.read_bytes())))
        checks.append({k: f"0x{v:08X}" for k, v in fields.items()
                       if k != "second_count" and expected[k] != v})
    startup = run / "startup.bin"
    result = {
        "startup_matches_image": startup.read_bytes() == image.read_bytes(),
        "fixed_controls_pass": controls_ok and not any(checks),
        "fixed_mailbox_differences": checks,
        "summaries": summaries,
        "paired_samples_in_read_order": samples,
        "sha256": {p.name: sha(p) for p in [*bins, startup, log]},
    }
    save(run / "result.json", result)
    print(json.dumps({k: v for k, v in result.items() if k != "paired_samples_in_read_order"}, indent=2))
