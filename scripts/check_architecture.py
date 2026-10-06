#!/usr/bin/env python3
"""Reject runtime/platform dependencies in the integer rules module."""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
forbidden = r'\b(Node\w*|SceneTree|FileAccess|DirAccess|Time|OS|HTTP\w*|DisplayServer|RenderingServer|Input|float|rand\w*)\b|\b(preload|load)\s*\('
errors = []
for path in (root / 'core').glob('*.gd'):
    for number, line in enumerate(path.read_text().splitlines(), 1):
        code = line.split('#', 1)[0]
        if re.search(forbidden, code):
            errors.append(f'{path.relative_to(root)}:{number}: runtime dependency')
if errors:
    raise SystemExit('\n'.join(errors))
print('Architecture PASS: integer domain has no scene, IO, clock or platform dependencies')
