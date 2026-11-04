"""Fixture SINTETIS: bukan koordinat/data kampus dan tidak masuk aset produksi."""

import argparse
import io
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import tile_pipeline as pipeline


def vint(number):
    result = bytearray()
    while number > 127:
        result.append((number & 127) | 128)
        number >>= 7
    return bytes(result + bytes([number]))


def field(number, value):
    return vint(number * 8 + 2) + vint(len(value)) + value


def synthetic_archive(bounds, roads=True):
    # SINTETIS: dua feature geometris minimal, payload MVT ditulis independen.
    names = ['building', 'transportation'] if roads else ['building']
    # Triangle polygon and two-vertex line, in synthetic integer tile coordinates.
    features = {'building': b'\x18\x03' + field(4, b'\x09\x00\x00\x12\x14\x00\x13\x14\x0f'),
                'transportation': b'\x18\x02' + field(4, b'\x09\x00\x00\x0a\x14\x00')}
    tile = b''.join(field(3, field(1, name.encode()) + field(2, features[name]) + b'\x78\x02')
                    for name in names)
    metadata = json.dumps({'vector_layers': [{'id': name} for name in names],
                           'attribution': 'OpenMapTiles OpenStreetMap contributors'}).encode()
    tile_id = (4 ** 12 - 1) // 3
    last_tile_id = (4 ** 16 - 1) // 3
    directory = (b'\x02' + vint(tile_id) + vint(last_tile_id - tile_id) + b'\x01\x01' +
                 vint(len(tile)) * 2 + b'\x01\x01')
    header = bytearray(127)
    header[:8] = b'PMTiles\x03'
    struct.pack_into('<11Q', header, 8, 127, len(directory), 127 + len(directory),
                     len(metadata), 127 + len(directory) + len(metadata), 0,
                     127 + len(directory) + len(metadata), len(tile), 2, 2, 1)
    header[96:102] = bytes([1, 1, 1, 1, 12, 16])
    header[118] = 12
    struct.pack_into('<4i', header, 102, *(round(v * 1e7) for v in bounds))
    return bytes(header) + directory + metadata + tile


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='AGAM synthetic path with spaces ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bounds = [0.0, 0.0, 0.01, 0.01]  # SINTETIS, bukan Ganesha.

    def args(self, **overrides):
        values = dict(output=str(self.root / 'asset folder' / 'ganesha.pmtiles'),
                      boundary=str(self.root / 'boundary.json'), cache=str(self.root / 'cache'),
                      osm_pbf=str(self.root / 'synthetic input.osm.pbf'), osm_sha256=None,
                      source_url=None, water_polygons_url=None,
                      java='synthetic-java', force=False, bounds_only=False)
        values.update(overrides)
        return argparse.Namespace(**values)

    def archive(self, **kwargs):
        path = self.root / 'synthetic.pmtiles'
        path.write_bytes(synthetic_archive(self.bounds, **kwargs))
        return path

    def test_margin_has_independent_equatorial_reference(self):
        result = pipeline.expanded_bounds([[0, 0], [0.01, 0], [0.01, 0.01], [0, 0]])
        # 1 degree latitude ~=111195.08m: independently tabulated spherical arc.
        self.assertAlmostEqual(result[1], -0.00179865, places=7)
        self.assertAlmostEqual(result[3], 0.01179865, places=7)
        self.assertLess(result[0], 0)
        self.assertGreater(result[2], 0.01)

    def test_invalid_bounds(self):
        for ring in [[], [[0, 0]] * 4, [[0, 0], [1, 1], [2, 2]],
                     [[0, 0], [1, 90], [1, 0], [0, 0]],
                     [[0, 0], [1, 1], [2, 2], [0, 0]],
                     [[0, 0], [float('nan'), 1], [1, 1], [0, 0]]]:
            with self.subTest(ring=ring), self.assertRaises(ValueError):
                pipeline.expanded_bounds(ring)

    def test_unverified_boundary_blocks_before_download(self):
        path = self.root / 'boundary.json'
        path.write_text('{"status":"placeholder"}')
        with patch.object(pipeline, 'download') as download, self.assertRaisesRegex(ValueError, 'BLOCKED'):
            pipeline.build(self.args(osm_pbf=None))
        download.assert_not_called()

    def test_wrong_snapshot_checksum(self):
        snapshot = self.root / 'snapshot.json'
        snapshot.write_text('{}')
        config = self.root / 'boundary.json'
        config.write_text(json.dumps(dict(status='verified_osm_snapshot', snapshot=snapshot.name,
                                         sha256='0' * 64)))
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            pipeline.load_boundary(config)

    def test_cached_jar_checksum_failure(self):
        jar = self.root / 'planetiler.jar'
        jar.write_bytes(b'SINTETIS corrupted jar')
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            pipeline.download(pipeline.JAR_URL, jar, pipeline.JAR_SHA256)

    def test_failed_download_leaves_no_partial_cache(self):
        target = self.root / 'cache.pbf'
        with patch('urllib.request.urlopen', side_effect=OSError('synthetic network failure')):
            with self.assertRaises(OSError):
                pipeline.download('https://example.invalid/synthetic', target)
        self.assertFalse(target.exists())
        self.assertFalse(list(self.root.glob('*.part')))

    def test_truncated_download_is_rejected(self):
        response = io.BytesIO(b'short')
        response.headers = {'Content-Length': '100'}
        target = self.root / 'cache.pbf'
        with patch('urllib.request.urlopen', return_value=response), self.assertRaises(ValueError):
            pipeline.download('https://example.invalid/synthetic', target)
        self.assertFalse(target.exists())
        self.assertFalse(list(self.root.glob('*.part')))

    def test_complete_archive_and_all_layers(self):
        report = pipeline.validate_pmtiles(self.archive(), self.bounds)
        self.assertEqual(report['tileContents'], 1)
        self.assertEqual(report['featureCountsAcrossUniqueTiles'], {'building': 1, 'transportation': 1})

    def test_empty_truncated_and_missing_road_archives(self):
        for data in [b'', b'PMTiles\x03', synthetic_archive(self.bounds, roads=False),
                     synthetic_archive(self.bounds)[:-1]]:
            path = self.root / 'bad.pmtiles'
            path.write_bytes(data)
            with self.subTest(size=len(data)), self.assertRaises(ValueError):
                pipeline.validate_pmtiles(path, self.bounds)

    def test_wrong_bounds_and_zoom_rejected(self):
        path = self.archive()
        with self.assertRaisesRegex(ValueError, 'Bounds'):
            pipeline.validate_pmtiles(path, [1, 1, 2, 2])
        data = bytearray(path.read_bytes())
        data[101] = 14
        path.write_bytes(data)
        with self.assertRaisesRegex(ValueError, 'zoom'):
            pipeline.validate_pmtiles(path, self.bounds)

    def test_existing_output_or_manifest_prevents_network(self):
        args = self.args()
        output = Path(args.output)
        output.parent.mkdir()
        for target in [output, output.with_suffix('.manifest.json')]:
            target.write_bytes(b'preserve')
            with patch.object(pipeline, 'load_boundary') as boundary, self.assertRaises(FileExistsError):
                pipeline.build(args)
            boundary.assert_not_called()
            self.assertEqual(target.read_bytes(), b'preserve')
            target.unlink()

    def test_missing_input(self):
        with patch.object(pipeline, 'load_boundary', return_value=(self.bounds, {})):
            with self.assertRaises(FileNotFoundError):
                pipeline.build(self.args())

    def test_real_boundary_snapshot_covers_all_prd_pois(self):
        root = Path(__file__).resolve().parent
        bounds, provenance = pipeline.load_boundary(root / 'campus-boundary.json')
        self.assertEqual(provenance['osmId'], 177629384)
        pois = json.loads((root / '../../assets/data/pois.json').read_text(encoding='utf-8'))['pois']
        self.assertEqual(len(pois), 10)
        for poi in pois:
            with self.subTest(poi=poi['id']):
                self.assertTrue(bounds[0] <= poi['lng'] <= bounds[2])
                self.assertTrue(bounds[1] <= poi['lat'] <= bounds[3])

    def test_wrong_input_checksum_stops_before_generator(self):
        args = self.prepare_build()
        args.osm_sha256 = '0' * 64
        with patch.object(pipeline, 'load_boundary', return_value=(self.bounds, {})), \
                patch.object(pipeline.subprocess, 'run') as run, self.assertRaisesRegex(ValueError, 'SHA-256'):
            pipeline.build(args)
        run.assert_not_called()

    def prepare_build(self):
        args = self.args()
        pbf = Path(args.osm_pbf)
        pbf.write_bytes(struct.pack('>I', 9) + b'OSMHeader')
        return args

    def fake_java(self, command, **kwargs):
        if command[-1] == '-version':
            return subprocess.CompletedProcess(command, 0, '', 'java version "21.0.12"')
        output = Path(next(arg.removeprefix('--output=') for arg in command if arg.startswith('--output=')))
        output.write_bytes(synthetic_archive(self.bounds))
        return subprocess.CompletedProcess(command, 0)

    def test_build_with_spaces_manifest_and_forced_rerun(self):
        args = self.prepare_build()
        with patch.object(pipeline, 'load_boundary', return_value=(self.bounds, {'synthetic': True})), \
                patch.object(pipeline, 'download', return_value=self.root / 'synthetic jar.jar'), \
                patch.object(pipeline.subprocess, 'run', side_effect=self.fake_java):
            first = pipeline.build(args)
            args.force = True
            second = pipeline.build(args)
        self.assertEqual(first['output']['sha256'], second['output']['sha256'])
        manifest = json.loads(Path(args.output).with_suffix('.manifest.json').read_text(encoding='utf-8'))
        self.assertEqual(manifest['source']['sha256'], pipeline.digest(Path(args.osm_pbf)))
        self.assertFalse(list(Path(args.output).parent.glob('.ganesha-build-*')))

    def test_generator_failure_preserves_both_existing_outputs(self):
        args = self.prepare_build()
        args.force = True
        output = Path(args.output)
        output.parent.mkdir()
        manifest = output.with_suffix('.manifest.json')
        output.write_bytes(b'existing tile')
        manifest.write_bytes(b'existing manifest')

        def fail(command, **kwargs):
            if command[-1] == '-version':
                return self.fake_java(command, **kwargs)
            raise subprocess.CalledProcessError(2, command)

        with patch.object(pipeline, 'load_boundary', return_value=(self.bounds, {})), \
                patch.object(pipeline, 'download', return_value=self.root / 'synthetic.jar'), \
                patch.object(pipeline.subprocess, 'run', side_effect=fail):
            with self.assertRaises(subprocess.CalledProcessError):
                pipeline.build(args)
        self.assertEqual(output.read_bytes(), b'existing tile')
        self.assertEqual(manifest.read_bytes(), b'existing manifest')

    def test_invalid_generator_output_is_never_published(self):
        args = self.prepare_build()

        def invalid(command, **kwargs):
            result = self.fake_java(command, **kwargs)
            if command[-1] != '-version':
                output = Path(next(arg.removeprefix('--output=') for arg in command if arg.startswith('--output=')))
                output.write_bytes(b'SINTETIS invalid archive')
            return result

        with patch.object(pipeline, 'load_boundary', return_value=(self.bounds, {})), \
                patch.object(pipeline, 'download', return_value=self.root / 'synthetic.jar'), \
                patch.object(pipeline.subprocess, 'run', side_effect=invalid):
            with self.assertRaisesRegex(ValueError, 'PMTiles'):
                pipeline.build(args)
        self.assertFalse(Path(args.output).exists())
        self.assertFalse(Path(args.output).with_suffix('.manifest.json').exists())

    def test_publication_failure_rolls_back_pair(self):
        a, b, staged_a, staged_b = [self.root / name for name in ['a', 'b', 'stage-a', 'stage-b']]
        for path in [a, b, staged_a, staged_b]:
            path.write_text(path.name)
        real_link = pipeline.os.link

        def fail_second(source, destination):
            if destination == b:
                raise OSError('synthetic second publication failure')
            real_link(source, destination)

        with patch.object(pipeline.os, 'link', side_effect=fail_second), self.assertRaises(OSError):
            pipeline.publish([(staged_a, a), (staged_b, b)], True)
        self.assertEqual(a.read_text(), 'a')
        self.assertEqual(b.read_text(), 'b')
        self.assertFalse(list(self.root.glob('*.bak')))


if __name__ == '__main__':
    unittest.main()
