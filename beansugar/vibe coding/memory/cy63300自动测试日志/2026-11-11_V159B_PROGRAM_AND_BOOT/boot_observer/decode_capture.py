import argparse
import csv
import json
from pathlib import Path
import struct


SCL = 0x100
SDA = 0x200
BUS = SCL | SDA
MAGIC = 0x158B0501
CAPACITY = 4096


def decode(raw):
    if len(raw) != 32 + 4 * CAPACITY:
        raise ValueError("Unexpected mailbox length")
    magic, state, command, count, start, idle, latest, clock = struct.unpack_from("<8I", raw)
    if magic != MAGIC or state not in (2, 3) or command != 1 or idle != BUS or count > CAPACITY:
        raise ValueError("Invalid capture state")
    if (state == 3) != (count == CAPACITY) or latest & ~BUS:
        raise ValueError("Inconsistent capture bounds")
    edges = [(word >> 2, (word & 3) << 8)
             for (word,) in struct.iter_unpack("<I", raw[32:32 + count * 4])]
    frames = []
    active = None
    before = idle
    prev_time = -1
    for time, pins in edges:
        if time <= prev_time or pins == before or pins & ~BUS:
            raise ValueError(f"Invalid edge at cycle {time}")
        prev_time = time
        if (before & SCL) and (pins & SCL):
            if (before & SDA) and not (pins & SDA):
                active = {"start_ticks": time, "rising_bits": [], "ambiguous_rises": []}
                frames.append(active)
            elif active is not None and not (before & SDA) and (pins & SDA):
                active["stop_ticks"] = time
                active = None
        if active is not None and not (before & SCL) and (pins & SCL):
            bits = active["rising_bits"]
            if (before ^ pins) & SDA:
                active["ambiguous_rises"].append(len(bits) + 1)
            bits.append(int(bool(pins & SDA)))
        before = pins

    for frame in frames:
        bits = frame["rising_bits"]
        frame["byte_samples"] = [
            {"byte": int("".join(map(str, bits[i:i+8])), 2), "ack": bits[i+8] == 0}
            for i in range(0, len(bits) - 8, 9)
        ]

        bits = frame["rising_bits"]
        if len(bits) >= 8 and not any(n <= 8 for n in frame["ambiguous_rises"]):
            address_byte = int("".join(map(str, bits[:8])), 2)
            frame["address_byte"] = f"0x{address_byte:02X}"
            frame["address_7bit"] = f"0x{address_byte >> 1:02X}"
            frame["direction"] = "R" if address_byte & 1 else "W"
        if len(bits) >= 9 and 9 not in frame["ambiguous_rises"]:
            frame["ack_sample"] = "ACK" if bits[8] == 0 else "NACK"
    summary = {
        "capture_state": state, "edge_count": count, "overflow": state == 3,
        "clock_cfgr": f"0x{clock:08X}", "counter_at_arm": start,
        "initial_levels": f"0x{idle:03X}", "final_levels": f"0x{latest:03X}",
        "frames": frames,
    }
    return summary, edges


def verify(summary, payloads):
    if summary["overflow"] or summary["initial_levels"] != "0x300" or summary["final_levels"] != "0x300":
        return False
    if len(summary["frames"]) != len(payloads):
        return False
    for frame, payload in zip(summary["frames"], payloads):
        expected = [{"byte": byte, "ack": True} for byte in [0x78, *payload]]
        rises = len(frame["rising_bits"])
        if (frame["ambiguous_rises"] or "stop_ticks" not in frame
                or rises not in (len(expected) * 9, len(expected) * 9 + 1)
                or frame["byte_samples"] != expected):
            return False
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mailbox", type=Path)
    args = parser.parse_args()
    summary, edges = decode(args.mailbox.read_bytes())
    expected = json.loads(Path(__file__).with_name("frames.json").read_text(encoding="utf-8"))
    summary["verified"] = verify(summary, expected["frames"])
    folder = args.mailbox.parent
    with (folder / "capture_edges.csv").open("x", encoding="utf-8", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(("ticks_after_arm_16_cycles", "scl", "sda"))
        writer.writerows((time, int(bool(pins & SCL)), int(bool(pins & SDA))) for time, pins in edges)
    rendered = json.dumps(summary, indent=2)
    with (folder / "capture_decode.json").open("x", encoding="utf-8") as output:
        output.write(rendered + "\n")
    print(f"Verified={summary['verified']} edges={summary['edge_count']} frames={len(summary['frames'])}")
    for i, frame in enumerate(summary["frames"]):
        samples = frame["byte_samples"]
        print(f"Frame {i}: {len(samples)} bytes, {sum(item['ack'] for item in samples)} ACK")
    return 0 if summary["verified"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
