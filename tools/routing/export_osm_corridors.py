"""Ekspor selasar lantai 1 OSM (`highway=corridor`) sebagai lorong kandidat.

Membaca layer `transportation` di `tools/tiles/ganesha.gpkg` (master yang sama
dengan graf `assets/routing/ganesha-walk-demo.geojson`) dan menulis setiap way
ber-`kind` `corridor` ke `assets/routing/corridors.geojson`. Koordinat disalin
apa adanya dari master, sehingga simpul yang juga ada di graf jalan kaki
bertemu tepat di titik yang sama. Semua selasar berstatus `verified: false`
sampai dicek di lapangan (PRD §11); routing menyebutnya "belum diverifikasi".

Hanya pustaka standar (sqlite3 + struct), deterministik, dan idempoten:

    python3 -I tools/routing/export_osm_corridors.py
"""
import argparse
import hashlib
import json
import sqlite3
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATUS = 'draft — belum diverifikasi lapangan'


def _wkb_lines(blob):
    """LineString/MultiLineString dari blob geometri GeoPackage."""
    envelope = (blob[3] >> 1) & 7
    view = memoryview(blob)[8 + {0: 0, 1: 32, 2: 48, 3: 48, 4: 64}[envelope]:]
    lines = []

    def read(offset):
        order = '<' if view[offset] == 1 else '>'
        kind = struct.unpack_from(order + 'I', view, offset + 1)[0] % 1000
        offset += 5
        if kind == 2:
            count = struct.unpack_from(order + 'I', view, offset)[0]
            offset += 4
            lines.append([list(struct.unpack_from(order + 'dd', view, offset + 16 * i))
                          for i in range(count)])
            return offset + 16 * count
        if kind == 5:
            count = struct.unpack_from(order + 'I', view, offset)[0]
            offset += 4
            for _ in range(count):
                offset = read(offset)
            return offset
        raise ValueError(f'Tipe geometri {kind} bukan garis.')

    read(0)
    return lines


def export(master, output):
    connection = sqlite3.connect(f'file:{master}?mode=ro', uri=True)
    rows = connection.execute(
        "select source_id, name, geom from transportation "
        "where kind = 'corridor' order by source_id").fetchall()
    features = []
    for source_id, name, geom in rows:
        for line in _wkb_lines(geom):
            if len(line) < 2:
                continue
            properties = {'source_id': source_id, 'kind': 'corridor', 'verified': False}
            if name:
                properties['name'] = name
            features.append({'type': 'Feature', 'properties': properties,
                             'geometry': {'type': 'LineString', 'coordinates': line}})
    document = {
        'type': 'FeatureCollection',
        'status': STATUS,
        'description': ('Selasar lantai 1 dari OpenStreetMap (highway=corridor), '
                        'dipakai routing sebagai lorong kandidat yang belum '
                        'diverifikasi. Dibuat oleh tools/routing/export_osm_corridors.py.'),
        'masterSha256': hashlib.sha256(Path(master).read_bytes()).hexdigest(),
        'features': features,
    }
    with open(output, 'w', encoding='utf-8', newline='\n') as stream:
        stream.write(json.dumps(document, ensure_ascii=False, separators=(',', ':')) + '\n')
    return len(features)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--master', default=ROOT / 'tools/tiles/ganesha.gpkg')
    parser.add_argument('--output', default=ROOT / 'assets/routing/corridors.geojson')
    args = parser.parse_args()
    count = export(args.master, args.output)
    print(f'Ditulis {count} selasar ke {args.output}')


if __name__ == '__main__':
    main()
