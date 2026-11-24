"""Audit offline aset PB04; --apk memeriksa bundling, bukan bukti render Android."""

import argparse
import json
from pathlib import Path
import zipfile

from tile_pipeline import digest, load_boundary, validate_pmtiles


def audit(root: Path, apk: Path | None = None) -> dict:
    assets = root / 'assets/map'
    manifest = json.loads((assets / 'ganesha.manifest.json').read_text(encoding='utf-8'))
    bounds, _ = load_boundary(root / 'tools/tiles/campus-boundary.json')
    actual = validate_pmtiles(assets / 'ganesha.pmtiles', bounds, max_zoom=18)
    graph = root / 'assets/routing/ganesha-walk-demo.geojson'
    if (digest(graph) != manifest['graph']['sha256'] or
            digest(root / 'tools/tiles/ganesha.gpkg') != manifest['masterSha256']):
        raise ValueError('Graf atau master berbeda dari manifest.')
    for key, value in actual.items():
        if manifest['output'].get(key) != value:
            raise ValueError(f'Manifest berbeda dari arsip: {key}')

    style = json.loads((assets / 'agam-style.json').read_text(encoding='utf-8'))
    available_layers = actual['featureCountsAcrossUniqueTiles']
    for layer in style['layers']:
        if 'source-layer' in layer and layer['source-layer'] not in available_layers:
            raise ValueError(f'Layer style tidak tersedia: {layer["source-layer"]}')
    # Kandidat ini sengaja tidak memiliki sumber jaringan/glyph/sprite.
    if style.get('glyphs') or style.get('sprite'):
        raise ValueError('Kandidat style memerlukan aset tambahan yang belum diaudit.')
    if style['sources'] != {
        'openmaptiles': {'type': 'vector', 'tiles': [], 'minzoom': 12, 'maxzoom': 18}
    }:
        raise ValueError('Binding kandidat berubah; audit ulang provider offline.')

    bundled = []
    if apk is not None:
        with zipfile.ZipFile(apk) as archive:
            for name in ['ganesha.pmtiles', 'agam-style.json', 'ganesha.manifest.json']:
                entry = f'assets/flutter_assets/assets/map/{name}'
                if archive.read(entry) != (assets / name).read_bytes():
                    raise ValueError(f'Aset APK berbeda dari source: {name}')
                bundled.append(entry)
            entry = 'assets/flutter_assets/assets/routing/' + graph.name
            if entry in archive.namelist():
                if archive.read(entry) != graph.read_bytes():
                    raise ValueError('Graf dalam APK berbeda dari master.')
                bundled.append(entry)
    return {
        'archive': actual,
        'styleStatus': style['metadata']['agam:status'],
        'apkChecked': str(apk) if apk else None,
        'bundledEntries': bundled,
        'limitations': 'Bukan bukti render, atribusi tampil, penggunaan offline di perangkat, atau acceptance area layanan.',
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apk', type=Path)
    args = parser.parse_args()
    print(json.dumps(audit(Path(__file__).resolve().parents[2], args.apk), ensure_ascii=False, indent=2))
