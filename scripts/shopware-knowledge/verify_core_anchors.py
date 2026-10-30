#!/usr/bin/env python3
"""Verify pinned GitHub source locators using an exact local core object."""

import argparse
import json
import re
import subprocess
from pathlib import Path
from urllib.parse import unquote

parser = argparse.ArgumentParser()
parser.add_argument('--core', required=True, type=Path)
parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
args = parser.parse_args()
skill = args.root / 'plugins/shopware-knowledge/skills/shopware-development'
texts = [p.read_text() for p in skill.rglob('*.md')]
texts.append((args.root / 'plugins/shopware-knowledge/knowledge-index.json').read_text())
anchors = set(re.findall(r'https://github\.com/shopware/shopware/(?:blob|tree)/([^/\s]+)/([^\s`"<>\)\]]+)', '\n'.join(texts)))
checked, missing, unavailable = [], [], []
for ref, raw_path in sorted(anchors):
    path = unquote(raw_path.split('#', 1)[0].rstrip('.,'))
    probe = subprocess.run(['git', '-C', str(args.core), 'rev-parse', '--verify', ref + '^{commit}'], capture_output=True)
    if probe.returncode:
        unavailable.append(ref + ':' + path)
        continue
    result = subprocess.run(['git', '-C', str(args.core), 'cat-file', '-e', ref + ':' + path], capture_output=True)
    (missing if result.returncode else checked).append(ref + ':' + path)
print(json.dumps({'checked': len(checked), 'missing': missing, 'unavailable_refs': unavailable}, indent=2))
raise SystemExit(1 if missing or unavailable else 0)
