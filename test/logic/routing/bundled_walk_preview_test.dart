import 'dart:convert';
import 'dart:io';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/routing/campus_routing_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final routing = CampusRoutingService.fromGeoJson(
    File('assets/routing/ganesha-walk-demo.geojson').readAsStringSync(),
    graphOnly: true,
  );
  final data = jsonDecode(File('assets/data/pois.json').readAsStringSync());
  final pois = {
    for (final poi in data['pois']) poi['id']: GeoPoint(poi['lat'], poi['lng']),
  };

  test(
    'Labtek VI ke VII berakhir di jalur, dengan jarak dan bobot konsisten',
    () async {
      final route = await routing.route(from: pois['P02']!, to: pois['P03']!);
      // Acuan terpisah dari graf GeoPackage, proyeksi lokal dan pencarian heap Python.
      expect(route.distanceM, closeTo(89.5, .2));
      expect(route.eta.inSeconds, 69);
      expect(route.path.first.distanceTo(pois['P02']!), closeTo(21.9, .2));
      expect(route.path.last.distanceTo(pois['P03']!), closeTo(16.1, .2));
      expect(route.steps.first.maneuver, Maneuver.depart);
      expect(
        route.steps.fold<double>(0, (sum, step) => sum + step.distanceM),
        closeTo(route.distanceM, .01),
      );
    },
  );

  test(
    'Labtek V ke VI hanya menempel ke jaringan utama, bukan selasar terpisah',
    () async {
      // Dulu pusat Labtek V menempel ke selasar terpisah sehingga rute gagal.
      // Acuan terpisah: komponen terpanjang graf, proyeksi lokal dan Dijkstra
      // heap Python.
      final route = await routing.route(from: pois['P01']!, to: pois['P02']!);
      expect(route.distanceM, closeTo(315.4, .2));
      expect(route.path.first.distanceTo(pois['P01']!), closeTo(22.9, .2));
      expect(route.path.last.distanceTo(pois['P02']!), closeTo(21.9, .2));
    },
  );
}
