// Test security rules (firestore.rules) terhadap emulator Firestore.
// Jalankan: npm run test:rules (lihat README.md).

import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-agam',
    firestore: {
      rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8'),
    },
  });
});

after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const alice = () => env.authenticatedContext('alice').firestore();
const guest = () => env.unauthenticatedContext().firestore();

/** Menulis dokumen tanpa melewati rules (seperti Admin SDK). */
async function seedDoc(path, data) {
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));
}

describe('pois dan facilities', () => {
  test('dapat dibaca tanpa login', async () => {
    await seedDoc('pois/P01', { id: 'P01' });
    await assertSucceeds(getDoc(doc(guest(), 'pois/P01')));
    await assertSucceeds(getDoc(doc(guest(), 'facilities/F01')));
  });

  test('tidak dapat ditulis dari aplikasi', async () => {
    await assertFails(setDoc(doc(alice(), 'pois/P01'), { id: 'P01' }));
    await assertFails(setDoc(doc(alice(), 'facilities/F01'), { id: 'F01' }));
  });
});

describe('users', () => {
  const profile = () => ({ role: 'pengunjung', createdAt: serverTimestamp() });

  test('pemilik dapat membuat, membaca, mengubah role, dan menghapus', async () => {
    const ref = doc(alice(), 'users/alice');
    await assertSucceeds(setDoc(ref, profile()));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(updateDoc(ref, { role: 'mahasiswaItb' }));
    await assertSucceeds(deleteDoc(ref));
  });

  test('pengguna lain dan tamu tidak dapat mengakses', async () => {
    await seedDoc('users/alice', { role: 'pengunjung', createdAt: new Date() });
    const bob = env.authenticatedContext('bob').firestore();
    await assertFails(getDoc(doc(bob, 'users/alice')));
    await assertFails(setDoc(doc(bob, 'users/alice'), profile()));
    await assertFails(getDoc(doc(guest(), 'users/alice')));
  });

  test('menolak role tidak dikenal, field tambahan, dan perubahan createdAt', async () => {
    const ref = doc(alice(), 'users/alice');
    await assertFails(setDoc(ref, { role: 'admin', createdAt: serverTimestamp() }));
    await assertFails(setDoc(ref, { ...profile(), email: 'a@b.c' }));
    await assertSucceeds(setDoc(ref, profile()));
    await assertFails(updateDoc(ref, { createdAt: new Date(0) }));
  });
});

describe('activity_logs', () => {
  const logs = () => collection(alice(), 'activity_logs');
  const at = () => serverTimestamp();

  const valid = {
    signUp: () => ({ uid: 'alice', type: 'signUp', at: at(), role: 'mahasiswaItb' }),
    login: () => ({ uid: 'alice', type: 'login', at: at() }),
    logout: () => ({ uid: 'alice', type: 'logout', at: at() }),
    appOpen: () => ({
      uid: 'alice',
      type: 'appOpen',
      at: at(),
      appVersion: '1.0.0',
      androidVersion: '14',
      deviceModel: 'Pixel 8',
    }),
    modeStart: () => ({ uid: 'alice', type: 'modeStart', date: '2026-11-15', mode: 'explore' }),
    modeEnd: () => ({
      uid: 'alice',
      type: 'modeEnd',
      date: '2026-11-15',
      mode: 'trail',
      durationMin: 25,
    }),
    featureUsed: () => ({ uid: 'alice', type: 'featureUsed', at: at(), feature: 'search' }),
    trailCompleted: () => ({ uid: 'alice', type: 'trailCompleted', date: '2026-11-15' }),
  };

  for (const [type, make] of Object.entries(valid)) {
    test(`menerima event ${type} sesuai §15.5`, async () => {
      await assertSucceeds(addDoc(logs(), make()));
    });
  }

  test('menolak tamu dan uid milik orang lain', async () => {
    await assertFails(addDoc(collection(guest(), 'activity_logs'), valid.login()));
    await assertFails(addDoc(logs(), { ...valid.login(), uid: 'bob' }));
  });

  test('menolak event di luar daftar', async () => {
    await assertFails(addDoc(logs(), { uid: 'alice', type: 'poiVisited', at: at() }));
  });

  test('menolak field terlarang: posisi, POI, kata kunci, alasan berakhir', async () => {
    await assertFails(addDoc(logs(), { ...valid.login(), lat: -6.89, lng: 107.61 }));
    await assertFails(addDoc(logs(), { ...valid.featureUsed(), poiId: 'P01' }));
    await assertFails(addDoc(logs(), { ...valid.featureUsed(), query: 'labtek' }));
    await assertFails(addDoc(logs(), { ...valid.modeEnd(), reason: 'autoEnd' }));
  });

  test('event mode dan trail hanya bertanggal, tanpa jam', async () => {
    await assertFails(addDoc(logs(), { ...valid.modeStart(), at: at() }));
    await assertFails(addDoc(logs(), { ...valid.modeStart(), date: '2026-11-15T08:00' }));
    await assertFails(addDoc(logs(), { ...valid.trailCompleted(), at: at() }));
  });

  test('durasi dibulatkan ke 5 menit dan nilai enum dibatasi', async () => {
    await assertFails(addDoc(logs(), { ...valid.modeEnd(), durationMin: 7 }));
    await assertFails(addDoc(logs(), { ...valid.modeStart(), mode: 'drive' }));
    await assertFails(addDoc(logs(), { ...valid.featureUsed(), feature: 'map' }));
  });

  test('pemilik dapat membaca dan menghapus, tidak dapat mengubah', async () => {
    const ref = await addDoc(logs(), valid.login());
    await assertSucceeds(getDoc(ref));
    await assertFails(updateDoc(ref, { type: 'logout' }));
    await assertSucceeds(deleteDoc(ref));
  });

  test('pengguna lain tidak dapat membaca log', async () => {
    await seedDoc('activity_logs/x', { uid: 'alice', type: 'login', at: new Date() });
    const bob = env.authenticatedContext('bob').firestore();
    await assertFails(getDoc(doc(bob, 'activity_logs/x')));
    await assertFails(deleteDoc(doc(bob, 'activity_logs/x')));
  });
});

describe('koleksi lain', () => {
  test('ditolak', async () => {
    await assertFails(setDoc(doc(alice(), 'other/x'), { a: 1 }));
    await assertFails(getDoc(doc(guest(), 'other/x')));
  });
});
