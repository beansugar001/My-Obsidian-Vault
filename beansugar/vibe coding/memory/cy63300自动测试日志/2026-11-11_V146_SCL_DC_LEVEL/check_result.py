import json
from pathlib import Path
import re
import struct


ROOT = Path(__file__).resolve().parent
ARM = next((ROOT / "runs").glob("arm_*"))
READ = next((ROOT / "runs").glob("read_*"))
ARM_LOG = (ARM / "openocd.log").read_text()
READ_LOG = (READ / "openocd.log").read_text()
CY_LOG = (ROOT / "cy_observe.log").read_text(encoding="utf-8-sig")


def main():
    words = struct.unpack("<23I", (READ / "pulse_mailbox.bin").read_bytes())
    magic, state, command, count, start, idle, current, clock = words[:8]
    assert (magic, state, command, count) == (0x143B0501, 3, 1, 3)
    assert idle == current == 0x300 and clock == 0x001D040A
    assert "crh=0x44444444" in READ_LOG and "phase=read rc=0" in READ_LOG
    assert "V146_COMPLETE phase=observe rc=0" in CY_LOG
    low = int(re.search(r"ARM_BEGIN host_ms=(\d+)", ARM_LOG).group(1))
    high = int(re.search(r"ARM_END host_ms=(\d+)", ARM_LOG).group(1))
    readings = [(int(t), int(raw, 16), int(mask, 16)) for t, raw, mask in re.findall(
        r"^V146_INPUT .*?host_ms=(\d+) idr=0x([0-9A-F]+) masked=0x([0-9A-F]+)$",
        CY_LOG, re.M,
    )]
    phases = []
    for index, label in enumerate(("idle", "scl_low", "final_idle")):
        pos = 8 + index * 5
        phase, begin, first, last, end = words[pos:pos + 5]
        assert phase == index and end > begin
        stable = [(raw, mask) for t, raw, mask in readings
                  if high + begin / 72000 + 200 <= t <= low + end / 72000 - 200]
        assert len(stable) >= 3, (label, stable)
        phases.append({
            "phase": label,
            "duration_ms": round((end - begin) / 72000, 3),
            "stm32_samples": [f"0x{first:03X}", f"0x{last:03X}"],
            "cy63300_sample_count": len(stable),
            "cy63300_idr": [f"0x{raw:08X}" for raw in sorted({raw for raw, _ in stable})],
            "cy63300_masked": [f"0x{mask:X}" for mask in sorted({mask for _, mask in stable})],
        })
    result = {"cy_total_samples": len(readings), "phases": phases}
    rendered = json.dumps(result, indent=2)
    with (ROOT / "v146_aligned_result.json").open("x", encoding="utf-8") as output:
        output.write(rendered + "\n")
    print(rendered)


if __name__ == "__main__":
    main()
