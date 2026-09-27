#!/usr/bin/env bash
set -euo pipefail
LAB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PATH=/usr/bin:/bin:$PATH
SIMAI_DIR="$LAB_DIR/SimAI"
BACKEND_DIR="$SIMAI_DIR/astra-sim-alibabacloud/extern/network_backend/ns3-interface"
mkdir -p "$BACKEND_DIR" "$LAB_DIR/logs" "$SIMAI_DIR/bin"
cp -a "$SIMAI_DIR/ns-3-alibabacloud/." "$BACKEND_DIR/"
SIM_DIR="$BACKEND_DIR/simulation"
cp "$SIMAI_DIR/astra-sim-alibabacloud/astra-sim/network_frontend/ns3/AstraSimNetwork.cc" "$SIM_DIR/scratch/"
cp "$SIMAI_DIR/astra-sim-alibabacloud/astra-sim/network_frontend/ns3/"*.h "$SIM_DIR/scratch/"
cp -a "$SIMAI_DIR/astra-sim-alibabacloud/astra-sim" "$SIM_DIR/src/applications/"
mkdir -p "$SIM_DIR/src/applications/SimCCL/mock"
cp -a "$SIMAI_DIR/SimCCL/src/mock/v2.30/." "$SIM_DIR/src/applications/SimCCL/mock/"
cd "$SIM_DIR"
./ns3 configure -d debug --enable-mtp --enable-modules=applications,csma,point-to-point,internet,mtp --disable-examples --disable-tests
./ns3 build AstraSimNetwork -j "${BUILD_JOBS:-2}"
ln -sfn "$SIM_DIR/build/scratch/ns3.36.1-AstraSimNetwork-debug" "$SIMAI_DIR/bin/SimAI_simulator"
test -x "$SIMAI_DIR/bin/SimAI_simulator"
