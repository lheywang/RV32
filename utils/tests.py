#!/usr/bin/env python3
import subprocess
import concurrent.futures
import os
from datetime import datetime

# Config
targets = [
    "clock",
    "counter",
    "pcounter",
    "decoder",
    "endianess",
    "registers",
    "csr",
    "reset",
    "occupancy",
    "booth",
    "shift",
    "srt",
    "alu0",
    "alu1",
    "alu2",
    "alu5",
]
log_dir = "logs"
report_dir = os.path.join(log_dir, "reports")
summary_file = os.path.join(report_dir, "_summary.md")

os.makedirs(report_dir, exist_ok=True)


def run_build(target):
    """Run make for one target and generate its report."""
    log_file = os.path.join(log_dir, f"{target}.ans")
    report_file = os.path.join(report_dir, f"{target}.md")

    # Run make, capturing stdout and stderr
    with open(log_file, "w") as f:
        proc = subprocess.run(
            ["make", f"TOP={target}"],
            stdout=f,
            stderr=subprocess.STDOUT,
        )

    # Determine result based on log content
    status = "PASS"
    with open(log_file, "r") as f:
        content = f.read()
        if "FAIL" in content:
            status = "FAIL"

    # Generate report (even on failure)
    try:
        subprocess.run(
            [
                "./utils/generate_report.py",
                "-m",
                "FILE",
                "-f",
                log_file,
                "-o",
                report_file,
            ],
            check=False,
        )
    except Exception as e:
        print(f"⚠️  Failed to generate report for {target}: {e}")

    return target, status


def main():
    print(f"🔧 Starting parallel builds ({os.cpu_count()} workers)...")
    print(f"Logs:     {log_dir}")
    print(f"Reports:  {report_dir}\n")

    results = {}

    # Run builds in parallel
    with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count()) as ex:
        futures = {ex.submit(run_build, t): t for t in targets}
        for fut in concurrent.futures.as_completed(futures):
            target, status = fut.result()
            emoji = "✅" if status == "PASS" else "❌"
            print(f"{emoji} {target} → {status}")
            results[target] = status

    # Build global summary
    print("\n🧾 Generating global summary...")
    with open(summary_file, "w") as f:
        f.write("# 🧾 Global Test Summary\n\n")
        f.write("| Module | Status | Report |\n")
        f.write("| ------- | ------- | ------- |\n")
        for target in targets:
            status = results.get(target, "N/A")
            emoji = "✅" if status == "PASS" else "❌"
            report_link = f"./{target}.md"
            f.write(f"| {target} | {emoji} {status} | [{target}.md]({report_link}) |\n")
        f.write(f"\n*Generated automatically on {datetime.now()}*\n")

    # Summary result
    fail_count = sum(1 for s in results.values() if s == "FAIL")
    if fail_count == 0:
        print("\n🎉 All builds passed successfully!")
    else:
        print(f"\n⚠️  {fail_count} / {len(targets)} builds failed.")
        print(f"See details in {summary_file}")

    print(f"\n✅ Reports available in: {report_dir}")


if __name__ == "__main__":
    main()
