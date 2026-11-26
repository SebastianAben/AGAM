"""Independent oracle: Labtek V centre -> Labtek VII with OSM corridors.

Usage: python3 -I tools/routing/check_corridor_route.py <repo-root> [lat lng]
"""
import heapq
import json
import math
import sys

root = sys.argv[1]
start = (float(sys.argv[2]), float(sys.argv[3])) if len(sys.argv) > 3 else (-6.8905811, 107.6097754)
R = 6371008.8


def hav(a, b):
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    dp, dl = p2 - p1, math.radians(b[1] - a[1])
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))


def lines(path):
    for f in json.load(open(path))['features']:
        cs = f['geometry']['coordinates']
        yield [(c[1], c[0]) for c in cs]


segs = []
for name in ('ganesha-walk-demo', 'passages', 'corridors'):
    for pts in lines(f'{root}/assets/routing/{name}.geojson'):
        for a, b in zip(pts, pts[1:]):
            if a != b:
                segs.append((a, b))

# Largest connected piece by total length (union-find).
parent = {}


def find(x):
    parent.setdefault(x, x)
    while parent[x] != x:
        parent[x] = parent[parent[x]]
        x = parent[x]
    return x


for a, b in segs:
    ra, rb = find(a), find(b)
    if ra != rb:
        parent[ra] = rb
length = {}
for a, b in segs:
    length[find(a)] = length.get(find(a), 0) + hav(a, b)
main = max(length, key=length.get)
segs = [s for s in segs if find(s[0]) == main]


def project(p, a, b):
    k = math.cos(math.radians(p[0]))
    ax, ay = (a[1] - p[1]) * k, a[0] - p[0]
    bx, by = (b[1] - p[1]) * k, b[0] - p[0]
    dx, dy = bx - ax, by - ay
    t = 0 if dx == dy == 0 else max(0, min(1, -(ax * dx + ay * dy) / (dx * dx + dy * dy)))
    q = (a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]))
    return hav(p, q), q, t


def snap(p):
    best = None
    for i, (a, b) in enumerate(segs):
        d, q, t = project(p, a, b)
        if d <= 25 and (best is None or d < best[0]):
            best = (d, q, i)
    return best


def shortest(p, q):
    """Network distance p->q (both snapped), plus the two snap legs."""
    sp, sq = snap(p), snap(q)
    if not sp or not sq:
        return None
    graph = {}

    def add(u, v):
        w = hav(u, v)
        graph.setdefault(u, []).append((v, w))
        graph.setdefault(v, []).append((u, w))

    for i, (a, b) in enumerate(segs):
        cuts = [a, b]
        for s in (sp, sq):
            if s[2] == i:
                cuts.append(s[1])
        cuts.sort(key=lambda c: hav(a, c))
        for u, v in zip(cuts, cuts[1:]):
            if u != v:
                add(u, v)
    dist = {sp[1]: 0}
    heap = [(0, sp[1])]
    while heap:
        d, u = heapq.heappop(heap)
        if u == sq[1]:
            return sp[0], d, sq[0]
        if d > dist[u]:
            continue
        for v, w in graph.get(u, []):
            if d + w < dist.get(v, math.inf):
                dist[v] = d + w
                heapq.heappush(heap, (d + w, v))
    return None


pois = {p['name']: p for p in json.load(open(f'{root}/assets/data/pois.json'))['pois']}
targets = [(e['lat'], e['lng']) for e in pois['Labtek VII']['entrances']]
doors = [(e['label'], (e['lat'], e['lng'])) for e in pois['Labtek V']['entrances']]

options = []
for t in targets:
    r = shortest(start, t)
    if r:
        leg, net, end = r
        options.append(('snap', leg, leg + net + end))
    for label, door in doors:
        r = shortest(door, t)
        if r:
            leg = hav(start, door)
            options.append((label, leg, leg + r[0] + r[1] + r[2]))
plain = min(options, key=lambda o: o[2])
weighted = min(options, key=lambda o: o[2] + o[1])  # off-network leg counted twice
print('shortest total  :', plain[0], 'leg %.1f total %.1f' % (plain[1], plain[2]))
print('weighted choice :', weighted[0], 'leg %.1f total %.1f' % (weighted[1], weighted[2]))
