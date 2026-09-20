#!/usr/bin/env bash
set -euo pipefail

if ! command -v verifpal >/dev/null 2>&1; then
    echo "Error: verifpal was not found in PATH." >&2
    exit 1
fi

models=(
  "01_symmetric_evidence_full.vp"
  "02_authentication.vp"
  "03_session_freshness.vp"
  "04_ack_binding.vp"
  "05_negative_no_fresh_nonce.vp"
)

sessions=(1 2 3)
results_dir="results"
mkdir -p "$results_dir"

echo "Verifpal version:"
verifpal --version | tee "$results_dir/verifpal_version.txt"
echo

for model in "${models[@]}"; do
    if [[ ! -f "$model" ]]; then
        echo "Error: missing model: $model" >&2
        exit 1
    fi

    stem="${model%.vp}"

    for s in "${sessions[@]}"; do
        log="$results_dir/${stem}_s${s}.log"
        code="$results_dir/${stem}_s${s}.code"

        echo "============================================================"
        echo "Model:    $model"
        echo "Sessions: $s"
        echo "Log:      $log"
        echo "============================================================"

        # Full human-readable report.
        # --fail-on-attack is intentionally omitted because some failed
        # queries are expected experimental results.
        verifpal verify "$model" \
            --sessions "$s" \
            --color never \
            2>&1 | tee "$log"

        # Compact result code for reproducibility/comparison.
        verifpal verify "$model" \
            --sessions "$s" \
            --color never \
            -q \
            --result-code \
            > "$code"

        echo "Result code: $(cat "$code")"
        echo
    done
done

echo "All requested runs completed."
echo "Results are stored in: $results_dir/"
