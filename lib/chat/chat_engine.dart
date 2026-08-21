import '../models/chat.dart';
import '../models/profile.dart';
import '../models/delight.dart';
import '../database/repository.dart';
import '../llm/llm_service.dart';
import '../llm/prompts.dart';
import '../soul/profile_engine.dart';
import '../utils/app_utils.dart';

class ChatEngine {
  final AppRepository _repo = AppRepository();
  final LLMService _llm = LLMService.instance;
  final ProfileEngine _profileEngine = ProfileEngine.instance;

  ChatEngine._internal();
  static final ChatEngine instance = ChatEngine._internal();

  Future<List<ChatTurn>> getChatHistory({String session = 'main'}) async {
    return _repo.getChatHistory(session: session);
  }

  Future<ChatTurn> sendMessage({
    required String message,
    String session = 'main',
    String scope = 'chat',
    String subjectId = '',
    String subjectTitle = '',
  }) async {
    final turnId = AppUtils.generateId();
    final now = DateTime.now().toIso8601String();
    final userTurn = ChatTurn(
      turnId: turnId,
      session: session,
      scope: scope,
      subjectId: subjectId,
      subjectTitle: subjectTitle,
      message: message,
      role: 'user',
      status: 'done',
      createdAt: now,
      updatedAt: now,
    );
    await _repo.insertChatTurn(userTurn);

    final event = BehaviorEvent(
      eventId: 'chat_${DateTime.now().millisecondsSinceEpoch}',
      eventType: 'chat',
      title: message,
      createdAt: DateTime.now(),
      weight: 1.5,
      metadata: {'session': session, 'scope': scope},
    );
    await _repo.insertEvent(event);

    if (!_llm.isReady) {
      final replyTurn = ChatTurn(
        turnId: 'reply_$turnId',
        session: session,
        scope: scope,
        subjectId: subjectId,
        subjectTitle: subjectTitle,
        replyToTurnId: turnId,
        reply: '我还没有配置 LLM API Key，暂时无法对话。请在设置中填写 OpenAI 兼容接口的 API Key、Base URL 和模型名称。',
        role: 'assistant',
        status: 'done',
        createdAt: now,
        updatedAt: now,
      );
      await _repo.insertChatTurn(replyTurn);
      return replyTurn;
    }

    final pendingTurn = ChatTurn(
      turnId: 'reply_$turnId',
      session: session,
      scope: scope,
      subjectId: subjectId,
      subjectTitle: subjectTitle,
      replyToTurnId: turnId,
      role: 'assistant',
      status: 'processing',
      createdAt: now,
      updatedAt: now,
    );
    await _repo.insertChatTurn(pendingTurn);

    try {
      final profile = await _profileEngine.getProfile();
      final history = await _repo.getChatHistory(session: session, limit: 20);
      final historyMaps = history
          .where((t) => t.message.isNotEmpty || t.reply.isNotEmpty)
          .map((t) => {
            'role': t.role,
            'content': t.role == 'user' ? t.message : t.reply,
          })
          .toList();

      final res = await _llm.complete(
        systemPrompt: LLMPrompts.chatReply(
          profile.toJson(),
          historyMaps,
          message,
        ),
        userPrompt: message,
        temperature: 0.8,
        maxTokens: 1024,
      );

      final replyTurn = pendingTurn.copyWith(
        status: res.isError ? 'error' : 'done',
        error: res.error ?? '',
        reply: res.content,
      );
      await _repo.updateChatTurn(replyTurn);

      if (res.isSuccess) {
        await _maybeTriggerProfileUpdate(message, res.content);
      }
      return replyTurn;
    } catch (e) {
      final errorTurn = pendingTurn.copyWith(
        status: 'error',
        error: e.toString(),
        reply: '抱歉，我遇到了一些问题：$e',
      );
      await _repo.updateChatTurn(errorTurn);
      return errorTurn;
    }
  }

  Future<void> _maybeTriggerProfileUpdate(String userMsg, String reply) async {
    final preferenceKeywords = ['我喜欢', '我不喜欢', '我讨厌', '我想要', '给我推', '别推', '多看', '少看'];
    final hasPreference = preferenceKeywords.any((k) => userMsg.contains(k));
    if (hasPreference) {
      await _profileEngine.generateProfile();
      await _maybeGenerateNotification();
    }
  }

  Future<void> _maybeGenerateNotification() async {
    final profile = await _profileEngine.getProfile();
    if (profile.cognitionUpdates.isNotEmpty) {
      final latest = profile.cognitionUpdates.first;
      if (!latest.seen) {
        final notif = AppNotification(
          id: 'cog_${DateTime.now().millisecondsSinceEpoch}',
          type: 'cognition_update',
          title: '我对你有了新的理解',
          body: latest.summary,
          data: {'impact': latest.impact, 'reasoning': latest.reasoning},
          createdAt: DateTime.now(),
        );
        await _repo.insertNotification(notif);
      }
    }
  }

  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    return _repo.getNotifications(limit: limit);
  }

  Future<int> getUnreadCount() async {
    return _repo.getUnreadCount();
  }

  Future<void> markNotificationRead(String id) async {
    await _repo.markNotificationRead(id);
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
  }

  Future<List<PendingConfirmation>> getPendingConfirmations() async {
    return _repo.getPendingConfirmations(limit: 10);
  }

  Future<void> respondToConfirmation({
    required String ref,
    required String response, // confirm, reject, defer, discuss
    String? discussion,
  }) async {
    await _repo.updateConfirmationStatus(ref, response);
    if (response == 'confirm' || response == 'reject') {
      final confs = await _repo.getPendingConfirmations();
      final conf = confs.where((c) => c.ref == ref).firstOrNull();
      if (conf != null) {
        await _profileEngine.confirmSpeculation(
          conf.observation,
          confirmed: response == 'confirm',
        );
      }
    }
    if (discussion != null && discussion.isNotEmpty) {
      await sendMessage(message: discussion, session: 'main');
    }
  }

  Future<void> generateInterestProbeNotification() async {
    final probes = await _profileEngine.generateInterestProbes();
    for (final probe in probes) {
      await _repo.upsertConfirmation(probe);
      final notif = AppNotification(
        id: 'probe_${probe.ref}',
        type: 'interest_probe',
        title: '想了解你更多',
        body: probe.title,
        data: {'ref': probe.ref, 'domain': probe.observation, 'confidence': probe.confidence},
        createdAt: DateTime.now(),
      );
      await _repo.insertNotification(notif);
    }
  }

  Future<void> clearChatHistory({String session = 'main'}) async {
    final turns = await _repo.getChatHistory(session: session);
    for (final turn in turns) {
      await _repo.updateChatTurn(turn.copyWith(status: 'done'));
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? firstOrNull() {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
