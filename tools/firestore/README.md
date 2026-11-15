# Firestore AGAM — seed konten dan test rules

Project Firebase: `agam-9e704`. Aturan sinkronisasi: [.agent/PRD.md §15.2](../../.agent/PRD.md#152-alur-sinkronisasi).

## Aturan

- `assets/data/pois.json` adalah satu-satunya sumber konten POI dan fasilitas. Ubah file itu lewat PR ke `dev`.
- **Jangan mengedit `pois` atau `facilities` di Firebase Console.** Perubahan di Console tertimpa saat seed berikutnya dan tidak tercatat di repository.
- Firestore mengikuti `dev` sampai rilis v1.0. Pada PB19, workflow diganti agar mengikuti `main`.

## Seed otomatis

Workflow [`seed-firestore.yml`](../../.github/workflows/seed-firestore.yml) berjalan setiap push ke `dev` yang mengubah `assets/data/pois.json`. Workflow ini menjalankan test dataset (`flutter test test/logic/data`) lebih dulu, lalu seed hanya jika test lulus. Workflow juga dapat dijalankan manual dari tab Actions (`workflow_dispatch`, hanya pada `dev`).

Workflow memerlukan secret repository `FIREBASE_SERVICE_ACCOUNT`, berisi key JSON service account dengan role **Cloud Datastore User** pada `agam-9e704`. Key tidak boleh di-commit.

## Seed manual

Dari checkout `dev` yang terbaru, Node 22+:

```sh
cd tools/firestore
npm ci
export GOOGLE_APPLICATION_CREDENTIALS=/path/di/luar/repo/service-account.json
npm run seed -- --dry-run   # tampilkan jumlah dokumen yang akan ditulis/dihapus
npm run seed
```

Contoh output:

```text
Seed ke project agam-9e704
pois: tulis 10, hapus 0
facilities: tulis 0, hapus 0
Selesai.
```

Seed menulis satu dokumen per item dengan ID dokumen sama dengan `id`, lalu menghapus dokumen yang tidak ada di JSON. Field tingkat atas JSON selain `pois` dan `facilities` (`schemaVersion`, `note`, dan sebagainya) tidak diunggah.

Periksa hasil di Firebase Console → Firestore: jumlah dokumen `pois` sama dengan jumlah POI di JSON.

## Security rules

Rules ada di [`firestore.rules`](../../firestore.rules) dan mengikuti PRD §15.4–§15.5. Ubah rules lewat PR, lalu deploy dari root repository:

```sh
firebase deploy --only firestore:rules
```

Test rules berjalan di emulator Firestore lokal (perlu Java 21+ dan Firebase CLI):

```sh
cd tools/firestore
npm ci
npm run test:rules
```

Emulator memakai project `demo-agam`, sehingga test tidak pernah menyentuh project asli.
