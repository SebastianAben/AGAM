"""Integritas aset sebenarnya dan batas kebijakan akses dengan tag sintetis."""
import json
from pmtiles.tile import tileid_to_zxy
import unittest

import fiona
import mapbox_vector_tile
import mercantile
from test_cluster_pmtiles import contents
from shapely.geometry import shape
from shapely.ops import transform, unary_union

from campus_master import walkable
from export_campus import HERE, MAX_Z, ROOT
from tile_pipeline import digest


class CampusExportTests(unittest.TestCase):
    def test_synthetic_access_rules(self):
        self.assertTrue(walkable({"highway": "footway"}))
        for tag, value in [("foot", "no"), ("access", "private"), ("barrier", "wall"),
                           ("oneway:foot", "-1"), ("access:conditional", "no @ night"),
                           ("tunnel", "yes"), ("layer", "1"), ("conveying", "forward"),
                           ("oneway", "yes"), ("opening_hours", "Mo-Fr"),
                           ("construction", "service"), ("sidewalk", "separate")]:
            with self.subTest(tag=tag):
                self.assertFalse(walkable({"highway": "footway", tag: value}))
        self.assertFalse(walkable({"highway": "primary", "foot": "yes"}))

    def test_bundled_graph_matches_master_and_decoded_max_zoom_tiles(self):
        graph = ROOT / "assets/routing/ganesha-walk-demo.geojson"
        graph_rows = json.loads(graph.read_text(encoding="utf-8"))["features"]
        expected = {r["properties"]["source_id"]: shape(r["geometry"]) for r in graph_rows}
        with fiona.open(HERE / "ganesha.gpkg", layer="walk") as master:
            self.assertEqual(len(master), len(graph_rows))
            for row in master:
                self.assertEqual(shape(row.geometry), expected[row.properties["source_id"]])
        tiles, metadata = contents(ROOT / "assets/map/ganesha.pmtiles")
        self.assertEqual(metadata["walkSha256"], digest(graph))
        segments = {}
        rendered_layers = set()
        for tile_id, payload in tiles.items():
            z, x, y = tileid_to_zxy(tile_id)
            if z != MAX_Z:
                continue
            decoded = mapbox_vector_tile.decode(payload)
            rendered_layers.update(decoded)
            layer = decoded.get("walk")
            if not layer:
                continue
            west, south, east, north = mercantile.xy_bounds(x, y, z)
            unit = (east - west) / layer["extent"]
            def meters(x, y):
                return west + x * unit, south + y * unit
            for row in layer["features"]:
                key = row["properties"]["source_id"]
                segments.setdefault(key, []).append(transform(meters, shape(row["geometry"])))
        self.assertEqual(set(expected), set(segments))
        self.assertTrue({"building_shadow", "building_wall", "building_roof"} <= rendered_layers)
        for key, source in expected.items():
            # Kuantisasi koordinat MVT maksimal setengah diagonal satu unit grid.
            self.assertLessEqual(transform(mercantile.xy, source).hausdorff_distance(
                unary_union(segments[key])), unit * 0.72, key)


if __name__ == "__main__":
    unittest.main()
