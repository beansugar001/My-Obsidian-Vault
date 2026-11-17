import json
from pathlib import Path

source = Path("frames.json")
frames = json.loads(source.read_text(encoding="utf-8"))["frames"]
if len(frames) != 6 or sum(map(len, frames)) != 117 or max(map(len, frames)) != 41:
    raise ValueError("Unexpected V158 frame lengths")
with Path("frames.h").open("w", encoding="ascii", newline="\n") as output:
    print("/* Generated from V158 frames.json. */", file=output)
    print("static const struct { unsigned size; uint8_t data[41]; } frames[] = {", file=output)
    for frame in frames:
        print("    {%d, {%s}}," % (len(frame), ", ".join(f"0x{x:02X}" for x in frame)), file=output)
    print("};", file=output)


glyphs = json.loads(Path("digits.json").read_text(encoding="ascii"))["glyphs"]
if len(glyphs) != 10 or any(len(row) != 16 or any(not 0 <= byte <= 255 for byte in row) for row in glyphs):
    raise ValueError("Unexpected digit glyph dimensions")
with Path("frames.h").open("a", encoding="ascii", newline="\n") as output:
    print("static const uint8_t digit_glyphs[10][16] = {", file=output)
    for glyph in glyphs:
        print("    {" + ", ".join(f"0x{byte:02X}" for byte in glyph) + "},", file=output)
    print("};", file=output)
