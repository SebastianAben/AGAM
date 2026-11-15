import '../../contracts/contracts.dart';

/// Pencarian sementara untuk demo yang memakai POI dari repository aktif.
/// Hasil hanya berisi POI; layanan ini tidak mengarang fasilitas atau rute.
class PoiSearchService implements SearchService {
  const PoiSearchService({required this.pois});

  final PoiRepository pois;

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
    if (!includePois || normalizedQuery.isEmpty) return const [];

    final availablePois = await pois.watchPois().first;
    final results = <SearchResult>[];
    for (final poi in availablePois) {
      var score = 0.0;
      for (final candidate in [poi.name, ...poi.aliases]) {
        final normalizedCandidate = _normalize(candidate);
        final candidateScore = normalizedCandidate == normalizedQuery
            ? 1.0
            : normalizedCandidate.startsWith(normalizedQuery)
            ? 0.8
            : normalizedCandidate.contains(normalizedQuery)
            ? 0.5
            : 0.0;
        if (candidateScore > score) score = candidateScore;
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
    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9& ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .map((token) => _romanNumerals[token] ?? token)
      .join(' ');
}
