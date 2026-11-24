"""Bangun ulang master dan kedua ekspor dari snapshot PBF Geofabrik terkunci."""
import argparse
from pathlib import Path
from tempfile import TemporaryDirectory

from campus_master import create_master
from export_campus import HERE, ROOT, export
from extract_campus import extract
from tile_pipeline import publish


def build(source):
    with TemporaryDirectory(dir=ROOT, prefix=".ganesha-build-") as tmp:
        stage = Path(tmp)
        subset = stage / "campus.osm.pbf"
        extract(source, subset)
        master = stage / "ganesha.gpkg"
        gaps = create_master(subset, ROOT / "assets/data/pois.json", master)
        manifest = export(master, stage)
        files = [(master, HERE / master.name)]
        for path in (stage / "assets").rglob("*"):
            if path.is_file():
                files.append((path, ROOT / path.relative_to(stage)))
        for _, dest in files:
            dest.parent.mkdir(parents=True, exist_ok=True)
        publish(files, force=True)
        print(manifest["layers"], manifest["graph"], gaps)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=HERE / ".cache/java-latest.osm.pbf")
    build(parser.parse_args().source)
