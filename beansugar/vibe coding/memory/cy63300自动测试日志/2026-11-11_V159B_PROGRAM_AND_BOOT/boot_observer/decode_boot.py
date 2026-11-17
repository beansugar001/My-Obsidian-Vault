
import csv
import json
import sys
from pathlib import Path

from decode_capture import decode, verify

mailbox = Path(sys.argv[1])
summary, edges = decode(mailbox.read_bytes())
payloads = json.loads(Path(__file__).with_name("frames.json").read_text())["frames"]
frames = summary["frames"]
# Power-off transitions can precede the six complete frames. Retain them in the evidence.
matches = [
    index for index in range(len(frames) - len(payloads) + 1)
    if verify({**summary, "frames": frames[index:index + len(payloads)]}, payloads)
]
start = matches[0] if len(matches) == 1 else None
passed = start is not None and start + len(payloads) == len(frames)
summary["verified_boot_frames"] = passed
summary["first_boot_frame"] = start
summary["preceding_frames"] = start
with mailbox.with_name("boot_capture_decode.json").open("x", encoding="utf-8") as out:
    json.dump(summary, out, indent=2)
with mailbox.with_name("boot_capture_edges.csv").open("x", encoding="utf-8", newline="") as out:
    writer = csv.writer(out)
    writer.writerow(("ticks_after_arm_16_cycles", "scl", "sda"))
    writer.writerows((ticks, int(bool(pins & 0x100)), int(bool(pins & 0x200))) for ticks, pins in edges)
print(f"VERIFIED={passed} edges={len(edges)} frames={len(frames)} preceding_frames={start}")
for index, frame in enumerate(frames):
    samples = frame["byte_samples"]
    print(f"frame={index} bytes={len(samples)} ack={sum(item['ack'] for item in samples)} stop={'stop_ticks' in frame}")
raise SystemExit(0 if passed else 1)

