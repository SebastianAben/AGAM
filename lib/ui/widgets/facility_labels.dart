import 'package:flutter/material.dart';

import '../../contracts/models/content.dart';
import '../../contracts/models/discovery.dart';

/// Facility categories in the order the map chips and the search page show.
const facilityCategories = [
  FacilityCategory.toilet,
  FacilityCategory.musala,
  FacilityCategory.kantin,
  FacilityCategory.atm,
  FacilityCategory.perpustakaan,
  FacilityCategory.layananAkademik,
];

IconData facilityIcon(FacilityCategory category) => switch (category) {
  FacilityCategory.toilet => Icons.wc_rounded,
  FacilityCategory.musala => Icons.mosque,
  FacilityCategory.kantin => Icons.restaurant_rounded,
  FacilityCategory.atm => Icons.atm_rounded,
  FacilityCategory.perpustakaan => Icons.local_library_rounded,
  FacilityCategory.layananAkademik => Icons.school_rounded,
};

String facilityName(FacilityCategory category) => switch (category) {
  FacilityCategory.toilet => 'Toilet',
  FacilityCategory.musala => 'Musala',
  FacilityCategory.kantin => 'Kantin',
  FacilityCategory.atm => 'ATM',
  FacilityCategory.perpustakaan => 'Perpustakaan',
  FacilityCategory.layananAkademik => 'Layanan akademik',
};

/// The nearest facility of each category, nearest first, at most [max].
///
/// [byDistance] must be sorted nearest first, as `FacilityService.nearby`
/// returns it. Without this, the closest few are often all toilets and the
/// sheet never mentions the nearest prayer room or canteen.
List<Facility> nearestPerCategory(
  List<FacilityDistance> byDistance, {
  int max = 4,
}) {
  final seen = <FacilityCategory>{};
  return [
    for (final item in byDistance)
      if (seen.add(item.facility.category)) item.facility,
  ].take(max).toList();
}
