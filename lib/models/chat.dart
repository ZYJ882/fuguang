import '../utils/app_utils.dart';

class ChatTurn {
  final String turnId;
  final String session;
  final String scope;
  final String subjectId;
  final String subjectTitle;
  final String replyToTurnId;
  final String message;
  final String reply;
  final String status; // pending, processing, done, error, failed
  final String error;
  final Map<String, dynamic> payload;
  final String createdAt;
  final String updatedAt;
  final String role; // user, assistant, system

  const ChatTurn({
    required this.turnId,
    this.session = 'main',
    this.scope = 'chat',
    this.subjectId = '',
    this.subjectTitle = '',
    this.replyToTurnId = '',
    this.message = '',
    this.reply = '',
    this.status = 'pending',
    this.error = '',
    this.payload = const {},
    this.createdAt = '',
    this.updatedAt = '',
    this.role = 'user',
  });

  factory ChatTurn.fromJson(Map<String, dynamic> json) => ChatTurn(
    turnId: json['turn_id']?.toString() ?? json['id']?.toString() ?? '',
    session: json['session']?.toString() ?? 'main',
    scope: json['scope']?.toString() ?? 'chat',
    subjectId: json['subject_id']?.toString() ?? '',
    subjectTitle: AppUtils.decodeHtml(json['subject_title']?.toString() ?? ''),
    replyToTurnId: json['reply_to_turn_id']?.toString() ?? '',
    message: AppUtils.decodeHtml(json['message']?.toString() ?? ''),
    reply: AppUtils.decodeHtml(
      (json['reply']?.toString() ?? '').isNotEmpty
          ? json['reply'].toString()
          : json['response']?.toString() ?? '',
    ),
    status: json['status']?.toString() ?? 'pending',
    error: AppUtils.decodeHtml(json['error']?.toString() ?? ''),
    payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload']) : const {},
    createdAt: json['created_at']?.toString() ?? '',
    updatedAt: json['updated_at']?.toString() ?? '',
    role: json['role']?.toString() ?? 'user',
  );

  Map<String, dynamic> toJson() => {
    'turn_id': turnId,
    'session': session,
    'scope': scope,
    'subject_id': subjectId,
    'subject_title': subjectTitle,
    'reply_to_turn_id': replyToTurnId,
    'message': message,
    'reply': reply,
    'status': status,
    'error': error,
    'payload': payload,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'role': role,
  };

  bool get isDone => const {'done', 'ok', 'completed'}.contains(status);
  bool get hasError => const {'error', 'failed'}.contains(status) || error.isNotEmpty;
  bool get isPending => const {'pending', 'processing'}.contains(status);
  bool get isCard => payload['type']?.toString() == 'card';
  bool get isQuestion => payload['type']?.toString() == 'question';
  String get cardKind => payload['kind']?.toString() ?? '';
  String get cardTitle => AppUtils.decodeHtml(
    (payload['title'] ?? (subjectTitle.isNotEmpty ? subjectTitle : message)).toString(),
  );
  String get cardState => payload['state']?.toString() ?? '';
  bool get cardTerminal => const {'confirmed', 'rejected', 'deferred', 'revised'}.contains(cardState);
  List<String> get cardActions =>
      (payload['actions'] as List?)?.map((e) => e.toString()).toList() ?? const [];
  List<String> get evidence =>
      (payload['evidence_refs'] as List?)?.map((e) => e.toString()).take(5).toList() ?? const [];

  ChatTurn copyWith({
    String? status,
    String? error,
    String? reply,
    Map<String, dynamic>? payload,
  }) =>
      ChatTurn(
        turnId: turnId,
        session: session,
        scope: scope,
        subjectId: subjectId,
        subjectTitle: subjectTitle,
        replyToTurnId: replyToTurnId,
        message: message,
        reply: reply ?? this.reply,
        status: status ?? this.status,
        error: error ?? this.error,
        payload: payload ?? this.payload,
        createdAt: createdAt,
        updatedAt: DateTime.now().toIso8601String(),
        role: role,
      );
}

class PendingConfirmation {
  final String kind; // hypothesis, confusion, interest_probe, avoidance_probe
  final String ref;
  final String title;
  final String observation;
  final String interpretation;
  final List<String> evidence;
  final double confidence;
  final String createdAt;
  final String status; // pending, confirmed, rejected, deferred

  const PendingConfirmation({
    required this.kind,
    required this.ref,
    required this.title,
    this.observation = '',
    this.interpretation = '',
    this.evidence = const [],
    this.confidence = 0,
    this.createdAt = '',
    this.status = 'pending',
  });

  factory PendingConfirmation.fromJson(Map<String, dynamic> json) => PendingConfirmation(
    kind: json['kind']?.toString() ?? '',
    ref: json['ref']?.toString() ?? '',
    title: AppUtils.decodeHtml(json['title']?.toString() ?? ''),
    observation: AppUtils.decodeHtml(json['observation']?.toString() ?? ''),
    interpretation: AppUtils.decodeHtml(json['interpretation']?.toString() ?? ''),
    evidence: (json['evidence_refs'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    createdAt: json['created_at']?.toString() ?? '',
    status: json['status']?.toString() ?? 'pending',
  );

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'ref': ref,
    'title': title,
    'observation': observation,
    'interpretation': interpretation,
    'evidence_refs': evidence,
    'confidence': confidence,
    'created_at': createdAt,
    'status': status,
  };
}

class AppNotification {
  final String id;
  final String type; // interest_probe, avoidance_probe, cognition_update, pending_chat, delight
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool read;
  final String actionStatus; // pending, acted, dismissed

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body = '',
    this.data = const {},
    required this.createdAt,
    this.read = false,
    this.actionStatus = 'pending',
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id']?.toString() ?? '',
    type: json['type']?.toString() ?? '',
    title: AppUtils.decodeHtml(json['title']?.toString() ?? ''),
    body: AppUtils.decodeHtml(json['body']?.toString() ?? ''),
    data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : const {},
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    read: json['read'] == true,
    actionStatus: json['action_status']?.toString() ?? 'pending',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'data': data,
    'created_at': createdAt.toIso8601String(),
    'read': read,
    'action_status': actionStatus,
  };
}
