"""Pipeline build-time OSM -> OpenMapTiles MVT/PMTiles; Python 3.11+, stdlib.

PMTiles v3: https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md
MVT: https://github.com/mapbox/vector-tile-spec/blob/master/2.1/vector_tile.proto
"""

from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import json
import math
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
import urllib.request
import uuid

VERSION = '0.10.2'
JAR_SHA256 = 'f310bd0413e2e4512b27f4046d418664e8e1d3bf31603c2a70e23de06c167e4d'
JAR_URL = f'https://github.com/onthegomap/planetiler/releases/download/v{VERSION}/planetiler.jar'
OSM_URL = 'https://download.geofabrik.de/asia/indonesia/java-latest.osm.pbf'
ATTRIBUTION = '\u00a9 OpenMapTiles \u00a9 OpenStreetMap contributors'
MARGIN_M = 200
MIN_ZOOM, MAX_ZOOM = 12, 16


def digest(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def check_hash(path: Path, expected: str) -> str:
    if not re.fullmatch(r'[0-9a-fA-F]{64}', expected):
        raise ValueError('SHA-256 harus tepat 64 digit hex.')
    actual = digest(path)
    if actual != expected.lower():
        raise ValueError(f'SHA-256 tidak cocok: {path.name}')
    return actual


def download(url: str, destination: Path, expected: str | None = None) -> Path:
    """Unduhan gagal tidak boleh meninggalkan file cache yang dianggap lengkap."""
    if not url.startswith('https://'):
        raise ValueError('Sumber unduhan wajib HTTPS.')
    if destination.exists():
        if expected:
            check_hash(destination, expected)
        return destination
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + '.' + uuid.uuid4().hex + '.part')
    try:
        request = urllib.request.Request(url, headers={'User-Agent': 'AGAM-tile-build/1.0'})
        with urllib.request.urlopen(request, timeout=60) as response, temporary.open('xb') as out:
            length = response.headers.get('Content-Length')
            print(f'Mengunduh {destination.name}: {length or "unknown"} bytes.', flush=True)
            received = 0
            while block := response.read(1024 * 1024):
                out.write(block)
                received += len(block)
                if received % (64 * 1024 * 1024) == 0:
                    print(f'  {received}/{length or "unknown"} bytes', flush=True)
        if temporary.stat().st_size == 0:
            raise ValueError('Unduhan kosong.')
        if length and temporary.stat().st_size != int(length):
            raise ValueError('Unduhan terpotong.')
        if expected:
            check_hash(temporary, expected)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)
    return destination


def expanded_bounds(points: list[list[float]]) -> list[float]:
    """Envelope spherical dengan margin 200 m; urutan west,south,east,north."""
    if len(points) < 4 or points[0] != points[-1]:
        raise ValueError('Batas harus berupa ring tertutup, minimal tiga titik berbeda.')
    for point in points:
        if len(point) != 2 or any(isinstance(v, bool) or not isinstance(v, (int, float))
                                  or not math.isfinite(v) for v in point):
            raise ValueError('Koordinat batas invalid.')
        if not (-180 <= point[0] <= 180 and -85 <= point[1] <= 85):
            raise ValueError('Koordinat batas di luar rentang tile Web Mercator.')
    xs, ys = zip(*points)
    if min(xs) >= max(xs) or min(ys) >= max(ys) or max(xs) - min(xs) >= 180:
        raise ValueError('Bounds kosong atau melintasi antimeridian.')
    if len(set(map(tuple, points))) < 3:
        raise ValueError('Ring batas degenerat.')
    origin_x, origin_y = points[0]
    area_twice = sum((a[0] - origin_x) * (b[1] - origin_y) -
                     (b[0] - origin_x) * (a[1] - origin_y)
                     for a, b in zip(points, points[1:]))
    if abs(area_twice) < 1e-16:
        raise ValueError('Ring batas tidak memiliki luas.')
    lat_margin = math.degrees(MARGIN_M / 6371008.8)
    max_lat = max(abs(min(ys) - lat_margin), abs(max(ys) + lat_margin))
    lon_margin = lat_margin / math.cos(math.radians(max_lat))
    result = [min(xs) - lon_margin, min(ys) - lat_margin,
              max(xs) + lon_margin, max(ys) + lat_margin]
    if not (-180 <= result[0] < result[2] <= 180 and -85 <= result[1] < result[3] <= 85):
        raise ValueError('Bounds setelah margin invalid.')
    return [math.floor(v * 1e8) / 1e8 if i < 2 else math.ceil(v * 1e8) / 1e8
            for i, v in enumerate(result)]


def load_boundary(path: Path) -> tuple[list[float], dict]:
    config = json.loads(path.read_text(encoding='utf-8'))
    if config.get('status') != 'verified_osm_snapshot':
        raise ValueError('BLOCKED: batas belum diverifikasi; aset produksi tidak dibuat.')
    snapshot = path.parent / config['snapshot']
    snapshot_hash = check_hash(snapshot, config['sha256'])
    data = json.loads(snapshot.read_text(encoding='utf-8'))
    ways = [e for e in data['elements'] if e['type'] == 'way' and e['id'] == config['osmId']]
    if len(ways) != 1:
        raise ValueError('Objek batas OSM tidak unik atau tidak ditemukan.')
    way = ways[0]
    if way.get('tags', {}).get('amenity') != 'university' or way['tags'].get('name') != 'Institut Teknologi Bandung':
        raise ValueError('Objek batas bukan kampus ITB yang diverifikasi.')
    nodes = {e['id']: [e['lon'], e['lat']] for e in data['elements'] if e['type'] == 'node'}
    points = [nodes[node] for node in way['nodes']]
    bounds = expanded_bounds(points)
    return bounds, {**config, 'sha256': snapshot_hash, 'osmVersion': way['version'],
                    'osmTimestamp': way['timestamp'], 'marginM': MARGIN_M,
                    'method': 'OSM polygon envelope; spherical R=6371008.8 m; '
                              'latitude margin 200/R, longitude margin at maximum absolute '
                              'expanded latitude; outward rounding to 8 decimal places'}


def varint(data: bytes, pos: int) -> tuple[int, int]:
    value = 0
    for shift in range(0, 70, 7):
        if pos >= len(data):
            raise ValueError('Varint terpotong.')
        byte = data[pos]
        pos += 1
        value |= (byte & 127) << shift
        if byte < 128:
            return value, pos
    raise ValueError('Varint terlalu panjang.')


def protobuf(data: bytes):
    pos = 0
    while pos < len(data):
        key, pos = varint(data, pos)
        field, wire = key >> 3, key & 7
        if not field:
            raise ValueError('Nomor field protobuf nol.')
        if wire == 0:
            value, pos = varint(data, pos)
        elif wire in (1, 2, 5):
            if wire == 2:
                length, pos = varint(data, pos)
            else:
                length = 8 if wire == 1 else 4
            if pos + length > len(data):
                raise ValueError('Protobuf terpotong.')
            value = data[pos:pos + length]
            pos += length
        else:
            raise ValueError('Wire type protobuf tidak didukung.')
        yield field, wire, value


def directory(data: bytes) -> list[tuple[int, int, int, int]]:
    count, pos = varint(data, 0)
    if count > len(data):
        raise ValueError('Jumlah entry directory invalid.')
    columns = []
    for _ in range(4):
        column = []
        for _ in range(count):
            value, pos = varint(data, pos)
            column.append(value)
        columns.append(column)
    if pos != len(data):
        raise ValueError('Directory memiliki trailing bytes.')
    entries = []
    tile_id = 0
    for i in range(count):
        tile_id += columns[0][i]
        run, length, encoded_offset = (columns[c][i] for c in (1, 2, 3))
        if not length or (i and columns[0][i] == 0):
            raise ValueError('Directory tidak terurut atau entry kosong.')
        if encoded_offset:
            offset = encoded_offset - 1
        elif i:
            offset = entries[-1][2] + entries[-1][3]
        else:
            raise ValueError('Offset directory pertama invalid.')
        entries.append((tile_id, run, offset, length))
    return entries


def decompress(data: bytes, compression: int) -> bytes:
    if compression == 1:
        return data
    if compression == 2:
        return gzip.decompress(data)
    raise ValueError('Hanya compression none/gzip didukung validator pipeline.')


def validate_pmtiles(path: Path, bounds: list[float]) -> dict:
    """Periksa seluruh directory dan payload MVT, bukan hanya magic/header."""
    size = path.stat().st_size
    with path.open('rb') as stream:
        header = stream.read(127)
        if len(header) != 127 or header[:8] != b'PMTiles\x03':
            raise ValueError('Bukan PMTiles v3.')
        fields = struct.unpack_from('<11Q', header, 8)
        root_off, root_len, meta_off, meta_len, leaf_off, leaf_len, tile_off, tile_len, addressed, entry_count, contents = fields
        for offset, length in [(root_off, root_len), (meta_off, meta_len),
                               (leaf_off, leaf_len), (tile_off, tile_len)]:
            if length and (offset < 127 or offset + length > size):
                raise ValueError('Section PMTiles di luar file.')
        if root_off + root_len > 16384 or not root_len or not tile_len:
            raise ValueError('Root/tile section PMTiles invalid.')
        internal, tile_compression, tile_type, min_z, max_z = header[97:102]
        if tile_type != 1 or (min_z, max_z) != (MIN_ZOOM, MAX_ZOOM):
            raise ValueError('PMTiles wajib MVT dengan zoom 12-16.')
        if not min_z <= header[118] <= max_z:
            raise ValueError('Center zoom PMTiles di luar rentang.')
        actual_bounds = [v / 1e7 for v in struct.unpack_from('<4i', header, 102)]
        if any(abs(a - b) > 1.1e-7 for a, b in zip(actual_bounds, bounds)):
            raise ValueError('Bounds PMTiles berbeda dari konfigurasi.')

        def read(offset, length):
            stream.seek(offset)
            return stream.read(length)

        metadata = json.loads(decompress(read(meta_off, meta_len), internal))
        layer_ids = {layer['id'] for layer in metadata.get('vector_layers', [])}
        if not {'building', 'transportation'} <= layer_ids:
            raise ValueError('Metadata layer bangunan/jalan tidak tersedia.')
        if any(credit not in metadata.get('attribution', '') for credit in ('OpenStreetMap', 'OpenMapTiles')):
            raise ValueError('Atribusi OpenStreetMap/OpenMapTiles tidak tersedia.')
        visited = set()
        entries = []

        def visit(offset, length, depth=0):
            if depth > 3 or (offset, length) in visited:
                raise ValueError('Directory berulang atau terlalu dalam.')
            visited.add((offset, length))
            for tile_id, run, relative, length in directory(decompress(read(offset, length), internal)):
                if run == 0:
                    if relative + length > leaf_len:
                        raise ValueError('Leaf pointer di luar section.')
                    visit(leaf_off + relative, length, depth + 1)
                else:
                    if relative + length > tile_len:
                        raise ValueError('Tile pointer di luar section.')
                    if not ((4 ** MIN_ZOOM - 1) // 3 <= tile_id and
                            tile_id + run <= (4 ** (MAX_ZOOM + 1) - 1) // 3):
                        raise ValueError('Tile ID di luar zoom 12-16.')
                    entries.append((tile_id, run, relative, length))

        visit(root_off, root_len)
        entries.sort()
        if any(a[0] + a[1] > b[0] for a, b in zip(entries, entries[1:])):
            raise ValueError('Tile ID bertumpang tindih.')
        unique = {(e[2], e[3]) for e in entries}
        if not entries or sum(e[1] for e in entries) != addressed or len(entries) != entry_count or len(unique) != contents:
            raise ValueError('Jumlah tile/entry/content tidak konsisten.')
        first_zoom = ((3 * entries[0][0] + 1).bit_length() - 1) // 2
        last_zoom = ((3 * (entries[-1][0] + entries[-1][1] - 1) + 1).bit_length() - 1) // 2
        if (first_zoom, last_zoom) != (min_z, max_z):
            raise ValueError('Rentang zoom header tidak sesuai tile aktual.')
        counts: dict[str, int] = {}
        required_geometries = {'building': 3, 'transportation': 2}
        geometric_layers = set()
        for offset, length in unique:
            tile = decompress(read(tile_off + offset, length), tile_compression)
            for field, wire, layer in protobuf(tile):
                if field != 3 or wire != 2:
                    continue
                fields = list(protobuf(layer))
                names = [v.decode('utf-8') for f, w, v in fields if f == 1 and w == 2]
                if len(names) != 1:
                    raise ValueError('Nama layer MVT invalid.')
                features = [v for f, w, v in fields if f == 2 and w == 2]
                for feature in features:
                    feature_fields = list(protobuf(feature))
                    geometries = [v for f, w, v in feature_fields if f == 4 and w == 2 and v]
                    types = [v for f, w, v in feature_fields if f == 3 and w == 0]
                    if not geometries or len(types) != 1 or types[0] not in (1, 2, 3):
                        raise ValueError('Feature MVT tanpa geometri.')
                    if required_geometries.get(names[0]) == types[0]:
                        geometric_layers.add(names[0])
                counts[names[0]] = counts.get(names[0], 0) + len(features)
        if not counts.get('building') or not counts.get('transportation') or geometric_layers != set(required_geometries):
            raise ValueError('Payload MVT tidak memuat bangunan/jalan.')
    return {'sizeBytes': size, 'sha256': digest(path), 'bounds': actual_bounds,
            'attributionHtml': metadata['attribution'],
            'minZoom': min_z, 'maxZoom': max_z, 'addressedTiles': addressed,
            'tileEntries': entry_count, 'tileContents': contents,
            'featureCountsAcrossUniqueTiles': counts}


def publish(staged: list[tuple[Path, Path]], force: bool):
    """Rollback pasangan aset/manifest jika salah satu pemindahan gagal."""
    backups = []
    published = []
    try:
        for _, destination in staged:
            if destination.exists():
                if not force:
                    raise FileExistsError(f'Output sudah ada: {destination}; gunakan -Force.')
                backup = destination.with_name(destination.name + '.' + uuid.uuid4().hex + '.bak')
                os.replace(destination, backup)
                backups.append((backup, destination))
        for source, destination in staged:
            # link() fails if an unrelated process creates destination after preflight.
            os.link(source, destination)
            published.append(destination)
    except BaseException:
        for destination in published:
            destination.unlink(missing_ok=True)
        for backup, destination in reversed(backups):
            os.replace(backup, destination)
        raise
    else:
        for backup, _ in backups:
            backup.unlink()


def build(args) -> dict:
    output = Path(args.output).resolve()
    manifest = output.with_suffix('.manifest.json')
    if output.suffix.lower() != '.pmtiles':
        raise ValueError('Output harus berekstensi .pmtiles.')
    if not args.force and (output.exists() or manifest.exists()) and not args.bounds_only:
        raise FileExistsError('Output/manifest sudah ada; gunakan -Force untuk mengganti.')
    bounds, provenance = load_boundary(Path(args.boundary).resolve())
    if args.bounds_only:
        return {'bounds': bounds, 'boundary': provenance}
    cache = Path(args.cache).resolve()
    cache.mkdir(parents=True, exist_ok=True)
    if args.osm_pbf:
        pbf = Path(args.osm_pbf).resolve(strict=True)
        source = args.source_url or 'local-file: source supplied by operator'
    else:
        source = OSM_URL
        pbf = download(source, cache / 'java-latest.osm.pbf', args.osm_sha256)
    if output == pbf or manifest == pbf:
        raise ValueError('Output tidak boleh menimpa input.')
    input_hash = check_hash(pbf, args.osm_sha256) if args.osm_sha256 else digest(pbf)
    with pbf.open('rb') as stream:
        prefix = stream.read(4)
        if len(prefix) != 4:
            raise ValueError('Input PBF terpotong.')
        header_size = struct.unpack('>I', prefix)[0]
        if not 0 < header_size <= 64 * 1024 or b'OSMHeader' not in stream.read(header_size):
            raise ValueError('Input bukan OSM PBF.')
    jar = download(JAR_URL, cache / f'planetiler-{VERSION}.jar', JAR_SHA256)
    version = subprocess.run([args.java, '-version'], capture_output=True, text=True, check=True)
    java_version = version.stdout + version.stderr
    match = re.search(r'version "(\d+)', java_version)
    if not match or int(match[1]) < 21:
        raise ValueError('Java 21+ diperlukan.')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.ganesha-build-', dir=output.parent) as staging:
        staged = Path(staging) / output.name
        command = [args.java, '-Xmx4g', '-jar', str(jar), '--download',
                   f'--osm-path={pbf}', '--bounds=' + ','.join(map(str, bounds)),
                   f'--minzoom={MIN_ZOOM}', f'--maxzoom={MAX_ZOOM}',
                   f'--render-maxzoom={MAX_ZOOM}',
                   f'--output={staged}', f'--tmpdir={cache / "scratch"}',
                   '--threads=4']
        if args.water_polygons_url:
            if not args.water_polygons_url.startswith('https://'):
                raise ValueError('URL water polygons wajib HTTPS.')
            command.append(f'--water-polygons-url={args.water_polygons_url}')
        log = cache / 'last-build.log'
        print('Menjalankan Planetiler; log: ' + str(log), flush=True)
        with log.open('w', encoding='utf-8') as stream:
            subprocess.run(command, cwd=cache, stdout=stream, stderr=subprocess.STDOUT, check=True)
        evidence = validate_pmtiles(staged, bounds)
        support_sources = []
        for filename, url in [
            ('water-polygons-split-3857.zip', args.water_polygons_url or
             'https://osmdata.openstreetmap.de/download/water-polygons-split-3857.zip'),
            ('natural_earth_vector.sqlite.zip', 'https://naciscdn.org/naturalearth/packages/natural_earth_vector.sqlite.zip'),
            ('lake_centerline.shp.zip', 'https://github.com/acalcutt/osm-lakelines/releases/download/v12/lake_centerline.shp.zip')]:
            source_path = cache / 'data/sources' / filename
            if source_path.exists():
                support_sources.append({'filename': filename, 'configuredUrl': url,
                                        'originNote': 'Configured generator URL; an operator-supplied cache may predate this URL.',
                                        'sizeBytes': source_path.stat().st_size, 'sha256': digest(source_path)})
        result = {'schemaVersion': 1, 'generatedAtUtc': dt.datetime.now(dt.timezone.utc).isoformat(),
                  'generator': {'name': 'Planetiler', 'version': VERSION, 'jarSha256': JAR_SHA256,
                                'url': JAR_URL, 'profile': 'OpenMapTiles', 'java': java_version.strip()},
                  'source': {'url': source, 'filename': pbf.name, 'sha256': input_hash,
                             'sizeBytes': pbf.stat().st_size},
                  'supportSources': support_sources,
                  'boundary': provenance, 'requestedBounds': bounds,
                  'attribution': ATTRIBUTION, 'sourceLicense': 'ODbL-1.0',
                  'sourceLicenseUrl': 'https://www.openstreetmap.org/copyright',
                  'profileLicense': 'CC-BY for cartography/schema; BSD for code',
                  'profileLicenseUrl': 'https://github.com/openmaptiles/openmaptiles/blob/master/LICENSE.md',
                  'output': {'filename': output.name, **evidence},
                  'limitations': ['Build-time artifact; belum terintegrasi renderer/APK.',
                                  'Batas OSM bukan hasil survei lapangan.',
                                  'Ukuran APK belum diukur.']}
        staged_manifest = Path(staging) / manifest.name
        staged_manifest.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
        publish([(staged, output), (staged_manifest, manifest)], args.force)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parent
    parser.add_argument('--boundary', default=str(root / 'campus-boundary.json'))
    parser.add_argument('--output', default=str(root / '../../assets/map/ganesha.pmtiles'))
    parser.add_argument('--cache', default=str(root / '.cache'))
    parser.add_argument('--osm-pbf')
    parser.add_argument('--osm-sha256')
    parser.add_argument('--source-url')
    parser.add_argument('--water-polygons-url')
    parser.add_argument('--java', default='java')
    parser.add_argument('--force', action='store_true')
    parser.add_argument('--bounds-only', action='store_true')
    args = parser.parse_args()
    try:
        print(json.dumps(build(args), indent=2, ensure_ascii=False))
    except (OSError, ValueError, KeyError, struct.error, subprocess.SubprocessError) as error:
        print(f'GAGAL: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
