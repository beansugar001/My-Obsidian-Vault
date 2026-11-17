import hashlib
import json
from pathlib import Path

here = Path(__file__).resolve().parent
snapshot, = (here / "runs").glob("snapshot_*/main_sector0_64KiB.bin")
data = snapshot.read_bytes()
image = (here / "hello.bin").read_bytes()
old = (here.parent / "V118_FLASH_CANDIDATE/cpu_i2c_paced_probe_flash.bin").read_bytes()
if len(data) != 65536 or len(image) == 0 or len(image) > len(data):
    raise ValueError("Invalid image or snapshot size")

sha = lambda blob: hashlib.sha256(blob).hexdigest().upper()
report = {
    "snapshot": str(snapshot.relative_to(here)),
    "snapshot_sha256": sha(data),
    "image_sha256": sha(image),
    "image_bytes": len(image),
    "image_start": "0x00000000",
    "image_last": f"0x{len(image)-1:08X}",
    "matches_v118_prefix": data[:len(old)] == old,
    "last_non_ff": f"0x{max(i for i, value in enumerate(data) if value != 0xFF):08X}",
    "zero_to_one_bytes": sum((before & after) != after for before, after in zip(data, image)),
    "target_flash_writes": 0,
    "target_flash_erases": 0,
}
with (here / "flash_compare.json").open("x", encoding="utf-8") as output:
    json.dump(report, output, indent=2)
print(json.dumps(report, indent=2))
