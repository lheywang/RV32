#!/bin/bash
# Run all Verilator/Make builds, log output, and summarize results.

set -euo pipefail

# List of module targets
targets=(
    clock
    counter
    pcounter
    decoder
    endianess
    registers
    csr
    reset
    occupancy
    booth       # modules for the ALU2
    shift       # modules for the ALU2
    srt         # modules for the ALU2
    alu0
    alu1
    alu2
    alu5
)

# Create logs and reports folders
log_dir="logs"
report_dir="${log_dir}/reports"
mkdir -p "$log_dir" "$report_dir"

fail_count=0
fail_list=()

echo "🔧 Starting Verilator builds..."
echo "Logs will be saved in: $log_dir"
echo "Reports will be saved in: $report_dir"
echo

for target in "${targets[@]}"; do
    log_file="${log_dir}/${target}.ans"
    report_file="${report_dir}/${target}.md"

    echo "➡️  Building $target ... (logging to $log_file)"
    if make TOP="$target" >"$log_file" 2>&1; then
        echo "✅ $target build passed"
    else
        echo "❌ $target build failed — see $log_file"
        fail_count=$((fail_count + 1))
        fail_list+=("$target")
    fi

    # Always generate a report, even if the build failed
    if [[ -s "$log_file" ]]; then
        echo "🧾 Generating report for $target ..."
        ./utils/generate_report.py -m FILE -f "$log_file" -o "$report_file" || {
            echo "⚠️  Failed to generate report for $target"
        }
    else
        echo "⚠️  Log file for $target is empty — skipping report."
    fi
    echo
done

# Summary
echo "========================================================"
if [[ $fail_count -eq 0 ]]; then
    echo "🎉 All ${#targets[@]} builds passed successfully!"
else
    echo "⚠️  $fail_count / ${#targets[@]} builds failed:"
    printf '   - %s\n' "${fail_list[@]}"
    echo
    echo "Check logs in $log_dir and reports in $report_dir for details."
    exit 1
fi

echo "✅ Reports generated in: $report_dir"