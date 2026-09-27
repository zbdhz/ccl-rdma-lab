#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$LAB_DIR/results"
RUN_DIR="$(mktemp -d "$LAB_DIR/results/smoke-$(date +%Y%m%d-%H%M%S)-XXXX")"
cp "$LAB_DIR/inputs/SimAI.conf" "$LAB_DIR/inputs/topology.txt" "$LAB_DIR/inputs/allreduce.txt" "$RUN_DIR/"
printf '0\n' > "$RUN_DIR/flow.txt"
printf '0\n' > "$RUN_DIR/trace.txt"
cd "$RUN_DIR"
unset AS_SEND_LAT
export AS_NVLS_ENABLE=0
export SIMAI_DUMP_DETAILED_FLOWS=1
timeout 180 "$LAB_DIR/SimAI/bin/SimAI_simulator" -t 1 -w allreduce.txt -n topology.txt -c SimAI.conf > run.log 2>&1
test -s ncclFlowModel_EndToEnd.csv
test -s ncclFlowModel_detailed_flows.csv
test -s fct.txt
printf 'Results: %s\n' "$RUN_DIR"
python3 "$LAB_DIR/verify-results.py" "$RUN_DIR"
ln -sfn "$RUN_DIR" "$LAB_DIR/results/latest"
