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
    booth
    alu0
    alu1
    alu5
)

# Create a logs folder
log_dir="logs"
mkdir -p "$log_dir"

fail_count=0
fail_list=()

echo "🔧 Starting Verilator builds..."
echo "Logs will be saved in: $log_dir"
echo

for target in "${targets[@]}"; do
    log_file="${log_dir}/${target}.ans"

    echo "➡️  Building $target ... (logging to $log_file)"
    if make TOP="$target" >"$log_file"; then
        echo "✅ $target passed"
    else
        echo "❌ $target failed — see $log_file"
        fail_count=$((fail_count + 1))
        fail_list+=("$target")
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
    echo "Check logs in $log_dir for details."
    exit 1
fi
