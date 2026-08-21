import '../models/recommendation.dart';

abstract class ContentSource {
  String get platform;
  String get platformLabel;
  bool get requiresAuth;
  bool get isAvailable;

  Future<List<Recommendation>> fetchTrending({int limit = 30});
  Future<List<Recommendation>> fetchByCategory(String category, {int limit = 30});
  Future<List<Recommendation>> search(String query, {int limit = 20});
  Future<List<Recommendation>> fetchRelated(String contentId, {int limit = 10});
  Future<Recommendation?> getContentDetail(String contentId);
}

class SourceConfig {
  final String platform;
  final bool enabled;
  final int priority;
  final int dailyFetchLimit;
  final String? cookies;
  final String? token;

  const SourceConfig({
    required this.platform,
    this.enabled = true,
    this.priority = 5,
    this.dailyFetchLimit = 100,
    this.cookies,
    this.token,
  });

  SourceConfig copyWith({
    bool? enabled,
    int? priority,
    int? dailyFetchLimit,
    String? cookies,
    String? token,
  }) =>
      SourceConfig(
        platform: platform,
        enabled: enabled ?? this.enabled,
        priority: priority ?? this.priority,
        dailyFetchLimit: dailyFetchLimit ?? this.dailyFetchLimit,
        cookies: cookies ?? this.cookies,
        token: token ?? this.token,
      );
}
