"""Ekspor PMTiles dan graf demo dari satu GeoPackage. Semua koordinat lokal."""
import argparse
from collections import defaultdict
import gzip
import json
from pathlib import Path
from tempfile import TemporaryDirectory

import fiona
import mapbox_vector_tile
import mercantile
from pmtiles.tile import Compression, TileType, zxy_to_tileid
from pmtiles.writer import Writer
from shapely.affinity import translate
from shapely.geometry import Polygon, shape, box, mapping
from shapely.ops import transform, unary_union

from campus_master import LAYERS, parts
from cluster_pmtiles import cluster_archive
from extract_campus import HERE, SOURCE_SHA
from tile_pipeline import OSM_URL, digest, load_boundary, publish, validate_pmtiles

ROOT = HERE.parents[1]
MIN_Z, MAX_Z = 12, 18
DEPTH_MIN_Z = 17
DEPTH_LAYERS = ("building_shadow", "building_wall", "building_roof")
STATUS = "draft — belum diverifikasi lapangan"
CREDIT = ('<a href="https://www.openstreetmap.org/copyright">© OpenStreetMap contributors (ODbL)</a> '
          '<a href="https://openmaptiles.org/">© OpenMapTiles</a>')


def read_layers(master, bounds):
    features = {}
    extent = box(*bounds)
    for layer, kind in LAYERS.items():
        with fiona.open(master, layer=layer) as src:
            if src.crs.to_epsg() != 4326:
                raise ValueError(f"CRS layer {layer} harus EPSG:4326.")
            values = []
            for row in src:
                geometry = shape(row.geometry)
                if (geometry.geom_type != kind or geometry.is_empty or not geometry.is_valid
                        or not extent.covers(geometry) or not row.properties["source_id"]):
                    raise ValueError(f"Geometri atau sumber tidak valid pada {layer}.")
                values.append((geometry, dict(row.properties)))
            features[layer] = values
    return features


def graph_from_walk(walk):
    links = defaultdict(set)
    features = []
    for line, props in walk:
        coords = list(line.coords)
        for a, b in zip(coords, coords[1:]):
            if a == b:
                raise ValueError("Ruas panjang nol.")
            links[a].add(b)
            links[b].add(a)
        features.append({"type": "Feature", "properties": props, "geometry": mapping(line)})
    if not links:
        raise ValueError("Graf jalur kosong.")
    unseen = set(links)
    sizes = []
    while unseen:
        queue = [unseen.pop()]
        count = 0
        while queue:
            node = queue.pop()
            count += 1
            for neighbour in links[node]:
                if neighbour in unseen:
                    unseen.remove(neighbour)
                    queue.append(neighbour)
        sizes.append(count)
    return ({"type": "FeatureCollection", "status": STATUS, "sourceSha256": SOURCE_SHA,
             "features": features}, {"vertices": len(links), "edges": sum(map(len, links.values())) // 2,
                                      "componentSizes": sorted(sizes, reverse=True)})


def write_tiles(path, features, bounds, graph_hash):
    # Renderer menangani label POI interaktif secara terpisah.
    projected = {name: [(transform(mercantile.xy, geom), props) for geom, props in rows]
                 for name, rows in features.items() if name not in {"sidewalk", "label"} and rows}
    kinds = dict(LAYERS)
    for name in DEPTH_LAYERS:
        projected[name] = []
        kinds[name] = "Polygon"
    for footprint, props in projected.get("building", []):
        # Offset grafis dalam koordinat proyeksi, tanpa asumsi tinggi gedung.
        dx, dy = -1.6, 3.4
        roof = translate(footprint, dx, dy)
        walls = []
        for ring in (footprint.exterior, *footprint.interiors):
            coords = list(ring.coords)
            for (ax, ay), (bx, by) in zip(coords, coords[1:]):
                wall = Polygon([(ax, ay), (bx, by), (bx + dx, by + dy), (ax + dx, ay + dy)])
                if wall.is_valid and wall.area > 0:
                    walls.append(wall)
        projected["building_shadow"].append((translate(footprint, 3, -2), props))
        projected["building_roof"].append((roof, props))
        projected["building_wall"].append((unary_union([footprint, roof, *walls]), props))
    tiles = sorted(mercantile.tiles(*bounds, range(MIN_Z, MAX_Z + 1)),
                   key=lambda t: zxy_to_tileid(t.z, t.x, t.y))
    with path.open("wb") as stream:
        writer = Writer(stream)
        for tile in tiles:
            xy = mercantile.xy_bounds(tile)
            clip = box(*xy)
            layers = []
            for name, rows in projected.items():
                if tile.z < DEPTH_MIN_Z and name in DEPTH_LAYERS:
                    continue
                if tile.z >= DEPTH_MIN_Z and name == "building":
                    continue
                data = []
                for geom, props in rows:
                    if not clip.intersects(geom):
                        continue
                    for part in parts(geom.intersection(clip), kinds[name]):
                        data.append({"geometry": part, "properties": props})
                if data:
                    layers.append({"name": name, "features": data})
            if layers:
                payload = mapbox_vector_tile.encode(layers, default_options={"quantize_bounds": tuple(xy)})
                writer.write_tile(zxy_to_tileid(tile.z, tile.x, tile.y), gzip.compress(payload, mtime=0))
        header = dict(zip(("min_lon_e7", "min_lat_e7", "max_lon_e7", "max_lat_e7"),
                          (round(c * 1e7) for c in bounds)))
        writer.finalize({**header, "tile_type": TileType.MVT, "tile_compression": Compression.GZIP},
                        {"name": "AGAM Ganesha", "attribution": CREDIT, "walkSha256": graph_hash,
                         "vector_layers": [{"id": name, "fields": {"source_id": "String", "kind": "String",
                                            "name": "String"}} for name in projected]})
    cluster_archive(path)


def export(master, root):
    bounds, boundary = load_boundary(HERE / "campus-boundary.json")
    rows = read_layers(master, bounds)
    graph, topology = graph_from_walk(rows["walk"])
    with TemporaryDirectory(dir=root, prefix=".ganesha-export-") as tmp:
        stage = Path(tmp)
        graph_path = stage / "ganesha-walk-demo.geojson"
        graph_path.write_text(json.dumps(graph, ensure_ascii=False, separators=(",", ":")) + "\n",
                              encoding="utf-8", newline="\n")
        archive = stage / "ganesha.pmtiles"
        graph_hash = digest(graph_path)
        write_tiles(archive, rows, bounds, graph_hash)
        output = validate_pmtiles(archive, bounds, max_zoom=MAX_Z)
        manifest = {"schemaVersion": 2, "generator": "AGAM GeoPackage → MVT + GeoJSON",
                    "status": STATUS, "source": {"url": OSM_URL, "sha256": SOURCE_SHA,
                    "replicationTimestamp": "2026-11-03T21:24:23Z"}, "boundary": boundary,
                    "requestedBounds": bounds, "sourceLicense": "ODbL-1.0", "attribution": CREDIT,
                    "masterSha256": digest(master), "layers": {k: len(v) for k, v in rows.items()},
                    "graph": {"filename": graph_path.name, "sha256": graph_hash, **topology},
                    "output": {"filename": archive.name, **output}}
        manifest_path = stage / "ganesha.manifest.json"
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
                                 encoding="utf-8", newline="\n")
        paths = [(graph_path, root / "assets/routing" / graph_path.name),
                 (archive, root / "assets/map" / archive.name),
                 (manifest_path, root / "assets/map" / manifest_path.name)]
        for _, dest in paths:
            dest.parent.mkdir(parents=True, exist_ok=True)
        publish(paths, force=True)
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--master", type=Path, default=HERE / "ganesha.gpkg")
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    result = export(args.master, args.root)
    print(result["layers"], result["graph"], result["output"]["addressedTiles"])
