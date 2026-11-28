"""Ekstrak way OSM yang menyentuh cakupan kampus beserta node dan relasi."""
import argparse
from pathlib import Path

import osmium

from tile_pipeline import check_hash, load_boundary

SOURCE_SHA = "091e9183554ac4a91b399726dd85e6d1050ea4fe4b1f0b772962c3764a195d3c"
HERE = Path(__file__).resolve().parent


def extract(source, destination):
    check_hash(source, SOURCE_SHA)
    bounds, _ = load_boundary(HERE / "campus-boundary.json")
    area = osmium.osm.Box(osmium.osm.Location(*bounds[:2]), osmium.osm.Location(*bounds[2:]))
    selected = osmium.IdTracker()
    with osmium.BackReferenceWriter(destination, source, remove_tags=False) as output:
        for node in osmium.FileProcessor(source, osmium.osm.NODE):
            if area.contains(node.location):
                selected.add_node(node.id)
                if node.tags:
                    output.add_node(node)
        ways = osmium.FileProcessor(source, osmium.osm.WAY).with_filter(selected.contains_filter())
        for way in ways:
            selected.add_way(way.id)
            output.add_way(way)
        relations = osmium.FileProcessor(source, osmium.osm.RELATION).with_filter(selected.contains_filter())
        for rel in relations:
            if rel.tags.get("type") in {"multipolygon", "restriction"}:
                output.add_relation(rel)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    extract(args.source, args.destination)
