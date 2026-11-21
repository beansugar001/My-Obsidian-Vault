"""Read-only snapshot of the CY63300 sample: image identity, mailbox, result block,
stack frame and PLM window.  Nothing is written to target memory."""
import json, subprocess, struct, sys
from datetime import datetime
from hashlib import sha256
from pathlib import Path

HERE = Path(r"C:\Users\24796\Documents\组\CY63300_内存安全首轮\stack_check_20261120")
sys.path.insert(0, str(HERE / "lib"))
from board import OCD, CFG

ROOT = Path(r"D:\obsidianvaults\笔记\beansugar\vibe coding\memory\cy63300自动测试日志\2026-11-21_CY63300_栈对象登记")
run = ROOT / ("snapshot_" + datetime.now().strftime("%Y%m%d_%H%M%S") + "_readonly")
run.mkdir(parents=True, exist_ok=False)
d = run.as_posix()

TCL = r'''
proc rd {addr} {
    dump_image "DPLACE/tmp.bin" $addr 4
    set fh [open "DPLACE/tmp.bin" rb]
    binary scan [read $fh 4] i v
    close $fh
    return [expr {$v & 0xffffffff}]
}
proc shot {rel addr len} {
    if {[catch {dump_image "DPLACE/$rel" $addr $len} e]} { echo "R_ERR_$rel=$e" }
}
proc go {} {
    if {[catch {init} e]} { echo "R_ERROR=init:$e"; return }
    echo "R_STATE0=[riscv.cpu curstate]"
    if {[catch {halt 2000} e]} { echo "R_HALT=FAIL:$e" }
    echo "R_STATE1=[riscv.cpu curstate]"
    shot flash.bin 0x0 1024
    shot mbox.bin 0x2000F000 68
    shot res.bin 0x2000F100 28
    shot frame.bin 0x2001FEE0 32
    shot plm.bin 0x70000000 16
    if {[catch {echo "R_MARK=[format 0x%08X [rd 0x2000F000]]"} e]} { echo "R_ERR_MARK=$e" }
    if {[catch {echo "R_RES0=[format 0x%08X [rd 0x2000F100]] R1=[format 0x%08X [rd 0x2000F104]]"} e]} { echo "R_ERR_RES=$e" }
    if {[catch {echo "R_MCAUSE_MEM=[format 0x%08X [rd 0x2000F108]] MEPC_MEM=[format 0x%08X [rd 0x2000F10C]]"} e]} { echo "R_ERR_MC=$e" }
    if {[catch {echo "R_TRAPMARK=[format 0x%08X [rd 0x2000F110]] PH2=[format 0x%08X [rd 0x2000F114]]"} e]} { echo "R_ERR_TR=$e" }
    if {[catch {echo "R_FRAME8=[format 0x%08X [rd 0x2001FEE8]] FRAME28=[format 0x%08X [rd 0x2001FEFC]]"} e]} { echo "R_ERR_FR=$e" }
    if {[catch {echo "R_PLM0=[format 0x%08X [rd 0x70000000]] PLM4=[format 0x%08X [rd 0x70000004]]"} e]} { echo "R_ERR_PLM=$e" }
    if {[catch {resume} e]} { echo "R_RESUME=FAIL:$e" } else { echo "R_RESUME=OK" }
    echo "R_STATE2=[riscv.cpu curstate]"
    echo "R_DONE"
}
if {[catch {go} r]} { echo "R_TOP_ERROR=$r" }
shutdown
'''
(run / "main.tcl").write_text(TCL.replace("DPLACE", d), encoding="utf-8")
log = run / "openocd.log"
with log.open("xb") as out:
    rc = subprocess.run([str(OCD), "-f", CFG.as_posix(), "-c", "source {" + d + "/main.tcl}"],
                        cwd=OCD.parent, stdout=out, stderr=subprocess.STDOUT, timeout=240).returncode
text = log.read_text(encoding="utf-8", errors="replace")
print("rc=", rc)
for ln in text.splitlines():
    if ln.startswith("R_") or "Error" in ln or "error" in ln:
        print(ln)

def words(name, n):
    p = run / name
    if not p.exists():
        return None
    b = p.read_bytes()
    return ["0x%08X" % struct.unpack_from("<I", b, i)[0] for i in range(0, min(len(b), n * 4), 4)]

out = {"run": str(run), "rc": rc, "log_sha256": sha256(log.read_bytes()).hexdigest().upper(),
       "mbox": words("mbox.bin", 17), "res": words("res.bin", 7), "frame": words("frame.bin", 8),
       "plm": words("plm.bin", 4)}
fp = run / "flash.bin"
if fp.exists():
    flash = fp.read_bytes()
    out["flash_first436_sha256"] = sha256(flash[:436]).hexdigest().upper()
    out["flash_word_0x100"] = "0x%08X" % struct.unpack_from("<I", flash, 0x100)[0]
    out["flash_word_0x1ac"] = "0x%08X" % struct.unpack_from("<I", flash, 0x1ac)[0]
    out["flash_tail_all_ff"] = all(x == 0xFF for x in flash[436:])
mib = HERE / "firmware.bin"
if mib.exists():
    out["firmware_bin_sha256"] = sha256(mib.read_bytes()).hexdigest().upper()
(run / "snapshot.json").write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
print(json.dumps(out, ensure_ascii=False, indent=1))
