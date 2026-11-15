// Menyalin assets/data/pois.json ke koleksi Firestore `pois` dan `facilities`
// (.agent/PRD.md §15.2). pois.json di branch dev adalah satu-satunya sumber;
// dokumen di Firestore yang tidak ada di JSON dihapus.
//
// Pemakaian: node seed_pois.mjs [--dry-run]
// Kredensial: GOOGLE_APPLICATION_CREDENTIALS (service account), atau
// FIRESTORE_EMULATOR_HOST untuk emulator. Lihat README.md.

import { readFile } from 'node:fs/promises';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const PROJECT_ID = process.env.GCLOUD_PROJECT ?? 'agam-9e704';
const DATASET = new URL('../../assets/data/pois.json', import.meta.url);
const COLLECTIONS = ['pois', 'facilities'];

const dryRun = process.argv.includes('--dry-run');

/** Pemeriksaan bentuk minimum; validasi isi dijalankan test Flutter dan aplikasi. */
function itemsOf(dataset, collection) {
  const items = dataset[collection] ?? [];
  if (!Array.isArray(items)) {
    throw new Error(`"${collection}" harus berupa daftar`);
  }
  const ids = new Set();
  for (const item of items) {
    if (typeof item?.id !== 'string' || item.id.length === 0) {
      throw new Error(`Item "${collection}" tanpa id string: ${JSON.stringify(item)}`);
    }
    if (item.id.includes('/')) {
      throw new Error(`id "${item.id}" tidak boleh mengandung "/"`);
    }
    if (ids.has(item.id)) {
      throw new Error(`id ganda di "${collection}": ${item.id}`);
    }
    ids.add(item.id);
  }
  return items;
}

const dataset = JSON.parse(await readFile(DATASET, 'utf8'));
const plan = Object.fromEntries(COLLECTIONS.map((c) => [c, itemsOf(dataset, c)]));

const db = getFirestore(initializeApp({ projectId: PROJECT_ID }));
const target = process.env.FIRESTORE_EMULATOR_HOST
  ? `emulator ${process.env.FIRESTORE_EMULATOR_HOST}`
  : `project ${PROJECT_ID}`;
console.log(`${dryRun ? '[dry-run] ' : ''}Seed ke ${target}`);

for (const collection of COLLECTIONS) {
  const items = plan[collection];
  const wanted = new Set(items.map((item) => item.id));
  const existing = await db.collection(collection).listDocuments();
  const stale = existing.filter((ref) => !wanted.has(ref.id));

  console.log(
    `${collection}: tulis ${items.length}, hapus ${stale.length}` +
      (stale.length ? ` (${stale.map((ref) => ref.id).join(', ')})` : ''),
  );
  if (dryRun) continue;

  const writer = db.bulkWriter();
  for (const item of items) writer.set(db.collection(collection).doc(item.id), item);
  for (const ref of stale) writer.delete(ref);
  await writer.close();
}

console.log(dryRun ? 'Selesai tanpa menulis.' : 'Selesai.');
