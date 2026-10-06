import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-three-purses', firestore: {
    host: '127.0.0.1', port: 8088, rules: readFileSync('firestore.rules', 'utf8')
  }});
});
beforeEach(async () => env.clearFirestore());
after(async () => env?.cleanup());

test('private backups reject unauthenticated and other users', async () => {
  const owner = env.authenticatedContext('alice').firestore();
  const stranger = env.authenticatedContext('bob').firestore();
  const anonymous = env.unauthenticatedContext().firestore();
  const payload = {profile: {medals: 3}, nickname: 'Alice', schemaVersion: 1, updatedAt: serverTimestamp()};
  await assertSucceeds(setDoc(doc(owner, 'users/alice'), payload));
  await assertSucceeds(getDoc(doc(owner, 'users/alice')));
  await assertFails(getDoc(doc(stranger, 'users/alice')));
  await assertFails(setDoc(doc(anonymous, 'users/alice'), payload));
  await assertFails(deleteDoc(doc(stranger, 'users/alice')));
  await assertSucceeds(deleteDoc(doc(owner, 'users/alice')));
});

test('scores are create-once and top aggregates are server-owned', async () => {
  const owner = env.authenticatedContext('alice').firestore();
  const stranger = env.authenticatedContext('bob').firestore();
  const date = new Date().toISOString().slice(0, 10).replaceAll('-', '');
  const seed = Number(date);
  const payload = {score: 200, nickname: 'Alice', rounds_used: 3, gold: 9, seed,
    preset: ['preset_a', 'preset_b', 'preset_c', 'preset_d'][seed % 4], steps: [],
    rules_version: 'send-lane-duel.rules.v1', submittedAt: serverTimestamp()};
  const path = `daily/${date}/scores/alice`;
  await assertSucceeds(setDoc(doc(owner, path), payload));
  await assertFails(setDoc(doc(owner, path), {...payload, score: 500}));
  await assertFails(deleteDoc(doc(owner, path)));
  await assertFails(setDoc(doc(stranger, `daily/${date}/scores/alice`), payload));
  await assertFails(setDoc(doc(owner, `daily/${date}/top/current`), {records: []}));
  await assertFails(setDoc(doc(stranger, `daily/${date}/scores/bob`), {...payload, score: 99999}));
  await assertFails(setDoc(doc(stranger, 'daily/20000101/scores/bob'), payload));
  await assertFails(setDoc(doc(stranger, `daily/${date}/scores/bob`), {...payload, seed: seed + 1}));
  await assertFails(setDoc(doc(stranger, `daily/${date}/scores/bob`), {...payload, preset: ['preset_a', 'preset_b', 'preset_c', 'preset_d'][(seed + 1) % 4]}));
});
