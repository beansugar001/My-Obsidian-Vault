
from __future__ import annotations
import json
import os
import re
import struct
import subprocess
import sys
from datetime import datetime
from hashlib import sha256
from pathlib import Path

HERE = Path(r"C:\Users\24796\Documents\组\CY63300_内存安全首轮")
sys.path.insert(0, str(HERE.parent / "SEHTAG_CSR可逆探针/单次触发探针"))
from run_real_csr import CFG, OCD, PINNED, V160_TCL, flash_tcl, run_phase, save, sha  # noqa: E402

LOG_ROOT = Path(os.environ.get("CY63300_LOG_ROOT", str(HERE / "recheck_20261120")))
REC = LOG_ROOT
RAW_DIR = HERE / "raw_recheck"
RAW_IMAGE = RAW_DIR / "firmware.bin"
RAW_PREV = HERE / "program_20261119_183558_576423/independent_readback/readback.bin"
LIVE_DIR = HERE / "live_check"
LIVE_IMAGE = LIVE_DIR / "firmware.bin"
PINNED_EXTRA = {
    RAW_IMAGE: "973407F8837981CA321D192EF2AFD8F1234CDEC6A1ADF51DAF20E146E0DC2921",
    RAW_PREV: "1B261F122EE7281C0EAAA0683122199392805F96ACA772664478E87D4DDA5699",
    LIVE_IMAGE: "5CBDB64E57CB0AABBFAC372500389846B4D98258231659E89144B03FBA179B1D",
}
SECTOR = 0x10000
PATTERN = (0x2468ACE0, 0x13579BDF)
POISON = (0xDEADBEEF, 0xCAFEBABE)


def audit():
    for path, digest in {**PINNED, **PINNED_EXTRA}.items():
        if sha(path) != digest:
            raise RuntimeError(f"SHA256 mismatch: {path}")
    image = RAW_IMAGE.read_bytes()
    live = LIVE_IMAGE.read_bytes()
    if len(image) != 428 or len(live) != 512:
        raise RuntimeError("Unexpected image sizes")
    prev = RAW_PREV.read_bytes()
    provenance = {
        "archived_readback": str(RAW_PREV),
        "archived_len": len(prev),
        "archived_prefix_matches_raw_image": len(prev) == SECTOR and prev[:len(image)] == image,
        "archived_prefix_sha256": sha256(prev[:len(image)]).hexdigest().upper(),
        "note": "archived 2026-11-19 18:35 readback prefix equals the 388-byte FIRST image, so it does not certify the 428-byte RAW image; board certification is done in this run",
    }
    print("PROVENANCE=" + json.dumps(provenance, ensure_ascii=False), flush=True)
    return image, live, provenance


def flash_raw(run, image, live, tcl):
    expected_live = live + b"\xff" * (SECTOR - len(live))
    before = run_phase(run, tcl, run / "candidate.bin" if False else RAW_IMAGE, "pre_erase", "snapshot", SECTOR)
    if before != expected_live:
        raise RuntimeError("Live Flash is not the identified LIVE image")
    save(run / "pre_flash_live_snapshot.json", {
        "sector_sha256": sha(run / "pre_erase/readback.bin"),
        "first_bytes_sha256": sha256(before[:len(live)]).hexdigest().upper(),
    })
    cand = run / "candidate.bin"
    cand.write_bytes(image)
    save(run / "flash_attempt.json", {"run": str(run), "image_sha256": sha(cand)})
    page = run_phase(run, tcl, cand, "erase_0000", "erase", 0x200,
                     sentinel=(0, struct.unpack_from("<I", before)[0]))
    if page != b"\xff" * 0x200:
        raise RuntimeError("Page 0 not blank after erase")
    programmed = run_phase(run, tcl, cand, "program", "program", len(image),
                           sentinel=(0, 0xFFFFFFFF), program_bytes=len(image))
    if programmed != image:
        raise RuntimeError("Program verify mismatch")
    actual = run_phase(run, tcl, cand, "independent_readback", "snapshot", SECTOR)
    expected = image + b"\xff" * (SECTOR - len(image))
    if actual != expected:
        raise RuntimeError("Independent sector readback mismatch")
    save(run / "program_result.json", {
        "verified": True, "bytes": len(image), "image_sha256": sha(cand),
        "sector_sha256": sha(run / "independent_readback/readback.bin"),
        "marked_for_recheck": True,
    })
    print("PASS_RAW_IMAGE_VERIFIED", flush=True)


def round_tcl(run, image):
    tail_word = struct.unpack_from("<I", image, len(image) - 4)[0]
    p = str(run).replace("\\", "/")
    return (
        'proc rd {addr} {\n'
        f'    dump_image "{p}/tmp.bin" $addr 4\n'
        f'    set fh [open "{p}/tmp.bin" rb]\n'
        '    binary scan [read $fh 4] i v\n'
        '    close $fh\n'
        '    return [expr {$v & 0xffffffff}]\n'
        '}\n'
        'proc go {} {\n'
        '    if {[catch {init} e]} { echo "OF_ERROR=init:$e"; return }\n'
        '    echo "OF_INIT_OK"\n'
        '    echo "OF_STATE0=[riscv.cpu curstate]"\n'
        '    if {[riscv.cpu curstate] eq "running"} { catch {halt 2000} }\n'
        '    echo "OF_PC_BEFORE=[reg pc]"\n'
        f'    if {{[rd 0x{len(image)-4:x}] != 0x{tail_word:08x}}} {{ echo "OF_IMAGE_MISMATCH"; return }}\n'
        '    echo "OF_IMAGE_WORD_OK"\n'
        '    catch {mww 0x2000F000 0x00000000}\n'
        '    mww 0x2000F048 0xDEADBEEF\n'
        '    mww 0x2000F04C 0xCAFEBABE\n'
        '    echo [format "OF_POISON_READ=0x%08X/0x%08X" [rd 0x2000F048] [rd 0x2000F04C]]\n'
        '    if {[catch {reg pc 0x0} e]} { echo "OF_SETPC_ERROR=$e" }\n'
        '    echo "OF_PC_AFTER_SET=[reg pc]"\n'
        '    if {[catch {resume} e]} { echo "OF_RESUME_ERROR=$e" }\n'
        '    set tried 0\n'
        '    while {$tried < 80} {\n'
        '        sleep 25\n'
        f'        if {{[rd 0x2000F000] == 0x{0x4D533132:08x}}} {{ break }}\n'
        '        incr tried\n'
        '    }\n'
        '    echo "OF_POLLS=$tried"\n'
        '    echo [format "OF_MARKER=0x%08X" [rd 0x2000F000]]\n'
        '    echo "OF_STATE1=[riscv.cpu curstate]"\n'
        f'    echo [format "OF_W14_W15=0x%08X/0x%08X" [rd 0x2000F038] [rd 0x2000F03C]]\n'
        f'    echo [format "OF_BEFORE=0x%08X/0x%08X" [rd 0x2000F050] [rd 0x2000F054]]\n'
        f'    echo [format "OF_AFTER_OS=0x%08X/0x%08X" [rd 0x2000F058] [rd 0x2000F05C]]\n'
        f'    echo [format "OF_AFTER_OF=0x%08X/0x%08X" [rd 0x2000F060] [rd 0x2000F064]]\n'
        f'    dump_image "{p}/dest_a.bin" 0x2000F048 8\n'
        f'    dump_image "{p}/mbox_a.bin" 0x2000F000 104\n'
        f'    dump_image "{p}/dest_b.bin" 0x2000F048 8\n'
        f'    dump_image "{p}/mbox_b.bin" 0x2000F000 104\n'
        '    echo "OF_STATE2=[riscv.cpu curstate]"\n'
        '    echo "OF_DONE"\n'
        '}\n'
        'if {[catch {go} e]} { echo "OF_TOP_ERROR=$e" }\n'
        'echo "OF_SHUTDOWN_REQUEST"\n'
        'shutdown\n'
    )


def main():
    image, live, provenance = audit()
    tcl_source = flash_tcl(len(image))
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    run = REC / f"overflow_{stamp}"
    run.mkdir()
    print(f"RUN_DIR={run}", flush=True)
    try:
        flash_tcl_path = run / "flash_raw.tcl"
        flash_tcl_path.write_text(tcl_source, encoding="utf-8")
        save(run / "image_provenance.json", provenance)
        flash_raw(run, image, live, flash_tcl_path)
        rtcl = run / "round.tcl"
        rtcl.write_text(round_tcl(run, image), encoding="utf-8")
        argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + rtcl.as_posix() + "}"]
        save(run / "round_command.json", {"argv": argv, "tcl_sha256": sha(rtcl)})
        log = run / "openocd.log"
        with log.open("xb") as out:
            rc = subprocess.run(argv, cwd=OCD.parent, stdout=out, stderr=subprocess.STDOUT, timeout=180).returncode
        text = log.read_text(encoding="utf-8", errors="replace")
        print("ROUND_RC=", rc, flush=True)
        for line in text.splitlines():
            if re.match(r"^(OF_|PASS_)", line):
                print(line, flush=True)
        save(run / "round_log_sha.json", {"log_sha256": sha(log)})
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        save(run / "stop.json", {"error": str(exc)})
        raise


if __name__ == "__main__":
    main()
