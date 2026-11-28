"""Deterministic local clustering for the small bundled AGAM PMTiles v3 archive.

Payloads and metadata are preserved, not regenerated. The flattened root must
fit in the first 16 KiB; larger archives fail explicitly instead of truncating.
Input must pass tile_pipeline.validate_pmtiles before this transformation.
"""
import struct
from pathlib import Path


def _varint(value):
    result = bytearray()
    while value > 127:
        result.append((value & 127) | 128)
        value >>= 7
    result.append(value)
    return bytes(result)


def cluster_archive(path: Path):
    from tile_pipeline import directory, decompress

    data = path.read_bytes()
    header = bytearray(data[:127])
    if len(header) != 127 or header[:8] != b'PMTiles\x03':
        raise ValueError('Clustering membutuhkan PMTiles v3 tervalidasi.')
    root_off, root_len, meta_off, meta_len, leaf_off, _, tile_off, *_ = struct.unpack_from('<11Q', header, 8)
    entries = []
    visited = set()

    def visit(offset, length, depth=0):
        if depth > 3 or (offset, length) in visited:
            raise ValueError('Directory berulang atau terlalu dalam.')
        visited.add((offset, length))
        for tile_id, run, relative, size in directory(decompress(data[offset:offset + length], header[97])):
            if run == 0:
                visit(leaf_off + relative, size, depth + 1)
            else:
                entries.append((tile_id, run, relative, size))

    visit(root_off, root_len)
    entries.sort()
    payload = bytearray()
    relocated = {}
    new_entries = []
    for tile_id, run, offset, length in entries:
        key = (offset, length)
        if key not in relocated:
            relocated[key] = len(payload)
            payload.extend(data[tile_off + offset:tile_off + offset + length])
        new_entries.append((tile_id, run, relocated[key], length))

    root = bytearray(_varint(len(new_entries)))
    previous_id = 0
    for tile_id, _, _, _ in new_entries:
        root.extend(_varint(tile_id - previous_id))
        previous_id = tile_id
    for _, run, _, _ in new_entries:
        root.extend(_varint(run))
    for _, _, _, length in new_entries:
        root.extend(_varint(length))
    previous_end = -1
    for _, _, offset, length in new_entries:
        root.extend(_varint(0 if offset == previous_end else offset + 1))
        previous_end = offset + length
    if 127 + len(root) > 16384:
        raise ValueError('Arsip melebihi batas root clustering AGAM (16 KiB).')
    metadata = decompress(data[meta_off:meta_off + meta_len], header[97])
    metadata_offset = 127 + len(root)
    payload_offset = metadata_offset + len(metadata)
    struct.pack_into('<11Q', header, 8, 127, len(root), metadata_offset,
                     len(metadata), payload_offset, 0, payload_offset,
                     len(payload), sum(e[1] for e in new_entries),
                     len(new_entries), len(relocated))
    header[96] = 1  # clustered: payload now follows ascending tile IDs.
    header[97] = 1  # root + metadata uncompressed, deterministic across platforms.
    path.write_bytes(bytes(header) + root + metadata + payload)
