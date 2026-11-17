import argparse
from datetime import datetime
import os
from pathlib import Path
import re
import subprocess

from observe_active_low import CFG, HELPER, OCD, STARTUP, source, save, sha

HERE = Path(__file__).resolve().parent
BODY = HERE / "observe_steps.tcl"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    source()  # Verify the reused startup, read helper, and probe configuration.
    init = STARTUP.read_text(encoding="utf-8").split("dump_image", 1)[0]
    init = init.replace("set startup [capture {init}]\n", "set startup [capture {init; poll off}]\n", 1)
    if "capture {init; poll off}" not in init:
        raise RuntimeError("Missing init and poll-off sequence")
    helper = HELPER.read_text(encoding="utf-8").split("proc check_controls", 1)[0]
    code = init + helper + BODY.read_text(encoding="ascii")
    if re.search(r"\b(halt|resume|reset|mww|mwh|mwb|dmi_write|load_image|flash|write_memory)\b", code, re.I):
        raise RuntimeError("Unexpected command in sampling Tcl")
    if not args.execute:
        print("STEP_READ_ONLY_AUDIT_PASS")
        return

    names = subprocess.run(
        ["powershell", "-NoProfile", "-Command", "(Get-Process -ErrorAction Stop).ProcessName"],
        check=True, capture_output=True, timeout=20,
    ).stdout
    if re.search(rb"^(openocd|pyocd|probe-rs|JLink[^\r\n]*|[^\r\n]*-gdb)\r?$", names, re.I | re.M):
        raise RuntimeError("Active debug process")
    run = HERE / datetime.now().strftime("staged_%Y%m%d_%H%M%S_%f")
    run.mkdir()
    tcl = run / "run.tcl"
    tcl.write_text(code, encoding="utf-8")
    argv = [str(OCD), "-f", CFG.as_posix(), "-c", "source {" + tcl.as_posix() + "}"]
    env = {"GPIO_GATE": run.as_posix()}
    save(run / "command.json", {"argv": argv, "cwd": str(OCD.parent), "env": env, "tcl_sha256": sha(tcl)})
    print("RUN_DIR=" + str(run), flush=True)
    log = run / "openocd.log"
    with log.open("xb") as out:
        try:
            status = subprocess.run(argv, cwd=OCD.parent, env={**os.environ, **env}, stdout=out,
                                    stderr=subprocess.STDOUT, timeout=375).returncode
        except subprocess.TimeoutExpired:
            status = None
    lines = [line for line in log.read_text(encoding="utf-8", errors="replace").splitlines()
             if line.startswith("User :") and re.search(r"\bSTEP_[A-Z]", line)]
    save(run / "result.json", {"exit_code": status, "stages": lines, "log_sha256": sha(log)})
    print("\n".join(lines))
    if status or not any(line.endswith("STEP_SESSION_END") for line in lines):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
