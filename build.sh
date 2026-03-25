#!/bin/bash
# build.sh — packages the Python server into a standalone binary.
# Run once (or after any changes to server.py or requirements.txt).
# Output: src/hub/spoke_server  (macOS/Linux) or src/hub/spoke_server.exe (Windows)

set -e

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
VENV="$REPO_ROOT/.venv"
SERVER="$REPO_ROOT/src/python/server.py"
OUT_DIR="$REPO_ROOT/src/hub"

echo "--- activating venv"
source "$VENV/bin/activate"

echo "--- installing pyinstaller"
pip install pyinstaller --quiet

echo "--- building spoke_server binary"
pyinstaller "$SERVER" \
  --onefile \
  --name spoke_server \
  --distpath "$OUT_DIR" \
  --workpath "$REPO_ROOT/.build/work" \
  --specpath "$REPO_ROOT/.build" \
  --clean \
  --noconfirm

echo "--- done: $OUT_DIR/spoke_server"
