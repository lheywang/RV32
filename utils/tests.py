#!/usr/bin/env python3
import os
import subprocess
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime

# === CONFIG ===
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
    "alu4",
    "alu5",
]
log_dir = "logs"
report_dir = os.path.join(log_dir, "reports")
summary_file = os.path.join(report_dir, "_summary.md")

os.makedirs(report_dir, exist_ok=True)


def run_target(target: str):
    """Build target, generate report, and parse .stat file."""
    log_file = os.path.join(log_dir, f"{target}.ans")
    report_file = os.path.join(report_dir, f"{target}.md")
    stat_file = os.path.join(report_dir, f"{target}.stat")

    # Run Verilator build
    with open(log_file, "w") as f:
        subprocess.run(["make", f"TOP={target}"], stdout=f, stderr=subprocess.STDOUT)

    # Generate the Markdown report
    subprocess.run(
        ["./utils/generate_report.py", "-m", "FILE", "-f", log_file, "-o", report_file],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    # Parse .stat file (if available)
    stats = {"pass": 0, "fail": 0, "percent": 0.0}
    if os.path.exists(stat_file):
        with open(stat_file) as f:
            for line in f:
                k, v = line.strip().split("=")
                stats[k] = float(v)
        os.remove(stat_file)

    # Compute status
    status = "PASS" if stats["fail"] == 0 else "FAIL"
    return (
        target,
        status,
        int(stats["pass"]),
        int(stats["fail"]),
        float(stats["percent"]),
    )


def main():
    print(f"🔧 Running Verilator builds in parallel ({os.cpu_count()} threads)...\n")

    results = []
    with ThreadPoolExecutor(max_workers=os.cpu_count()) as executor:
        for res in executor.map(run_target, targets):
            target, status, passed, failed, percent = res
            emoji = "✅" if status == "PASS" and passed != 0 else "❌"
            msg = (
                " : No tests detected, perhaps check for build errors ?"
                if passed == 0 and failed == 0
                else ""
            )
            print(f"{emoji} {target:10s} → {status:4s} ({percent:.2f}%){msg}")
            results.append(res)

    # === Generate global summary ===
    total_pass = sum(r[2] for r in results)
    total_fail = sum(r[3] for r in results)
    avg_percent = sum(r[4] for r in results) / len(results)

    with open(summary_file, "w") as f:
        f.write("# 🧾 Global Test Summary\n\n")
        f.write("| Module | Status | Passed | Failed | Success (%) |\n")
        f.write("| ------- | ------- | ------- | ------- | ------------ |\n")
        for target, status, passed, failed, percent in results:
            emoji = "✅" if status == "PASS" and passed != 0 else "❌"
            f.write(
                f"| [{target}](./{target}.md) | {emoji} {status} | {passed} | {failed} | {percent:.2f} |\n"
            )

        f.write(f"\n**Total passed:** {total_pass}  \n")
        f.write(f"**Total failed:** {total_fail}  \n")
        f.write(f"**Average success:** {avg_percent:.2f}%  \n")
        f.write(f"\n*Generated on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n")

    print(f"\n📄 Summary written to: {summary_file}")
    print(f"📁 Reports directory: {report_dir}")
    print()
    print(f"Total passed: {total_pass}")
    print(f"Total failed: {total_fail}")
    print(f"Average success: {avg_percent:.2f}%")


if __name__ == "__main__":
    main()
