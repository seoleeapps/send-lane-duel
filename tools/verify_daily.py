#!/usr/bin/env python3
"""Replay exported daily records locally; writes an audit, never mutates cloud data."""
from __future__ import annotations
import argparse
import importlib.util
import json
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('duel_reference', ROOT / 'tools/sim/run_sim.py')
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)


def replay(record: dict):
    steps = record['steps']
    if not isinstance(steps, list) or len(steps) > 35:
        raise ValueError('action count')
    run = reference.Run(record['seed'], record['preset'], record.get('ascension', 0))
    for step in steps:
        if step['step'] in ('route', 'draft'):
            index = step['index']
            if type(index) is not int or index < 0:
                raise ValueError('choice index')
            if step['step'] == 'route':
                if index >= len(run.route_options()): raise ValueError('route range')
                run.choose_route(index)
            else:
                if index >= len(run.draft_options()): raise ValueError('draft range')
                run.choose_draft(index)
        elif step['step'] == 'round':
            action = step['action']
            if not isinstance(action, dict): raise ValueError('action type')
            workers = action.get('workers', 0)
            if type(workers) is not int or workers < 0: raise ValueError('workers')
            for build in action.get('builds', []):
                if not isinstance(build, list) or len(build) not in (2, 3): raise ValueError('build shape')
                if type(build[1]) is not int or not 0 <= build[1] < len(run.player.board): raise ValueError('slot range')
                if build[0] == 'upgrade' and len(build) != 2: raise ValueError('upgrade shape')
                if build[0] in ('place', 'replace') and len(build) != 3: raise ValueError('build shape')
            run.apply_action(action)
        else:
            raise ValueError('unknown step')
    if run.status not in ('won', 'lost'): raise ValueError('unfinished run')
    return run


def verify(record: dict, date: str) -> dict:
    try:
        if not isinstance(record, dict): raise ValueError('record type')
        parsed_date = datetime.strptime(date, '%Y-%m-%d')
        if parsed_date.strftime('%Y-%m-%d') != date: raise ValueError('date format')
        seed = int(date.replace('-', ''))
        if any(type(record[key]) is not int for key in ('seed', 'score', 'rounds_used', 'gold')):
            raise ValueError('result integer types')
        if record['seed'] != seed or record['preset'] != list(reference.PRESETS)[seed % len(reference.PRESETS)]:
            raise ValueError('daily identity')
        if record.get('rules_version') != reference.RULES['schema'] or record.get('ascension', 0) != 0:
            raise ValueError('rules or ascension')
        run = replay(record)
        actual = {'score': run.score(), 'rounds_used': run.rounds_used, 'gold': run.player.gold}
        if any(record[key] != value for key, value in actual.items()): raise ValueError('claimed result mismatch')
        return {'valid': True, 'actual': actual}
    except (KeyError, IndexError, TypeError, ValueError, reference.IllegalAction) as error:
        return {'valid': False, 'reason': str(error)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True, help='JSON list of top-100 records')
    parser.add_argument('--date', required=True, help='UTC YYYY-MM-DD')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    records = json.loads(args.input.read_text())
    if not isinstance(records, list) or len(records) > 100: parser.error('input must contain at most 100 records')
    audit = [{'uid': record.get('uid', '') if isinstance(record, dict) else '', **verify(record, args.date)} for record in records]
    args.output.write_text(json.dumps({'date': args.date, 'audit': audit}, indent=2) + '\n')
    print(f'Daily audit: valid={sum(item["valid"] for item in audit)} rejected={sum(not item["valid"] for item in audit)}; no cloud writes')


if __name__ == '__main__': main()
