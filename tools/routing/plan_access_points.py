"""Candidate access points and the trail loop, from the bundled walk graph.

Most campus buildings have an open ground floor instead of a door, so the
navigation target is an *access point*: where the walkway meets the building
(PRD §11, [CL] 24 November 2026). Until the field check, each building gets
one candidate: the centre of the building projected onto the nearest edge of
the walk graph's main network. Isolated pieces of the draft graph are skipped,
otherwise a route to that building cannot be computed.

The trail order is the shortest closed loop over those access points, measured
along the graph (exhaustive search over 9! orders). The app rotates the loop to
start at the POI nearest to the user, so any POI may be first.

Usage (from the repository root):

    python3 tools/routing/plan_access_points.py \\
        assets/routing/ganesha-walk-demo.geojson assets/data/pois.json \\
        --write --check-list task-implementation/backend/PB11-access-point-field-check.md

Without ``--write`` the result is only printed. Deterministic: the same inputs
give the same output. Standard library only.
"""

from __future__ import annotations

import argparse
import heapq
import itertools
import json
import math
import re
from pathlib import Path

WALKING_MPS = 1.3
SIDES = ['utara', 'timur laut', 'timur', 'tenggara',
         'selatan', 'barat daya', 'barat', 'barat laut']


def metres(a, b):
    """Equirectangular distance in metres between (lng, lat) pairs."""
    lat = math.radians((a[1] + b[1]) / 2)
    dx = (b[0] - a[0]) * 111320 * math.cos(lat)
    dy = (b[1] - a[1]) * 110540
    return math.hypot(dx, dy)


def project(p, a, b):
    """Closest point to p on segment a-b, in a local metric frame."""
    lat = math.radians(p[1])
    sx, sy = 111320 * math.cos(lat), 110540
    ax, ay = (a[0] - p[0]) * sx, (a[1] - p[1]) * sy
    bx, by = (b[0] - p[0]) * sx, (b[1] - p[1]) * sy
    dx, dy = bx - ax, by - ay
    length2 = dx * dx + dy * dy
    t = 0.0 if length2 == 0 else max(0.0, min(1.0, -(ax * dx + ay * dy) / length2))
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), t


def side(centre, point):
    """Compass side of the building the access point lies on."""
    lat = math.radians(centre[1])
    dx = (point[0] - centre[0]) * math.cos(lat)
    dy = point[1] - centre[1]
    bearing = (math.degrees(math.atan2(dx, dy)) + 360) % 360
    return SIDES[int((bearing + 22.5) // 45) % 8]


def node(p):
    return (round(p[0], 7), round(p[1], 7))


def load_graph(path):
    graph = json.loads(Path(path).read_text(encoding='utf-8'))
    adjacency, edges = {}, []
    for feature in graph['features']:
        points = [node(p) for p in feature['geometry']['coordinates']]
        for a, b in zip(points, points[1:]):
            weight = metres(a, b)
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
    """Shortest distances from several (node, initial distance) sources."""
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


def plan(graph_path, pois_path):
    adjacency, edges = load_graph(graph_path)
    network, piece_count = main_network(adjacency)
    main_edges = [(a, b) for a, b in edges if a in network]
    document = json.loads(Path(pois_path).read_text(encoding='utf-8'))

    points = []
    for poi in document['pois']:
        centre = (poi['lng'], poi['lat'])
        best = None
        for a, b in main_edges:
            point, t = project(centre, a, b)
            distance = metres(centre, point)
            if best is None or distance < best[0]:
                best = (distance, point, a, b)
        distance, point, a, b = best
        points.append({
            'id': poi['id'],
            'name': poi['name'],
            'centre': centre,
            'point': (round(point[0], 7), round(point[1], 7)),
            'offset': distance,
            'side': side(centre, point),
            'edge': (a, b),
        })

    # Walking distance between access points: start from both ends of the
    # access point's edge, then finish on the other point's edge.
    ids = [p['id'] for p in points]
    walk = {}
    for p in points:
        a, b = p['edge']
        table = dijkstra(adjacency, [(a, metres(p['point'], a)),
                                     (b, metres(p['point'], b))])
        for q in points:
            if p is q:
                walk[p['id'], q['id']] = 0.0
                continue
            qa, qb = q['edge']
            walk[p['id'], q['id']] = min(
                table.get(qa, math.inf) + metres(qa, q['point']),
                table.get(qb, math.inf) + metres(qb, q['point']),
            )

    first, rest = ids[0], ids[1:]

    def loop_length(order):
        return sum(walk[x, y] for x, y in zip(order, order[1:] + order[:1]))

    loop = min(((first,) + perm for perm in itertools.permutations(rest)),
               key=lambda order: (loop_length(order), order))
    # A loop has the same length both ways; walk it so that the neighbour
    # with the lower ID comes second, which keeps the output stable.
    if loop[1] > loop[-1]:
        loop = (loop[0],) + tuple(reversed(loop[1:]))
    return {
        'pieces': piece_count,
        'network_nodes': len(network),
        'nodes': len(adjacency),
        'points': points,
        'loop': list(loop),
        'loop_m': loop_length(loop),
        'walk': walk,
    }


def write_dataset(pois_path, result):
    """Fills entrances[] with unverified candidates and trailOrder 1-10.

    Edits the two values in place so the file keeps its hand-written layout
    (one-line lists); running it again replaces the same values.
    """
    path = Path(pois_path)
    text = path.read_text(encoding='utf-8')
    order = {poi_id: i + 1 for i, poi_id in enumerate(result['loop'])}
    for p in result['points']:
        head = re.search(r'"id": "%s"' % re.escape(p['id']), text)
        nxt = re.search(r'"id": "', text[head.end():])
        stop = head.end() + nxt.start() if nxt else len(text)
        block = text[head.start():stop]
        entrance = json.dumps([{
            'lat': p['point'][1],
            'lng': p['point'][0],
            'label': f"Titik akses sisi {p['side']}",
            'verified': False,
        }], ensure_ascii=False)
        block, found_entrances = re.subn(
            r'"entrances": \[[^\n]*?\](?=,\n)',
            lambda _: f'"entrances": {entrance}', block, count=1)
        block, found_order = re.subn(
            r'"trailOrder": (null|\d+)',
            f'"trailOrder": {order[p["id"]]}', block, count=1)
        if (found_entrances, found_order) != (1, 1):
            raise SystemExit(f"{p['id']}: entrances/trailOrder tidak ditemukan")
        text = text[:head.start()] + block + text[stop:]
    json.loads(text)  # the result must stay valid JSON
    path.write_text(text, encoding='utf-8')


def check_list(result):
    names = {p['id']: p['name'] for p in result['points']}
    loop = result['loop']
    lines = [
        '# PB11 — Daftar cek titik akses di lapangan',
        '',
        'Dibuat oleh `tools/routing/plan_access_points.py` dari graf jalan kaki '
        'draf (`assets/routing/ganesha-walk-demo.geojson`) dan titik tengah gedung '
        'di `assets/data/pois.json`. Setiap titik adalah **kandidat**: proyeksi '
        'titik tengah gedung ke ruas jalur terdekat pada jaringan utama graf. '
        'Belum ada yang diverifikasi di lapangan (`verified: false`).',
        '',
        '## Cara cek',
        '',
        '1. Buka link peta tiap baris, lalu berdiri di titik tersebut.',
        '2. Tandai **Cocok** bila dari titik itu orang memang masuk ke gedung '
        '(pintu atau sisi lantai 1 yang terbuka) dari jalur pejalan kaki.',
        '3. Bila tidak cocok, berdiri di tempat orang masuk yang sebenarnya dan '
        'catat koordinatnya (Google Maps: tekan lama titik biru, salin angka). '
        'Bila gedung punya beberapa sisi masuk yang sering dipakai, catat juga '
        'sisi lainnya beserta arahnya.',
        '4. Setelah dicek, koordinat di `pois.json` dikoreksi dan `verified` '
        'diubah menjadi `true` per titik.',
        '',
        '## Kandidat',
        '',
        '| POI | Gedung | Sisi | Lat | Lng | Jarak dari titik tengah | Peta | Hasil cek |',
        '| --- | --- | --- | --- | --- | --- | --- | --- |',
    ]
    for p in result['points']:
        lng, lat = p['point']
        url = f'https://www.google.com/maps?q={lat},{lng}'
        lines.append(
            f"| {p['id']} | {p['name']} | {p['side']} | {lat} | {lng} | "
            f"{p['offset']:.0f} m | [buka]({url}) | ☐ Cocok ☐ Koreksi: |")
    lines += [
        '',
        '## Urutan trail (keliling)',
        '',
        f"Keliling terpendek di atas graf: {result['loop_m']:.0f} m "
        f"(~{result['loop_m'] / WALKING_MPS / 60:.0f} menit jalan kaki). "
        'Aplikasi memutar urutan ini agar dimulai dari POI terdekat dengan '
        'pengguna, lalu berlanjut searah putaran.',
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
        f"Graf draf berisi {result['nodes']} simpul dalam {result['pieces']} "
        f"potongan terpisah; jaringan utama {result['network_nodes']} simpul. "
        'Kandidat hanya memakai jaringan utama, karena titik di potongan terpisah '
        'tidak dapat dijangkau rute. Saat cek lapangan, catat juga jalur nyata '
        'yang tidak ada di peta rute (misalnya selasar yang menghubungkan '
        'gedung).',
        '',
    ]
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('graph')
    parser.add_argument('pois')
    parser.add_argument('--write', action='store_true',
                        help='fill entrances[] and trailOrder in the POI file')
    parser.add_argument('--check-list', help='write the field check list here')
    args = parser.parse_args()

    result = plan(args.graph, args.pois)
    print(f"Graf: {result['nodes']} simpul, {result['pieces']} potongan; "
          f"jaringan utama {result['network_nodes']} simpul")
    for p in result['points']:
        print(f"  {p['id']} {p['name']:<26} sisi {p['side']:<10} "
              f"{p['offset']:4.0f} m  {p['point'][1]}, {p['point'][0]}")
    names = {p['id']: p['name'] for p in result['points']}
    print(f"Keliling {result['loop_m']:.0f} m: "
          + ' -> '.join(names[i] for i in result['loop']))
    if args.write:
        write_dataset(args.pois, result)
        print(f'Ditulis: {args.pois}')
    if args.check_list:
        Path(args.check_list).write_text(check_list(result), encoding='utf-8')
        print(f'Ditulis: {args.check_list}')


if __name__ == '__main__':
    main()
