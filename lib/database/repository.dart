import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/recommendation.dart';
import '../models/profile.dart';
import '../models/chat.dart';
import '../models/saved_item.dart';
import '../models/delight.dart';
import 'app_database.dart';

class AppRepository {
  final AppDatabase _db = AppDatabase.instance;

  // ============ Behavior Events ============
  Future<void> insertEvent(BehaviorEvent event) async {
    final db = await _db.database;
    await db.insert(
      'behavior_events',
      {
        'event_id': event.eventId,
        'event_type': event.eventType,
        'source_platform': event.sourcePlatform,
        'content_id': event.contentId,
        'content_url': event.contentUrl,
        'title': event.title,
        'metadata': jsonEncode(event.metadata),
        'weight': event.weight,
        'created_at': event.createdAt.toIso8601String(),
        'processed': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BehaviorEvent>> getRecentEvents({int limit = 500, String? type}) async {
    final db = await _db.database;
    final where = type != null ? 'event_type = ?' : null;
    final args = type != null ? [type] : null;
    final rows = await db.query(
      'behavior_events',
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map((r) => BehaviorEvent(
      eventId: r['event_id'].toString(),
      eventType: r['event_type'].toString(),
      sourcePlatform: r['source_platform']?.toString() ?? '',
      contentId: r['content_id']?.toString() ?? '',
      contentUrl: r['content_url']?.toString() ?? '',
      title: r['title']?.toString() ?? '',
      metadata: jsonDecode(r['metadata']?.toString() ?? '{}'),
      createdAt: DateTime.parse(r['created_at'].toString()),
      weight: (r['weight'] as num?)?.toDouble() ?? 1.0,
    )).toList();
  }

  Future<int> getEventCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM behavior_events');
    return (result.first['c'] as num?)?.toInt() ?? 0;
  }

  // ============ Recommendation Pool ============
  Future<void> upsertRecommendation(Recommendation rec) async {
    final db = await _db.database;
    final map = rec.toJson();
    map['fetched_at'] = DateTime.now().toIso8601String();
    map.remove('id');
    await db.insert(
      'recommendation_pool',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertRecommendations(List<Recommendation> recs) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final rec in recs) {
      final map = rec.toJson();
      map['fetched_at'] = DateTime.now().toIso8601String();
      map.remove('id');
      batch.insert('recommendation_pool', map, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Recommendation>> getRecommendations({
    int limit = 50,
    String? sourcePlatform,
    double minMatchScore = 0,
  }) async {
    final db = await _db.database;
    final where = StringBuffer('1=1');
    final args = <Object?>[];
    if (sourcePlatform != null) {
      where.write(' AND source_platform = ?');
      args.add(sourcePlatform);
    }
    if (minMatchScore > 0) {
      where.write(' AND match_score >= ?');
      args.add(minMatchScore);
    }
    final rows = await db.query(
      'recommendation_pool',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'match_score DESC, freshness DESC, fetched_at DESC',
      limit: limit,
    );
    return rows.map((r) => Recommendation.fromJson(r)).toList();
  }

  Future<int> getPoolSize() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM recommendation_pool');
    return (result.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<void> updateRecommendationFeedback(String itemKey, String feedbackType) async {
    final db = await _db.database;
    await db.update(
      'recommendation_pool',
      {'feedback_type': feedbackType},
      where: 'item_key = ?',
      whereArgs: [itemKey],
    );
  }

  Future<void> incrementShowCount(String itemKey) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE recommendation_pool SET show_count = show_count + 1 WHERE item_key = ?',
      [itemKey],
    );
  }

  Future<void> cleanupOldPool({int maxAgeDays = 30, int maxRows = 500}) async {
    final db = await _db.database;
    final cutoff = DateTime.now().subtract(Duration(days: maxAgeDays)).toIso8601String();
    await db.delete('recommendation_pool', where: 'fetched_at < ?', whereArgs: [cutoff]);
    final count = await getPoolSize();
    if (count > maxRows) {
      await db.rawDelete('''
        DELETE FROM recommendation_pool WHERE id IN (
          SELECT id FROM recommendation_pool ORDER BY match_score ASC, fetched_at ASC LIMIT ?
        )
      ''', [count - maxRows]);
    }
  }

  // ============ User Profile ============
  Future<ProfileSummary> getProfile() async {
    final db = await _db.database;
    final row = await db.query('user_profile', where: 'id = 1', limit: 1);
    if (row.isEmpty) return const ProfileSummary();
    final r = row.first;
    return ProfileSummary(
      portrait: r['portrait']?.toString() ?? '',
      layers: _parseList(r['layers_json'], ProfileLayer.fromJson),
      deepNeeds: _parseStringList(r['deep_needs_json']),
      mbti: ProfileMbti.fromJson(_parseMap(r['mbti_json'])),
      values: _parseStringList(r['values_json']),
      motivationalDrivers: _parseStringList(r['motivational_drivers_json']),
      interests: _parseList(r['interests_json'], ProfileInterest.fromJson),
      avoidances: _parseList(r['avoidances_json'], ProfileInterest.fromJson),
      favoriteUpUsers: _parseStringList(r['favorite_up_users_json']),
      lifeStage: r['life_stage']?.toString() ?? '',
      currentPhase: r['current_phase']?.toString() ?? '',
      cognitiveStyle: _parseStringList(r['cognitive_style_json']),
      style: ProfileStyle.fromJson(_parseMap(r['style_json'])),
      context: ProfileContext.fromJson(_parseMap(r['context_json'])),
      explorationOpenness: (r['exploration_openness'] as num?)?.toDouble() ?? 0.5,
      speculativeInterests: _parseList(
        r['speculative_interests_json'],
        (j) => ProfileSpeculation.fromJson(j, avoidance: false),
      ),
      speculativeAvoidances: _parseList(
        r['speculative_avoidances_json'],
        (j) => ProfileSpeculation.fromJson(j, avoidance: true),
      ),
      cognitionUpdates: _parseList(r['cognition_updates_json'], ProfileCognitionUpdate.fromJson),
      activeInsights: _parseList(r['active_insights_json'], ProfileInsight.fromJson),
      recentAwareness: _parseList(r['recent_awareness_json'], ProfileAwareness.fromJson),
      overrides: _parseMap(r['overrides_json']),
      initialized: r['initialized'] == 1,
      updatedAt: r['updated_at'] != null ? DateTime.tryParse(r['updated_at'].toString()) : null,
    );
  }

  Future<void> saveProfile(ProfileSummary profile) async {
    final db = await _db.database;
    await db.update(
      'user_profile',
      {
        'portrait': profile.portrait,
        'layers_json': jsonEncode(profile.layers.map((e) => e.toJson()).toList()),
        'deep_needs_json': jsonEncode(profile.deepNeeds),
        'mbti_json': jsonEncode(profile.mbti.toJson()),
        'values_json': jsonEncode(profile.values),
        'motivational_drivers_json': jsonEncode(profile.motivationalDrivers),
        'interests_json': jsonEncode(profile.interests.map((e) => e.toJson()).toList()),
        'avoidances_json': jsonEncode(profile.avoidances.map((e) => e.toJson()).toList()),
        'favorite_up_users_json': jsonEncode(profile.favoriteUpUsers),
        'life_stage': profile.lifeStage,
        'current_phase': profile.currentPhase,
        'cognitive_style_json': jsonEncode(profile.cognitiveStyle),
        'style_json': jsonEncode(profile.style.toJson()),
        'context_json': jsonEncode(profile.context.toJson()),
        'exploration_openness': profile.explorationOpenness,
        'speculative_interests_json':
            jsonEncode(profile.speculativeInterests.map((e) => e.toJson()).toList()),
        'speculative_avoidances_json':
            jsonEncode(profile.speculativeAvoidances.map((e) => e.toJson()).toList()),
        'cognition_updates_json':
            jsonEncode(profile.cognitionUpdates.map((e) => e.toJson()).toList()),
        'active_insights_json': jsonEncode(profile.activeInsights.map((e) => e.toJson()).toList()),
        'recent_awareness_json':
            jsonEncode(profile.recentAwareness.map((e) => e.toJson()).toList()),
        'overrides_json': jsonEncode(profile.overrides),
        'initialized': profile.initialized ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
        'event_count': await getEventCount(),
      },
      where: 'id = 1',
    );
  }

  // ============ Chat ============
  Future<void> insertChatTurn(ChatTurn turn) async {
    final db = await _db.database;
    await db.insert(
      'chat_turns',
      {
        'turn_id': turn.turnId,
        'session': turn.session,
        'scope': turn.scope,
        'subject_id': turn.subjectId,
        'subject_title': turn.subjectTitle,
        'reply_to_turn_id': turn.replyToTurnId,
        'message': turn.message,
        'reply': turn.reply,
        'status': turn.status,
        'error': turn.error,
        'payload': jsonEncode(turn.payload),
        'role': turn.role,
        'created_at': turn.createdAt,
        'updated_at': turn.updatedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateChatTurn(ChatTurn turn) async {
    final db = await _db.database;
    await db.update(
      'chat_turns',
      {
        'reply': turn.reply,
        'status': turn.status,
        'error': turn.error,
        'payload': jsonEncode(turn.payload),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'turn_id = ?',
      whereArgs: [turn.turnId],
    );
  }

  Future<List<ChatTurn>> getChatHistory({String session = 'main', int limit = 100}) async {
    final db = await _db.database;
    final rows = await db.query(
      'chat_turns',
      where: 'session = ?',
      whereArgs: [session],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map((r) => ChatTurn.fromJson(r)).toList();
  }

  // ============ Saved Items ============
  Future<void> saveItem(SavedItem item) async {
    final db = await _db.database;
    await db.insert(
      'saved_items',
      item.toJson()..['saved_at'] = item.savedAt.toIso8601String(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeItem(String itemKey, String listKind) async {
    final db = await _db.database;
    await db.delete(
      'saved_items',
      where: 'item_key = ? AND list_kind = ?',
      whereArgs: [itemKey, listKind],
    );
  }

  Future<List<SavedItem>> getSavedItems({required String listKind, int limit = 200}) async {
    final db = await _db.database;
    final rows = await db.query(
      'saved_items',
      where: 'list_kind = ?',
      whereArgs: [listKind],
      orderBy: 'saved_at DESC',
      limit: limit,
    );
    return rows.map((r) => SavedItem.fromJson(r)).toList();
  }

  Future<int> getSavedCount(String listKind) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM saved_items WHERE list_kind = ?',
      [listKind],
    );
    return (result.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<bool> isItemSaved(String itemKey, String listKind) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM saved_items WHERE item_key = ? AND list_kind = ?',
      [itemKey, listKind],
    );
    return ((result.first['c'] as num?)?.toInt() ?? 0) > 0;
  }

  // ============ Content History ============
  Future<void> upsertHistory(ContentHistoryItem item) async {
    final db = await _db.database;
    await db.insert(
      'content_history',
      item.toJson()..['event_at'] = item.eventAt.toIso8601String(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ContentHistoryItem>> getHistory({
    String? type,
    int limit = 100,
    int days = 30,
  }) async {
    final db = await _db.database;
    final where = StringBuffer('event_at >= ?');
    final args = <Object?>[
      DateTime.now().subtract(Duration(days: days)).toIso8601String(),
    ];
    if (type != null) {
      where.write(' AND history_type = ?');
      args.add(type);
    }
    final rows = await db.query(
      'content_history',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'event_at DESC',
      limit: limit,
    );
    return rows.map((r) => ContentHistoryItem.fromJson(r)).toList();
  }

  // ============ Delight Cards ============
  Future<void> insertDelight(DelightCard card) async {
    final db = await _db.database;
    await db.insert(
      'delight_cards',
      {
        'delight_id': card.delightId,
        'content_json': jsonEncode(card.content.toJson()),
        'reason': card.reason,
        'bridge_logic': card.bridgeLogic,
        'speculation_domain': card.speculationDomain,
        'speculation_confidence': card.speculationConfidence,
        'challenge_type': card.challengeType,
        'created_at': card.createdAt.toIso8601String(),
        'status': card.status,
        'ack_count': card.ackCount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DelightCard?> getPendingDelight() async {
    final db = await _db.database;
    final rows = await db.query(
      'delight_cards',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return DelightCard(
      delightId: r['delight_id'].toString(),
      content: Recommendation.fromJson(jsonDecode(r['content_json'].toString())),
      reason: r['reason']?.toString() ?? '',
      bridgeLogic: r['bridge_logic']?.toString() ?? '',
      speculationDomain: r['speculation_domain']?.toString() ?? '',
      speculationConfidence: (r['speculation_confidence'] as num?)?.toDouble() ?? 0,
      challengeType: r['challenge_type']?.toString() ?? 'interest',
      createdAt: DateTime.parse(r['created_at'].toString()),
      status: r['status']?.toString() ?? 'pending',
      ackCount: (r['ack_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> updateDelightStatus(String delightId, String status) async {
    final db = await _db.database;
    await db.update(
      'delight_cards',
      {'status': status, 'ack_count': 1},
      where: 'delight_id = ?',
      whereArgs: [delightId],
    );
  }

  // ============ Notifications ============
  Future<void> insertNotification(AppNotification notif) async {
    final db = await _db.database;
    await db.insert(
      'app_notifications',
      notif.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AppNotification>> getNotifications({int limit = 50, bool? unreadOnly}) async {
    final db = await _db.database;
    final where = unreadOnly == true ? 'read = 0' : null;
    final rows = await db.query(
      'app_notifications',
      where: where,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map((r) => AppNotification.fromJson(r)).toList();
  }

  Future<int> getUnreadCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM app_notifications WHERE read = 0');
    return (result.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<void> markNotificationRead(String id) async {
    final db = await _db.database;
    await db.update('app_notifications', {'read': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markAllRead() async {
    final db = await _db.database;
    await db.update('app_notifications', {'read': 1});
  }

  // ============ Pending Confirmations ============
  Future<void> upsertConfirmation(PendingConfirmation conf) async {
    final db = await _db.database;
    await db.insert(
      'pending_confirmations',
      conf.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PendingConfirmation>> getPendingConfirmations({int limit = 10}) async {
    final db = await _db.database;
    final rows = await db.query(
      'pending_confirmations',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map((r) => PendingConfirmation.fromJson(r)).toList();
  }

  Future<void> updateConfirmationStatus(String ref, String status) async {
    final db = await _db.database;
    await db.update(
      'pending_confirmations',
      {'status': status},
      where: 'ref = ?',
      whereArgs: [ref],
    );
  }

  // ============ Source Credentials ============
  Future<void> saveCredentials(String platform, String cookies, {String? token}) async {
    final db = await _db.database;
    await db.insert(
      'source_credentials',
      {
        'source_platform': platform,
        'cookies': cookies,
        'token': token ?? '',
        'logged_in': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getCredentials(String platform) async {
    final db = await _db.database;
    final rows = await db.query(
      'source_credentials',
      where: 'source_platform = ?',
      whereArgs: [platform],
      limit: 1,
    );
    if (rows.isEmpty) return {'cookies': '', 'token': ''};
    return {
      'cookies': rows.first['cookies']?.toString() ?? '',
      'token': rows.first['token']?.toString() ?? '',
    };
  }

  // ============ App Config ============
  Future<void> setConfig(String key, String value) async {
    final db = await _db.database;
    await db.insert(
      'app_config',
      {'key': key, 'value': value, 'updated_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getConfig(String key) async {
    final db = await _db.database;
    final rows = await db.query('app_config', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value']?.toString();
  }

  // ============ Helpers ============
  List<T> _parseList<T>(dynamic jsonStr, T Function(Map<String, dynamic>) parser) {
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr.toString()) as List;
      return list.map((e) => parser(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  List<String> _parseStringList(dynamic jsonStr) {
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr.toString()) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _parseMap(dynamic jsonStr) {
    if (jsonStr == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(jsonStr.toString()));
    } catch (_) {
      return {};
    }
  }
}
