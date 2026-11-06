import 'package:dio/dio.dart';

/// The AsoulTappo save linked to a main-site account, as its server reports.
class TappoProgress {
  const TappoProgress({
    required this.shards,
    required this.owned,
    required this.items,
    required this.legendaryPity,
    required this.legendaryHard,
    required this.skinPity,
    required this.skinHard,
    required this.draws,
  });
  final int shards;
  final int owned;
  final int items;
  final int legendaryPity;
  final int legendaryHard;
  final int skinPity;
  final int skinHard;
  final int draws;
}

/// AsoulTappo's own server, which accepts the main-site token. Read only:
/// `api/account` says whether a save is linked without creating one.
class TappoApi {
  TappoApi(this.dio);
  final Dio dio;

  static final base = Uri.parse('https://len5010.top/tappo/');

  /// The main site's download page, which also serves the installer from
  /// China; GitHub is one of its sources.
  static final downloads = Uri.parse('https://len5010.top/download?app=tappo');

  Future<Map<String, dynamic>> _get(String path, String token) async {
    final response = await dio.get<Map<String, dynamic>>(
      base.resolve(path).toString(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return response.data ?? const {};
  }

  /// Null when the account has no AsoulTappo save yet.
  Future<TappoProgress?> progress(String token) async {
    final account = await _get('api/account', token);
    if (account['save'] == null) return null;
    final me = await _get('api/me', token);
    final resonance = me['resonance'] as Map<String, dynamic>;
    final pity = resonance['pity'] as Map<String, dynamic>;
    final hard = resonance['hardPity'] as Map<String, dynamic>;
    final totals = me['totals'] as Map<String, dynamic>;
    int number(Object? value) => (value as num).floor();
    return TappoProgress(
      shards: number(me['shards']),
      owned: number(totals['owned']),
      items: number(totals['items']),
      legendaryPity: number(pity['legendary']),
      legendaryHard: number(hard['legendary']),
      skinPity: number(pity['skin']),
      skinHard: number(hard['skin']),
      draws: number(resonance['total']),
    );
  }
}
