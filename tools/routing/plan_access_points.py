"""Candidate access points per building and the trail loop.

Most campus buildings have an open ground floor instead of a single door, so
the navigation target is an *access point*: a place where a walkway meets the
building (PRD §11, [CL] 24 November 2026). A building may have several.

Candidates come from the same OSM data the map draws:

- the building outline is the OSM polygon that contains the POI centre, plus
  any extra polygons listed in ``EXTRA_BUILDINGS`` (one POI may span two
  buildings, e.g. Labtek X & XI);
- every edge of the walk graph's *main network* that comes within
  ``TOUCH_M`` of that outline gives one point: the spot on the edge closest
  to the building. Most of these are walkways that end at the building wall.
  A building with no edge that close is searched again up to ``WIDE_M``;
- points closer than ``MERGE_M`` to each other are merged, keeping the one
  nearest to the wall.

Edges on separate pieces of the graph (a covered walkway linking two
buildings, for example) are not reachable by a route, so they are listed in
the field check list but not used.

The trail order is the shortest closed loop over the POIs, where the distance
between two POIs is the shortest walk between any of their access points
(exhaustive search over 9! orders). The app rotates the loop to start at the
POI nearest to the user.

Usage (from the repository root, with ``tools/tiles/requirements-campus.txt``
installed for fiona and shapely):

    python3 tools/routing/plan_access_points.py \\
        assets/routing/ganesha-walk-demo.geojson assets/data/pois.json \\
        --buildings tools/tiles/ganesha.gpkg --write \\
        --check-list task-implementation/backend/PB11-access-point-field-check.md

Without ``--write`` the result is only printed. Deterministic: the same inputs
give the same output, and running it again rewrites the same values.
"""

from __future__ import annotations

import argparse
import heapq
import itertools
import json
import math
import re
from pathlib import Path

import fiona
from shapely.geometry import LineString, Point, Polygon, shape
from shapely.ops import nearest_points, unary_union

WALKING_MPS = 1.3
TOUCH_M = 4.0
WIDE_M = 8.0
MERGE_M = 5.0
SIDES = ['utara', 'timur laut', 'timur', 'tenggara',
         'selatan', 'barat daya', 'barat', 'barat laut']

# POIs that span more than the polygon containing their centre.
EXTRA_BUILDINGS = {
    'P05': ['way/119419843'],  # Labtek XI, next to Labtek X
}

# Local metric frame around the campus (equirectangular, metres).
LAT0, LNG0 = -6.8905, 107.61
KX = 111320 * math.cos(math.radians(LAT0))
KY = 110540


def to_m(lng, lat):
    return ((lng - LNG0) * KX, (lat - LAT0) * KY)


def to_deg(x, y):
    return (round(LNG0 + x / KX, 7), round(LAT0 + y / KY, 7))


def node(p):
    return (round(p[0], 7), round(p[1], 7))


def polygon_m(geometry):
    g = shape(geometry)
    if g.geom_type == 'MultiPolygon':
        g = max(g.geoms, key=lambda part: part.area)
    return Polygon([to_m(*c[:2]) for c in g.exterior.coords])


def load_graph(path):
    graph = json.loads(Path(path).read_text(encoding='utf-8'))
    adjacency, edges = {}, []
    for feature in graph['features']:
        points = [node(p) for p in feature['geometry']['coordinates']]
        for a, b in zip(points, points[1:]):
            weight = math.dist(to_m(*a), to_m(*b))
            adjacency.setdefault(a, []).append((b, weight))
            adjacency.setdefault(b, []).append((a, weight))
            edges.append((a, b))
    return adjacency, edges


def main_network(adjacency):
    """Nodes of the largest connected piece, and how many pieces exist."""
    seen, pieces = {}, []
    for start in adjacency:
        if start in seen:
            continue
        members, stack = [start], [start]
        seen[start] = len(pieces)
        while stack:
            for nxt, _ in adjacency[stack.pop()]:
                if nxt not in seen:
                    seen[nxt] = len(pieces)
                    members.append(nxt)
                    stack.append(nxt)
        pieces.append(members)
    return set(max(pieces, key=len)), len(pieces)


def dijkstra(adjacency, sources):
    dist, heap = {}, []
    for n, d in sources:
        if d < dist.get(n, math.inf):
            dist[n] = d
            heapq.heappush(heap, (d, n))
    while heap:
        d, u = heapq.heappop(heap)
        if d > dist[u]:
            continue
        for v, w in adjacency[u]:
            nd = d + w
            if nd < dist.get(v, math.inf):
                dist[v] = nd
                heapq.heappush(heap, (nd, v))
    return dist


def side(centre, point):
    """Compass side of the building, from its centre to the access point."""
    bearing = (math.degrees(math.atan2(point[0] - centre[0],
                                       point[1] - centre[1])) + 360) % 360
    return bearing, SIDES[int((bearing + 22.5) // 45) % 8]


def touches(edges, outline, limit):
    """(distance, point, edge) for each edge within limit of the outline."""
    found = []
    for a, b in edges:
        segment = LineString([to_m(*a), to_m(*b)])
        distance = segment.distance(outline)
        if distance <= limit:
            point = nearest_points(segment, outline)[0]
            found.append((distance, (point.x, point.y), (a, b)))
    return sorted(found, key=lambda t: (round(t[0], 3), t[1]))


def merge(found):
    kept = []
    for distance, point, edge in found:
        if all(math.dist(point, other[1]) >= MERGE_M for other in kept):
            kept.append((distance, point, edge))
    return kept


def plan(graph_path, pois_path, buildings_path):
    adjacency, edges = load_graph(graph_path)
    network, piece_count = main_network(adjacency)
    main_edges = [e for e in edges if e[0] in network]
    other_edges = [e for e in edges if e[0] not in network]
    with fiona.open(buildings_path, layer='building') as source:
        buildings = [(f['properties']['source_id'], f['properties']['name'],
                      polygon_m(f['geometry'])) for f in source]
    document = json.loads(Path(pois_path).read_text(encoding='utf-8'))

    results = []
    for poi in document['pois']:
        centre = Point(to_m(poi['lng'], poi['lat']))
        extra = EXTRA_BUILDINGS.get(poi['id'], [])
        parts = [(sid, name, g) for sid, name, g in buildings
                 if g.contains(centre) or sid in extra]
        if not parts:
            raise SystemExit(f"{poi['id']}: tidak ada poligon gedung di titik tengahnya")
        outline = unary_union([g for _, _, g in parts])
        middle = (outline.centroid.x, outline.centroid.y)

        limit = TOUCH_M
        found = touches(main_edges, outline, limit)
        if not found:
            limit = WIDE_M
            found = touches(main_edges, outline, limit)
        points = []
        for distance, point, edge in merge(found):
            bearing, label = side(middle, point)
            points.append({'point': to_deg(*point), 'm': point, 'edge': edge,
                           'wall_m': distance, 'bearing': bearing, 'side': label})
        points.sort(key=lambda p: (p['bearing'], p['point']))
        counts = {}
        for p in points:
            counts[p['side']] = counts.get(p['side'], 0) + 1
        seen = {}
        for p in points:
            if counts[p['side']] > 1:
                seen[p['side']] = seen.get(p['side'], 0) + 1
                p['label'] = f"Titik akses sisi {p['side']} {seen[p['side']]}"
            else:
                p['label'] = f"Titik akses sisi {p['side']}"
        detached = [(d, to_deg(*pt)) for d, pt, _ in merge(touches(other_edges, outline, TOUCH_M))]
        results.append({'id': poi['id'], 'name': poi['name'],
                        'buildings': [(sid, name) for sid, name, _ in parts],
                        'limit': limit, 'points': points, 'detached': detached})

    # Shortest walk between any access point of one POI and any of another.
    def sources(entry):
        out = []
        for p in entry['points']:
            a, b = p['edge']
            out += [(a, math.dist(p['m'], to_m(*a))), (b, math.dist(p['m'], to_m(*b)))]
        return out

    ids = [r['id'] for r in results]
    walk = {}
    for r in results:
        table = dijkstra(adjacency, sources(r))
        for q in results:
            walk[r['id'], q['id']] = 0.0 if r is q else min(
                (table.get(n, math.inf) + d for n, d in sources(q)), default=math.inf)

    def loop_length(order):
        return sum(walk[x, y] for x, y in zip(order, order[1:] + order[:1]))

    first, rest = ids[0], ids[1:]
    loop = min(((first,) + perm for perm in itertools.permutations(rest)),
               key=lambda order: (loop_length(order), order))
    # Same length both ways; walk it so the neighbour with the higher ID comes
    # second, which keeps the direction chosen on 24 November 2026
    # (Labtek V, then Labtek VIII).
    if loop[1] < loop[-1]:
        loop = (loop[0],) + tuple(reversed(loop[1:]))
    return {'pieces': piece_count, 'network_nodes': len(network),
            'nodes': len(adjacency), 'pois': results, 'loop': list(loop),
            'loop_m': loop_length(loop), 'walk': walk}


def write_dataset(pois_path, result):
    """Rewrites entrances[] and trailOrder in place, one access point per line."""
    path = Path(pois_path)
    text = path.read_text(encoding='utf-8')
    order = {poi_id: i + 1 for i, poi_id in enumerate(result['loop'])}
    for r in result['pois']:
        head = re.search(r'"id": "%s"' % re.escape(r['id']), text)
        nxt = re.search(r'"id": "', text[head.end():])
        stop = head.end() + nxt.start() if nxt else len(text)
        block = text[head.start():stop]
        items = [json.dumps({'lat': p['point'][1], 'lng': p['point'][0],
                             'label': p['label'], 'verified': False},
                            ensure_ascii=False) for p in r['points']]
        value = '[\n' + ',\n'.join(' ' * 8 + item for item in items) + '\n      ]'
        # Entrance objects hold no brackets, so [^\]]* spans the whole list.
        block, found_entrances = re.subn(
            r'"entrances": \[[^\]]*\]',
            lambda _: f'"entrances": {value}', block, count=1)
        block, found_order = re.subn(
            r'"trailOrder": (null|\d+)',
            f'"trailOrder": {order[r["id"]]}', block, count=1)
        if (found_entrances, found_order) != (1, 1):
            raise SystemExit(f"{r['id']}: entrances/trailOrder tidak ditemukan")
        text = text[:head.start()] + block + text[stop:]
    json.loads(text)  # the result must stay valid JSON
    path.write_text(text, encoding='utf-8')


def check_list(result):
    names = {r['id']: r['name'] for r in result['pois']}
    total = sum(len(r['points']) for r in result['pois'])
    lines = [
        '# PB11 — Daftar cek titik akses di lapangan',
        '',
        'Dibuat oleh `tools/routing/plan_access_points.py` dari data OSM yang '
        'juga digambar di peta: poligon gedung (`tools/tiles/ganesha.gpkg`) dan '
        'graf jalan kaki (`assets/routing/ganesha-walk-demo.geojson`). Titik akses '
        f'adalah titik pada jalur yang menempel ke gedung (≤{TOUCH_M:.0f} m dari '
        f'dinding; {WIDE_M:.0f} m bila tidak ada yang sedekat itu), digabung bila '
        f'berjarak <{MERGE_M:.0f} m. Totalnya {total} kandidat untuk 10 gedung; '
        'semuanya belum diverifikasi (`verified: false`). Navigasi akan menuju '
        'titik akses terdekat milik gedung tujuan.',
        '',
        '## Cara cek',
        '',
        '1. Buka link peta tiap baris, lalu berdiri di titik tersebut.',
        '2. Tandai **Cocok** bila dari titik itu orang memang masuk ke gedung '
        '(pintu atau sisi lantai 1 yang terbuka).',
        '3. Tandai **Hapus** bila titik itu bukan jalan masuk (misalnya pagar, '
        'jendela, atau tembok tertutup).',
        '4. Bila ada jalan masuk yang tidak tercantum, berdiri di sana dan catat '
        'koordinatnya (Google Maps: tekan lama titik biru, salin angka) beserta '
        'sisi gedungnya.',
        '5. Setelah dicek, `pois.json` dikoreksi dan `verified` diubah menjadi '
        '`true` per titik.',
    ]
    for r in result['pois']:
        parts = ', '.join(f'{name} ({sid})' for sid, name in r['buildings'])
        lines += ['', f"## {r['id']} — {r['name']}", '', f'Poligon OSM: {parts}.']
        if r['limit'] > TOUCH_M:
            lines.append(f'Tidak ada jalur dalam {TOUCH_M:.0f} m dari dinding; '
                         f'pencarian diperluas sampai {r["limit"]:.0f} m.')
        lines += ['', '| Titik | Lat | Lng | Jarak ke dinding | Peta | Hasil cek |',
                  '| --- | --- | --- | --- | --- | --- |']
        for p in r['points']:
            lng, lat = p['point']
            lines.append(
                f"| {p['label']} | {lat} | {lng} | {p['wall_m']:.1f} m | "
                f"[buka](https://www.google.com/maps?q={lat},{lng}) | "
                '☐ Cocok ☐ Hapus |')
        for d, (lng, lat) in r['detached']:
            lines.append(
                f'| Jalur terputus dari jaringan rute (tidak dipakai) | {lat} | '
                f'{lng} | {d:.1f} m | '
                f'[buka](https://www.google.com/maps?q={lat},{lng}) | '
                '☐ Jalur nyata, perlu disambung ☐ Abaikan |')
    loop = result['loop']
    lines += [
        '',
        '## Urutan trail (keliling)',
        '',
        f"Jumlah jarak jalan antar-gedung ±{result['loop_m']:.0f} m, diukur dari "
        'titik akses terdekat ke titik akses terdekat; jalan menembus atau '
        'mengitari gedung untuk berpindah sisi tidak dihitung, jadi jarak tempuh '
        'nyata lebih panjang. Aplikasi memutar urutan ini agar dimulai dari POI '
        'terdekat dengan pengguna, lalu berlanjut searah putaran.',
        '',
        '| Urutan | POI | Gedung | Ke berikutnya |',
        '| --- | --- | --- | --- |',
    ]
    for i, poi_id in enumerate(loop):
        nxt = loop[(i + 1) % len(loop)]
        lines.append(f"| {i + 1} | {poi_id} | {names[poi_id]} | "
                     f"{result['walk'][poi_id, nxt]:.0f} m ke {names[nxt]} |")
    lines += [
        '',
        '## Catatan graf',
        '',
        f"Graf berisi {result['nodes']} simpul dalam {result['pieces']} potongan "
        f"terpisah; jaringan utama {result['network_nodes']} simpul. Hanya jaringan "
        'utama yang dapat dipakai rute. Jalur yang terputus, misalnya selasar '
        'antar-gedung, tercantum di tabel per gedung untuk dicek.',
        '',
    ]
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('graph')
    parser.add_argument('pois')
    parser.add_argument('--buildings', default='tools/tiles/ganesha.gpkg')
    parser.add_argument('--write', action='store_true',
                        help='fill entrances[] and trailOrder in the POI file')
    parser.add_argument('--check-list', help='write the field check list here')
    args = parser.parse_args()

    result = plan(args.graph, args.pois, args.buildings)
    print(f"Graf: {result['nodes']} simpul, {result['pieces']} potongan; "
          f"jaringan utama {result['network_nodes']} simpul")
    for r in result['pois']:
        extra = f" (batas {r['limit']:.0f} m)" if r['limit'] > TOUCH_M else ''
        print(f"  {r['id']} {r['name']:<26} {len(r['points'])} titik akses, "
              f"{len(r['detached'])} jalur terputus{extra}")
        for p in r['points']:
            print(f"      {p['label']:<30} {p['wall_m']:4.1f} m  "
                  f"{p['point'][1]}, {p['point'][0]}")
    names = {r['id']: r['name'] for r in result['pois']}
    print(f"Keliling ±{result['loop_m']:.0f} m antar-titik akses terdekat: "
          + ' -> '.join(names[i] for i in result['loop']))
    if args.write:
        write_dataset(args.pois, result)
        print(f'Ditulis: {args.pois}')
    if args.check_list:
        Path(args.check_list).write_text(check_list(result), encoding='utf-8')
        print(f'Ditulis: {args.check_list}')


if __name__ == '__main__':
    main()
