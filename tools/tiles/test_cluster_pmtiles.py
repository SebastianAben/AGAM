"""Clustering regressions with synthetic fixture and the existing real archive."""
import json
from pathlib import Path
import struct
import tempfile
import unittest

from cluster_pmtiles import cluster_archive
from test_tile_pipeline import synthetic_archive
from tile_pipeline import directory, decompress, validate_pmtiles, load_boundary


def contents(path):
    data = path.read_bytes()
    ro, rl, mo, ml, lo, _, to, *_ = struct.unpack_from('<11Q', data, 8)
    tiles = {}
    def visit(offset, length):
        for tile_id, run, relative, size in directory(decompress(data[offset:offset+length], data[97])):
            if run == 0:
                visit(lo + relative, size)
            else:
                payload = decompress(data[to+relative:to+relative+size], data[98])
                for current in range(tile_id, tile_id + run):
                    tiles[current] = payload
    visit(ro, rl)
    return tiles, json.loads(decompress(data[mo:mo+ml], data[97]))


class ClusterTests(unittest.TestCase):
    def test_shared_synthetic_payload_preserved_and_rerun_identical(self):
        bounds = [0, 0, 0.01, 0.01]  # SINTETIS, bukan kampus.
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'synthetic.pmtiles'
            data = bytearray(synthetic_archive(bounds))
            data[96] = 0
            path.write_bytes(data)
            before = contents(path)
            cluster_archive(path)
            self.assertEqual(before, contents(path))
            self.assertEqual(path.read_bytes()[96], 1)
            self.assertEqual(validate_pmtiles(path, bounds)['tileContents'], 1)
            once = path.read_bytes()
            cluster_archive(path)
            self.assertEqual(path.read_bytes(), once)

    def test_real_archive_all_payloads_and_metadata_preserved(self):
        root = Path(__file__).resolve().parents[2]
        bounds, _ = load_boundary(root / 'tools/tiles/campus-boundary.json')
        source = root / 'assets/map/ganesha.pmtiles'
        before = contents(source)
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / source.name
            path.write_bytes(source.read_bytes())
            cluster_archive(path)
            self.assertEqual(before, contents(path))
            self.assertEqual(len(before[0]), 13)
            validate_pmtiles(path, bounds)
            self.assertEqual(path.read_bytes(), source.read_bytes())

    def test_truncated_archive_rejected_without_rewrite(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'bad.pmtiles'
            path.write_bytes(b'PMTiles')
            with self.assertRaises(ValueError):
                cluster_archive(path)
            self.assertEqual(path.read_bytes(), b'PMTiles')
