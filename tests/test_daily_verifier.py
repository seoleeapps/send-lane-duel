import importlib.util
import json
from pathlib import Path
import unittest
from copy import deepcopy

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('verify_daily', ROOT / 'tools/verify_daily.py')
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class ReplayTests(unittest.TestCase):
    def test_all_run_vectors(self):
        for vector in json.loads((ROOT / 'tests/fixtures/vectors.json').read_text())['runs']:
            with self.subTest(seed=vector['seed']):
                run = verifier.replay(vector)
                self.assertEqual(run.score(), vector['expect']['score'])
                self.assertEqual(run.status, vector['expect']['status'])

    def record(self):
        ref = verifier.reference
        seed = 20261006
        preset = list(ref.PRESETS)[seed % len(ref.PRESETS)]
        steps = []
        run = ref.play(ref.make_bot('균형'), seed, preset=preset, record=steps)
        return {'seed': seed, 'preset': preset, 'steps': steps, 'rules_version': ref.RULES['schema'],
                'score': run.score(), 'rounds_used': run.rounds_used, 'gold': run.player.gold}

    def test_daily_identity_score_and_bad_slot(self):
        record = self.record()
        self.assertTrue(verifier.verify(record, '2026-10-06')['valid'])
        for key, value in [('score', 99999), ('seed', 20261007), ('preset', 'preset_a'), ('rules_version', 'old')]:
            forged = deepcopy(record)
            forged[key] = value
            self.assertFalse(verifier.verify(forged, '2026-10-06')['valid'])
        forged = deepcopy(record)
        next(step for step in forged['steps'] if step['step'] == 'round')['action']['builds'] = [['place', -1, 'fam_pierce']]
        self.assertFalse(verifier.verify(forged, '2026-10-06')['valid'])

    def test_malformed_inputs_are_rejected(self):
        record = self.record()
        for key in ('seed', 'score', 'rounds_used', 'gold'):
            forged = deepcopy(record)
            forged[key] = float(forged[key])
            self.assertFalse(verifier.verify(forged, '2026-10-06')['valid'])
        self.assertFalse(verifier.verify([], '2026-10-06')['valid'])
        self.assertFalse(verifier.verify(record, '2026-1-06')['valid'])
        self.assertFalse(verifier.verify(record, '2026-02-31')['valid'])


if __name__ == '__main__': unittest.main()
