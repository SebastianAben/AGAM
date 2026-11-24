"""Master GeoPackage WGS84 dari ekstrak OSM yang telah diperiksa dan POI PRD."""
from collections import Counter, defaultdict
from pathlib import Path
import json

import fiona
import osmium
from shapely import STRtree, from_wkb
from shapely.geometry import Point, LineString, box, mapping

from extract_campus import HERE
from tile_pipeline import load_boundary

LAYERS = {"building": "Polygon", "green": "Polygon", "transportation": "LineString",
          "walk": "LineString", "sidewalk": "LineString", "gate": "Point",
          "crossing": "Point", "poi": "Point", "label": "Point"}
WALK_TYPES = {"footway", "path", "pedestrian", "steps", "living_street"}
LOCAL_ROADS = {"service", "residential", "unclassified"}
ALLOWED = {"yes", "designated", "permissive", "official"}


def denied(tags):
    return (tags.get("foot", tags.get("access", "yes")) not in ALLOWED
            or "opening_hours" in tags
            or any(k.startswith(("foot:", "access:conditional", "oneway:foot:")) for k in tags))


def walkable(tags):
    road = tags.get("highway")
    dedicated = road in WALK_TYPES
    local = road in LOCAL_ROADS and tags.get("foot") in ALLOWED
    foot_direction = tags.get("oneway:foot", tags.get("oneway", "no") if dedicated else "no")
    return ((dedicated or local)
            and not denied(tags) and foot_direction == "no"
            and tags.get("sidewalk") != "separate"
            and tags.get("construction", "no") == "no"
            and tags.get("barrier", "no") == "no"
            and tags.get("conveying", "no") == "no"
            and tags.get("layer", "0") == "0" and tags.get("level", "0") == "0"
            and all(tags.get(k, "no") == "no" for k in ("bridge", "tunnel", "indoor", "area")))


def parts(geometry, kind):
    if not geometry.is_empty:
        if geometry.geom_type == kind:
            yield geometry
        elif hasattr(geometry, "geoms"):
            for part in geometry.geoms:
                yield from parts(part, kind)


def create_master(extract, pois, out):
    bounds, _ = load_boundary(HERE / "campus-boundary.json")
    extent = box(*bounds)
    layers = defaultdict(list)
    blocked = set()
    node_ids = defaultdict(set)
    ways = []
    fences = []
    restricted_ways = set()
    gaps = Counter()

    def add(layer, geometry, identifier, kind, name=""):
        for part in parts(geometry.intersection(extent), LAYERS[layer]):
            layers[layer].append({"geometry": mapping(part), "properties": {
                "source_id": identifier, "kind": kind, "name": name}})

    factory = osmium.geom.WKBFactory()
    for obj in osmium.FileProcessor(extract).with_locations().with_areas():
        tags = dict(obj.tags)
        if obj.is_node():
            coord = (obj.location.lon, obj.location.lat)
            if not extent.covers(Point(coord)):
                continue
            node_ids[coord].add(obj.id)
            barrier = tags.get("barrier")
            if denied(tags) or (barrier and tags.get("foot") not in ALLOWED):
                blocked.add(obj.id)
            if barrier in {"gate", "lift_gate", "swing_gate", "kissing_gate"}:
                add("gate", Point(coord), f"node/{obj.id}", barrier)
            if tags.get("highway") == "crossing":
                add("crossing", Point(coord), f"node/{obj.id}", "crossing")
        elif obj.is_relation() and ("restriction:foot" in tags or "restriction:foot:conditional" in tags):
            restricted_ways.update(m.ref for m in obj.members if m.type == "w")
        elif obj.is_way() and tags.get("barrier") in {"fence", "wall", "hedge", "retaining_wall"}:
            if len(obj.nodes) > 1:
                fences.append(LineString([(n.lon, n.lat) for n in obj.nodes]))
        elif obj.is_way() and tags.get("highway"):
            refs = [(n.ref, (n.lon, n.lat)) for n in obj.nodes]
            if len(refs) < 2:
                continue
            can_walk = walkable(tags)
            if not can_walk or tags["highway"] in LOCAL_ROADS:
                add("transportation", LineString([p for _, p in refs]), f"way/{obj.id}",
                    tags["highway"], tags.get("name", ""))
            if can_walk:
                ways.append((obj.id, tags, refs))
            else:
                gaps["waysOutsideBidirectionalWalkPolicy"] += 1
        elif obj.is_area():
            layer = None
            if tags.get("building") and tags["building"] != "no":
                layer = "building"
            elif (tags.get("landuse") in {"grass", "forest", "meadow", "village_green"}
                  or tags.get("leisure") in {"park", "garden", "pitch"}
                  or tags.get("natural") in {"wood", "grassland", "scrub"}):
                layer = "green"
            if layer:
                geom = from_wkb(bytes.fromhex(factory.create_multipolygon(obj)))
                if geom.is_valid:
                    prefix = "way" if obj.from_way() else "relation"
                    add(layer, geom, f"{prefix}/{obj.orig_id()}", layer, tags.get("name", ""))

    # Satu fitur per pasangan node OSM. Loader hanya menghubungkan vertex
    # identik. Buang node ambigu, pembatas akses dan potongan tepi cakupan.
    counters = Counter()
    fence_index = STRtree(fences)
    for way_id, tags, refs in ways:
        for (a, p), (b, q) in zip(refs, refs[1:]):
            if (p == q or a in blocked or b in blocked or way_id in restricted_ways
                    or len(node_ids[p]) != 1 or len(node_ids[q]) != 1):
                gaps["edgesExcludedAtBoundaryBarrierOrAmbiguousNode"] += 1
                continue
            if len(fence_index.query(LineString([p, q]), predicate="intersects")):
                gaps["edgesTouchingMappedBarriers"] += 1
                continue
            key = (min(a, b), max(a, b))
            if counters[key]:
                continue
            counters[key] += 1
            kind = tags.get("footway", tags["highway"])
            add("walk", LineString([p, q]), f"way/{way_id}:{a}-{b}", kind, tags.get("name", ""))
            if kind == "sidewalk":
                add("sidewalk", LineString([p, q]), f"way/{way_id}", kind)
    for poi in json.loads(Path(pois).read_text(encoding="utf-8"))["pois"]:
        for layer in ("poi", "label"):
            add(layer, Point(poi["lng"], poi["lat"]), poi["id"], "poi", poi["name"])
    for layer, kind in LAYERS.items():
        schema = {"geometry": kind, "properties": {"source_id": "str", "kind": "str", "name": "str"}}
        with fiona.Env(OGR_CURRENT_DATE="2026-11-03T21:24:23.000Z"):
            with fiona.open(out, "w", driver="GPKG", crs="EPSG:4326", layer=layer, schema=schema) as sink:
                sink.writerecords(layers[layer])
    return dict(gaps)
