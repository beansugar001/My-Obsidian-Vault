import argparse
import csv
import json
from pathlib import Path
import struct


SCL = 0x100
SDA = 0x200
BUS = SCL | SDA
MAGIC = 0x143B0501
CAPACITY = 512


def decode(raw):
    if len(raw) != 32 + 8 * CAPACITY:
        raise ValueError("Unexpected mailbox length")
    magic, state, command, count, start, idle, latest, clock = struct.unpack_from("<8I", raw)
    if magic != MAGIC or state not in (2, 3) or command != 1 or idle != BUS or count > CAPACITY:
        raise ValueError("Invalid capture state")
    if (state == 3) != (count == CAPACITY) or latest & ~BUS:
        raise ValueError("Inconsistent capture bounds")
    raw_edges = struct.iter_unpack("<II", raw[32:32 + count * 8])
    edges = []
    cycle_offset = 0
    previous_raw = -1
    frames = []
    active = None
    before = idle
    prev_time = -1
    for raw_time, pins in raw_edges:
        if raw_time < previous_raw:
            cycle_offset += 1 << 32
        previous_raw = raw_time
        time = raw_time + cycle_offset
        edges.append((time, pins))
        if time <= prev_time or pins == before or pins & ~BUS:
            raise ValueError(f"Invalid edge at cycle {time}")
        prev_time = time
        if (before & SCL) and (pins & SCL):
            if (before & SDA) and not (pins & SDA):
                active = {"start_cycles": time, "rising_bits": [], "ambiguous_rises": []}
                frames.append(active)
            elif active is not None and not (before & SDA) and (pins & SDA):
                active["stop_cycles"] = time
                active = None
        if active is not None and not (before & SCL) and (pins & SCL):
            bits = active["rising_bits"]
            if (before ^ pins) & SDA:
                active["ambiguous_rises"].append(len(bits) + 1)
            bits.append(int(bool(pins & SDA)))
        before = pins

    for frame in frames:
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
        "counter_wraps": cycle_offset >> 32,
        "clock_cfgr": f"0x{clock:08X}", "counter_at_arm": start,
        "initial_levels": f"0x{idle:03X}", "final_levels": f"0x{latest:03X}",
        "frames": frames,
    }
    return summary, edges


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mailbox", type=Path)
    args = parser.parse_args()
    summary, edges = decode(args.mailbox.read_bytes())
    folder = args.mailbox.parent
    with (folder / "capture_edges.csv").open("x", encoding="utf-8", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(("cycles_after_arm", "scl", "sda"))
        writer.writerows((time, int(bool(pins & SCL)), int(bool(pins & SDA))) for time, pins in edges)
    rendered = json.dumps(summary, indent=2)
    with (folder / "capture_decode.json").open("x", encoding="utf-8") as output:
        output.write(rendered + "\n")
    print(rendered)


if __name__ == "__main__":
    main()
