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

echo "Verifpal version:"
verifpal --version
echo

status=0
for model in "${models[@]}"; do
    printf "Checking %-40s ... " "$model"
    if [[ ! -f "$model" ]]; then
        echo "MISSING"
        status=1
        continue
    fi
    if verifpal pretty "$model" >/dev/null 2>&1; then
        echo "OK"
    else
        echo "FAILED"
        echo "  Run manually: verifpal pretty \"$model\""
        status=1
    fi
done

echo
if [[ "$status" -eq 0 ]]; then
    echo "All models parsed successfully."
else
    echo "One or more models failed the check." >&2
fi

exit "$status"
