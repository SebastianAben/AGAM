import 'dart:convert';
import 'dart:io';

import 'package:agam/contracts/contracts.dart';
import 'package:agam/logic/data/poi_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeoPoint.distanceTo', () {
    // Nilai acuan dihitung terpisah dengan Python (rumus haversine, R = 6371 km).
    test('Oktagon ke TVST ±49,39 m', () {
      const oktagon = GeoPoint(-6.8890603, 107.6100470);
      const tvst = GeoPoint(-6.8895043, 107.6100594);
      expect(oktagon.distanceTo(tvst), closeTo(49.3895, 0.01));
    });

    test('Labtek V ke Labtek VI ±49,94 m', () {
      const labtek5 = GeoPoint(-6.8905811, 107.6097754);
      const labtek6 = GeoPoint(-6.8901358, 107.6097167);
      expect(labtek5.distanceTo(labtek6), closeTo(49.9373, 0.01));
    });

    test('GKUB ke GKUT ±342,47 m', () {
      const gkub = GeoPoint(-6.89053, 107.60890);
      const gkut = GeoPoint(-6.8903881, 107.6119990);
      expect(gkub.distanceTo(gkut), closeTo(342.4679, 0.01));
    });
  });

  test('CampusArea.contains membedakan titik di dalam dan di luar', () {
    const area = CampusArea(
      polygon: [
        GeoPoint(-6.892, 107.607),
        GeoPoint(-6.892, 107.614),
        GeoPoint(-6.887, 107.614),
        GeoPoint(-6.887, 107.607),
      ],
    );
    expect(area.contains(const GeoPoint(-6.890, 107.610)), isTrue);
    expect(area.contains(const GeoPoint(-6.900, 107.610)), isFalse);
  });

  test('TrailProgress menghitung kunjungan di luar urutan', () {
    const progress = TrailProgress(
      order: ['P01', 'P02', 'P03'],
      visited: {'P02'},
      active: true,
    );
    expect(progress.visitedCount, 1);
    expect(progress.nextPoiId, 'P01');
    expect(progress.isComplete, isFalse);
  });

  group('NavigationTarget.facility', () {
    const approvedMeta = ContentMetadata(
      sources: ['SINTETIS'],
      verifiedAt: null,
      owner: 'SINTETIS',
      assetAttribution: [],
      approved: true,
    );
    const door1 = GeoPoint(0, 0.001);
    const door2 = GeoPoint(0.001, 0.001);
    const center = GeoPoint(0.0005, 0.0005);

    Poi buildingPoi(String id, List<PoiEntrance> entrances) => Poi(
      id: id,
      name: 'Gedung SINTETIS',
      aliases: const [],
      category: PoiCategory.lecture,
      position: center,
      radiusM: 15,
      entrances: entrances,
      description: 'SINTETIS',
      function: 'SINTETIS',
      facilities: const [],
      trivia: 'SINTETIS',
      media: const PoiMedia(),
      metadata: approvedMeta,
    );

    test('memakai titik akses gedung dan ekstrak locationHint untuk fasilitas dalam gedung', () {
      const indoor = Facility(
        id: 'F-SYN-INDOOR',
        name: 'Perpustakaan SINTETIS',
        category: FacilityCategory.perpustakaan,
        position: center,
        buildingId: 'P01',
        description: 'Labtek V, lantai 3. Titik peta memakai titik gedung; letak persis di dalam gedung belum disurvei.',
        metadata: approvedMeta,
      );
      final building = buildingPoi('P01', const [
        PoiEntrance(position: door1, label: 'Pintu 1'),
        PoiEntrance(position: door2, label: 'Pintu 2'),
      ]);

      final target = NavigationTarget.facility(indoor, building: building);
      expect(target.point, door1);
      expect(target.candidates, [door1, door2]);
      expect(target.isPlaceholderPoint, isTrue);
      expect(target.locationHint, 'Labtek V, lantai 3');
    });

    test(
      'mengabaikan building bila buildingId tidak cocok atau entrances kosong',
      () {
        const indoor = Facility(
          id: 'F-SYN-MISMATCH',
          name: 'Toilet SINTETIS',
          category: FacilityCategory.toilet,
          position: center,
          buildingId: 'P01',
          description: 'Di dalam Labtek V. Titik peta memakai titik gedung; belum disurvei.',
          metadata: approvedMeta,
        );
        final wrongBuilding = buildingPoi('P02', const [
          PoiEntrance(position: door1, label: 'Pintu lain'),
        ]);
        final noDoors = buildingPoi('P01', const []);

        final mismatch = NavigationTarget.facility(
          indoor,
          building: wrongBuilding,
        );
        expect(mismatch.point, center);
        expect(mismatch.candidates, isEmpty);
        expect(mismatch.isPlaceholderPoint, isTrue);
        expect(mismatch.locationHint, 'Di dalam Labtek V');

        final emptyDoors = NavigationTarget.facility(indoor, building: noDoors);
        expect(emptyDoors.point, center);
        expect(emptyDoors.candidates, isEmpty);
        expect(emptyDoors.isPlaceholderPoint, isTrue);
      },
    );

    test(
      'menjaga perilaku fasilitas luar ruangan dan menandai belum diverifikasi',
      () {
        const outdoorUnverified = Facility(
          id: 'F-SYN-ATM',
          name: 'ATM SINTETIS',
          category: FacilityCategory.atm,
          position: center,
          description: 'Di antara GKUB dan Labtek V. Titik ditandai pengguna pada peta AGAM, 24 November 2026; belum diverifikasi lapangan.',
          metadata: approvedMeta,
        );
        final target = NavigationTarget.facility(outdoorUnverified);
        expect(target.point, center);
        expect(target.candidates, isEmpty);
        expect(target.isPlaceholderPoint, isTrue);
        expect(target.locationHint, 'Di antara GKUB dan Labtek V');

        const outdoorVerified = Facility(
          id: 'F-SYN-VERIFIED',
          name: 'Kios SINTETIS',
          category: FacilityCategory.kantin,
          position: center,
          description: 'Di samping gerbang selatan.',
          metadata: approvedMeta,
        );
        final verifiedTarget = NavigationTarget.facility(outdoorVerified);
        expect(verifiedTarget.isPlaceholderPoint, isFalse);
        expect(verifiedTarget.locationHint, 'Di samping gerbang selatan');
      },
    );

    test('seluruh 26 fasilitas dataset bawaan menghasilkan target dan petunjuk bersih', () {
      final dataset = decodePoiDataset(
        jsonDecode(File('assets/data/pois.json').readAsStringSync()),
      );
      final poiById = {for (final poi in dataset.pois) poi.id: poi};

      for (final facility in dataset.facilities) {
        final building = facility.buildingId == null
            ? null
            : poiById[facility.buildingId];
        final target = NavigationTarget.facility(facility, building: building);
        expect(target.locationHint, isNotNull, reason: facility.id);
        expect(
          target.locationHint!.toLowerCase(),
          isNot(contains('titik peta')),
          reason: facility.id,
        );
        expect(
          target.locationHint!.toLowerCase(),
          isNot(contains('titik ditandai')),
          reason: facility.id,
        );
        expect(target.isPlaceholderPoint, isTrue, reason: facility.id);
        if (building != null && building.entrances.isNotEmpty) {
          expect(target.point, building.navigationPoint, reason: facility.id);
          expect(
            target.candidates,
            building.entrances.map((e) => e.position).toList(),
            reason: facility.id,
          );
        } else {
          expect(target.point, facility.position, reason: facility.id);
          expect(target.candidates, isEmpty, reason: facility.id);
        }
      }
    });
  });

  test('NavigationState.currentStep mendahulukan activeStep bila tersedia', () {
    const step0 = RouteStep(
      maneuver: Maneuver.depart,
      instruction: 'Ikuti jalur pejalan kaki.',
      distanceM: 50,
      position: GeoPoint(0, 0),
    );
    const straight = RouteStep(
      maneuver: Maneuver.straight,
      instruction: 'Lanjut lurus.',
      distanceM: 40,
      position: GeoPoint(0, 0),
    );
    const route = WalkingRoute(
      path: [GeoPoint(0, 0), GeoPoint(0, 0.001)],
      distanceM: 50,
      eta: Duration(seconds: 40),
      steps: [step0],
    );

    const normal = NavigationState(
      status: NavigationStatus.onRoute,
      route: route,
      currentStepIndex: 0,
    );
    expect(normal.currentStep, same(step0));

    const cruising = NavigationState(
      status: NavigationStatus.onRoute,
      route: route,
      currentStepIndex: 0,
      activeStep: straight,
    );
    expect(cruising.currentStep, same(straight));
  });
}
