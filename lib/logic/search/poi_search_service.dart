import 'dart:async';

import '../../contracts/contracts.dart';

/// Searches the current on-device dataset, including verified facilities when
/// the content team supplies them.
class PoiSearchService implements SearchService {
  const PoiSearchService({required this.pois, this.onSearch});

  final PoiRepository pois;
  final void Function()? onSearch;

  static const _romanNumerals = {
    'i': '1',
    'ii': '2',
    'iii': '3',
    'iv': '4',
    'v': '5',
    'vi': '6',
    'vii': '7',
    'viii': '8',
    'ix': '9',
    'x': '10',
    'xi': '11',
  };

  @override
  Future<List<SearchResult>> search(
    String query, {
    Set<FacilityCategory>? facilityCategories,
    bool includePois = true,
  }) async {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return const [];
    onSearch?.call();
    final (availablePois, availableFacilities) = await (
      includePois ? pois.watchPois().first : Future.value(const <Poi>[]),
      (facilityCategories?.isNotEmpty ?? true)
          ? pois.watchFacilities().first
          : Future.value(const <Facility>[]),
    ).wait;
    final results = <SearchResult>[];
    if (includePois) {
      for (final poi in availablePois) {
        var score = _score(poi.name, normalizedQuery);
        for (final alias in poi.aliases) {
          final aliasScore = _score(alias, normalizedQuery);
          if (aliasScore > score) score = aliasScore;
        }
        if (score > 0) {
          results.add(
            SearchResult(
              kind: SearchResultKind.poi,
              id: poi.id,
              name: poi.name,
              score: score,
            ),
          );
        }
      }
    }
    if (facilityCategories?.isNotEmpty ?? true) {
      for (final facility in availableFacilities) {
        if (!facility.metadata.approved ||
            facility.metadata.isPlaceholder ||
            !(facilityCategories?.contains(facility.category) ?? true)) {
          continue;
        }
        final score = _score(facility.name, normalizedQuery);
        if (score > 0) {
          results.add(
            SearchResult(
              kind: SearchResultKind.facility,
              id: facility.id,
              name: facility.name,
              score: score,
            ),
          );
        }
      }
    }
    results.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      final kind = a.kind.index.compareTo(b.kind.index);
      return kind == 0 ? a.id.compareTo(b.id) : kind;
    });
    return results;
  }

  static double _score(String text, String query) {
    final candidate = _normalize(text);
    if (candidate == query) return 1;
    if (candidate.startsWith(query)) return 0.8;
    if (candidate.contains(query)) return 0.5;
    return 0;
  }

  static String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9& ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .map((token) => _romanNumerals[token] ?? token)
      .join(' ');
}
