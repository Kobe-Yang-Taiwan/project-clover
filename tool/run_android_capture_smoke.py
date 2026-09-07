"""Capture external Android state while the synthetic smoke test is alive."""
from pathlib import Path
import subprocess
import sys

output = Path("build")
output.mkdir(exist_ok=True)
process = subprocess.Popen(
    ["flutter", "test", "integration_test/critical_draft_device_test.dart",
     "--reporter", "expanded"],
    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
)
with (output / "device-smoke.log").open("w") as log:
    for line in process.stdout:
        print(line, end="", flush=True)
        log.write(line)
        log.flush()
        if "CLOVER_DEVICE_EVIDENCE" in line:
            with (output / "device-alarm.txt").open("w") as alarms:
                subprocess.run(["adb", "shell", "dumpsys", "alarm"],
                               stdout=alarms, check=True, timeout=10)
            with (output / "device-saved.png").open("wb") as screenshot:
                subprocess.run(["adb", "exec-out", "screencap", "-p"],
                               stdout=screenshot, check=True, timeout=10)
sys.exit(process.wait())
