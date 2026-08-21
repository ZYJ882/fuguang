import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  static Database? _database;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'fuguang.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async {
        // journal_mode 会返回查询结果，Android SQLite 仅允许通过 rawQuery 执行此类 PRAGMA。
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE behavior_events (
        event_id TEXT PRIMARY KEY,
        event_type TEXT NOT NULL,
        source_platform TEXT DEFAULT '',
        content_id TEXT DEFAULT '',
        content_url TEXT DEFAULT '',
        title TEXT DEFAULT '',
        metadata TEXT DEFAULT '{}',
        weight REAL DEFAULT 1.0,
        created_at TEXT NOT NULL,
        processed INTEGER DEFAULT 0
      )
    ''');
    await db
        .execute('CREATE INDEX idx_events_type ON behavior_events(event_type)');
    await db.execute(
        'CREATE INDEX idx_events_created ON behavior_events(created_at)');
    await db.execute(
        'CREATE INDEX idx_events_content ON behavior_events(content_id)');

    await db.execute('''
      CREATE TABLE recommendation_pool (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bvid TEXT NOT NULL,
        item_key TEXT UNIQUE,
        content_id TEXT DEFAULT '',
        title TEXT DEFAULT '',
        up_name TEXT DEFAULT '',
        cover_url TEXT DEFAULT '',
        expression TEXT DEFAULT '',
        topic_label TEXT DEFAULT '',
        content_url TEXT DEFAULT '',
        source_platform TEXT DEFAULT 'bilibili',
        content_type TEXT DEFAULT 'video',
        body_text TEXT DEFAULT '',
        published_at TEXT DEFAULT '',
        published_label TEXT DEFAULT '',
        view_count INTEGER DEFAULT 0,
        like_count INTEGER DEFAULT 0,
        comment_count INTEGER DEFAULT 0,
        favorite_count INTEGER DEFAULT 0,
        danmaku_count INTEGER DEFAULT 0,
        rating_score REAL DEFAULT 0,
        rating_count INTEGER DEFAULT 0,
        source_rank INTEGER DEFAULT 0,
        duration INTEGER DEFAULT 0,
        tags TEXT DEFAULT '',
        feedback_type TEXT DEFAULT '',
        match_score REAL DEFAULT 0,
        recommend_reason TEXT DEFAULT '',
        fetched_at TEXT NOT NULL,
        freshness REAL DEFAULT 1.0,
        show_count INTEGER DEFAULT 0,
        click_count INTEGER DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_pool_source ON recommendation_pool(source_platform)');
    await db.execute(
        'CREATE INDEX idx_pool_match ON recommendation_pool(match_score)');
    await db.execute(
        'CREATE INDEX idx_pool_fresh ON recommendation_pool(freshness)');

    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        portrait TEXT DEFAULT '',
        layers_json TEXT DEFAULT '[]',
        deep_needs_json TEXT DEFAULT '[]',
        mbti_json TEXT DEFAULT '{}',
        values_json TEXT DEFAULT '[]',
        motivational_drivers_json TEXT DEFAULT '[]',
        interests_json TEXT DEFAULT '[]',
        avoidances_json TEXT DEFAULT '[]',
        favorite_up_users_json TEXT DEFAULT '[]',
        life_stage TEXT DEFAULT '',
        current_phase TEXT DEFAULT '',
        cognitive_style_json TEXT DEFAULT '[]',
        style_json TEXT DEFAULT '{}',
        context_json TEXT DEFAULT '{}',
        exploration_openness REAL DEFAULT 0.5,
        speculative_interests_json TEXT DEFAULT '[]',
        speculative_avoidances_json TEXT DEFAULT '[]',
        cognition_updates_json TEXT DEFAULT '[]',
        active_insights_json TEXT DEFAULT '[]',
        recent_awareness_json TEXT DEFAULT '[]',
        overrides_json TEXT DEFAULT '{}',
        initialized INTEGER DEFAULT 0,
        updated_at TEXT,
        event_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_turns (
        turn_id TEXT PRIMARY KEY,
        session TEXT DEFAULT 'main',
        scope TEXT DEFAULT 'chat',
        subject_id TEXT DEFAULT '',
        subject_title TEXT DEFAULT '',
        reply_to_turn_id TEXT DEFAULT '',
        message TEXT DEFAULT '',
        reply TEXT DEFAULT '',
        status TEXT DEFAULT 'pending',
        error TEXT DEFAULT '',
        payload TEXT DEFAULT '{}',
        role TEXT DEFAULT 'user',
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_chat_session ON chat_turns(session)');
    await db.execute('CREATE INDEX idx_chat_created ON chat_turns(created_at)');

    await db.execute('''
      CREATE TABLE saved_items (
        item_key TEXT PRIMARY KEY,
        source_platform TEXT DEFAULT '',
        content_id TEXT DEFAULT '',
        content_url TEXT DEFAULT '',
        content_type TEXT DEFAULT 'video',
        title TEXT DEFAULT '',
        author_name TEXT DEFAULT '',
        cover_url TEXT DEFAULT '',
        note TEXT DEFAULT '',
        list_kind TEXT NOT NULL,
        saved_at TEXT NOT NULL,
        updated_at TEXT,
        feedback_type TEXT DEFAULT '',
        synced_to_platform INTEGER DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_saved_kind ON saved_items(list_kind)');
    await db.execute('CREATE INDEX idx_saved_saved ON saved_items(saved_at)');

    await db.execute('''
      CREATE TABLE content_history (
        item_key TEXT PRIMARY KEY,
        source_platform TEXT DEFAULT '',
        content_id TEXT DEFAULT '',
        content_url TEXT DEFAULT '',
        content_type TEXT DEFAULT 'video',
        title TEXT DEFAULT '',
        author_name TEXT DEFAULT '',
        cover_url TEXT DEFAULT '',
        history_type TEXT DEFAULT 'impressed',
        event_at TEXT NOT NULL,
        impression_count INTEGER DEFAULT 0,
        click_count INTEGER DEFAULT 0,
        feedback_type TEXT DEFAULT '',
        recommend_reason TEXT DEFAULT '',
        match_score REAL DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_history_type ON content_history(history_type)');
    await db
        .execute('CREATE INDEX idx_history_event ON content_history(event_at)');

    await db.execute('''
      CREATE TABLE delight_cards (
        delight_id TEXT PRIMARY KEY,
        content_json TEXT NOT NULL,
        reason TEXT DEFAULT '',
        bridge_logic TEXT DEFAULT '',
        speculation_domain TEXT DEFAULT '',
        speculation_confidence REAL DEFAULT 0,
        challenge_type TEXT DEFAULT 'interest',
        created_at TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        ack_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE app_notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT DEFAULT '',
        data TEXT DEFAULT '{}',
        created_at TEXT NOT NULL,
        read INTEGER DEFAULT 0,
        action_status TEXT DEFAULT 'pending'
      )
    ''');
    await db.execute('CREATE INDEX idx_notif_read ON app_notifications(read)');
    await db.execute(
        'CREATE INDEX idx_notif_created ON app_notifications(created_at)');

    await db.execute('''
      CREATE TABLE pending_confirmations (
        ref TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        title TEXT DEFAULT '',
        observation TEXT DEFAULT '',
        interpretation TEXT DEFAULT '',
        evidence_json TEXT DEFAULT '[]',
        confidence REAL DEFAULT 0,
        created_at TEXT NOT NULL,
        status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE source_credentials (
        source_platform TEXT PRIMARY KEY,
        cookies TEXT DEFAULT '',
        token TEXT DEFAULT '',
        user_agent TEXT DEFAULT '',
        logged_in INTEGER DEFAULT 0,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE app_config (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.insert('user_profile', {
      'id': 1,
      'initialized': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
