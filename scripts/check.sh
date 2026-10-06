#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/qa
python3 tools/validate_content.py
python3 -I tools/sim/run_sim.py --self-test
python3 scripts/check_architecture.py
python3 -m unittest discover -s tests -p 'test_*.py'
python3 - <<'PY'
from pathlib import Path
import subprocess, sys
commands = [
 ['godot', '--headless', '--path', '.', '--import', '--quit'],
 ['godot', '--headless', '--path', '.', '--script', 'res://tests/run_vectors.gd'],
 ['godot', '--headless', '--path', '.', '--script', 'res://tests/run_session.gd'],
 ['godot', '--headless', '--path', '.', '--script', 'res://tests/run_ads.gd'],
 ['godot', '--headless', '--path', '.', '--quit-after', '3', '--', '--save=user://tests-startup/save.json'],
]
for i, command in enumerate(commands):
 try:
  result = subprocess.run(command, capture_output=True, text=True, timeout=120)
 except subprocess.TimeoutExpired:
  sys.exit('Godot timeout: ' + ' '.join(command))
 log = result.stdout + result.stderr
 Path(f'build/qa/godot-{i}.log').write_text(log)
 errors = [line for line in log.splitlines() if 'SCRIPT ERROR:' in line or line.startswith('ERROR:')]
 if result.returncode or errors:
  print(log)
  sys.exit(1)
 for line in log.splitlines():
  if line.startswith(('VECTORS', 'SESSION', 'AD POLICY')): print(line)
print('Godot import, vectors, session and startup PASS')
PY
