#!/usr/bin/env python3
"""Bangun envelope gelombang narasi dari file audio asli.

Untuk setiap `assets/media/*/narasi.m4a`, script ini mendekode audio dengan
ffmpeg, menghitung energi lima pita frekuensi per 50 ms, lalu menyimpannya
sebagai `narasi.wave.json` di folder yang sama. Kartu Narasi di UI04
memakai file ini agar bar gelombang mengikuti audio yang sedang diputar.

Data ini turunan langsung dari audio, bukan konten baru. Jalankan ulang
setiap kali file narasi berubah:

    python3 tool/build_narration_waves.py

Kebutuhan: ffmpeg di PATH dan numpy.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import numpy as np

SAMPLE_RATE = 16000
FPS = 20
WINDOW = SAMPLE_RATE // FPS
# Lima pita, dari nada dasar suara sampai desis konsonan.
BANDS_HZ = [(90, 250), (250, 600), (600, 1500), (1500, 3500), (3500, 7500)]


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(
        [
            "ffmpeg", "-v", "error", "-i", str(path),
            "-ac", "1", "-ar", str(SAMPLE_RATE), "-f", "s16le", "-",
        ],
        check=True,
        capture_output=True,
    ).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0


def envelope(samples: np.ndarray) -> list[list[int]]:
    frames = len(samples) // WINDOW
    if frames == 0:
        return []
    window = np.hanning(WINDOW)
    freqs = np.fft.rfftfreq(WINDOW, 1 / SAMPLE_RATE)
    chunks = samples[: frames * WINDOW].reshape(frames, WINDOW) * window
    power = np.abs(np.fft.rfft(chunks, axis=1)) ** 2
    levels = np.stack(
        [
            power[:, (freqs >= lo) & (freqs < hi)].mean(axis=1)
            for lo, hi in BANDS_HZ
        ],
        axis=1,
    )
    db = 10 * np.log10(levels + 1e-10)
    # Normalisasi per pita: senyap -> 0, bagian paling keras -> 1.
    low = np.percentile(db, 10, axis=0)
    high = np.percentile(db, 98, axis=0)
    norm = np.clip((db - low) / np.maximum(high - low, 1e-6), 0, 1)
    return np.round(norm * 100).astype(int).tolist()


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    sources = sorted((root / "assets" / "media").glob("*/narasi.m4a"))
    if not sources:
        print("Tidak ada narasi.m4a ditemukan.", file=sys.stderr)
        return 1
    for source in sources:
        frames = envelope(decode(source))
        target = source.with_name("narasi.wave.json")
        target.write_text(
            json.dumps(
                {
                    "source": source.name,
                    "fps": FPS,
                    "bands": len(BANDS_HZ),
                    "frames": frames,
                },
                separators=(",", ":"),
            )
            + "\n"
        )
        print(f"{target.relative_to(root)}: {len(frames)} frame")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
