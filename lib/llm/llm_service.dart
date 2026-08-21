import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/repository.dart';

class LLMConfig {
  final String provider;
  final String apiKey;
  final String baseUrl;
  final String model;
  final double temperature;
  final int maxTokens;
  final double topP;
  final int timeoutSeconds;

  const LLMConfig({
    this.provider = 'openai_compatible',
    this.apiKey = '',
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-4o-mini',
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.topP = 1.0,
    this.timeoutSeconds = 60,
  });

  LLMConfig copyWith({
    String? provider,
    String? apiKey,
    String? baseUrl,
    String? model,
    double? temperature,
    int? maxTokens,
    double? topP,
    int? timeoutSeconds,
  }) =>
      LLMConfig(
        provider: provider ?? this.provider,
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        temperature: temperature ?? this.temperature,
        maxTokens: maxTokens ?? this.maxTokens,
        topP: topP ?? this.topP,
        timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      );

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'api_key': apiKey,
    'base_url': baseUrl,
    'model': model,
    'temperature': temperature,
    'max_tokens': maxTokens,
    'top_p': topP,
    'timeout_seconds': timeoutSeconds,
  };

  factory LLMConfig.fromJson(Map<String, dynamic> json) => LLMConfig(
    provider: json['provider']?.toString() ?? 'openai_compatible',
    apiKey: json['api_key']?.toString() ?? '',
    baseUrl: json['base_url']?.toString() ?? 'https://api.openai.com/v1',
    model: json['model']?.toString() ?? 'gpt-4o-mini',
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
    maxTokens: (json['max_tokens'] as num?)?.toInt() ?? 2048,
    topP: (json['top_p'] as num?)?.toDouble() ?? 1.0,
    timeoutSeconds: (json['timeout_seconds'] as num?)?.toInt() ?? 60,
  );

  bool get isConfigured => apiKey.isNotEmpty && baseUrl.isNotEmpty && model.isNotEmpty;
}

class LLMService {
  final AppRepository _repo = AppRepository();
  final http.Client _client = http.Client();
  LLMConfig _config = const LLMConfig();
  int _totalRequests = 0;
  int _totalTokens = 0;

  LLMService._internal();
  static final LLMService instance = LLMService._internal();

  Future<void> init() async {
    final configStr = await _repo.getConfig('llm_config');
    if (configStr != null) {
      try {
        _config = LLMConfig.fromJson(jsonDecode(configStr));
      } catch (_) {}
    }
  }

  LLMConfig get config => _config;
  bool get isReady => _config.isConfigured;
  int get totalRequests => _totalRequests;
  int get totalTokens => _totalTokens;

  Future<void> updateConfig(LLMConfig config) async {
    _config = config;
    await _repo.setConfig('llm_config', jsonEncode(config.toJson()));
  }

  Future<LLMResponse> chat({
    required List<ChatMessage> messages,
    double? temperature,
    int? maxTokens,
    String? model,
  }) async {
    if (!_config.isConfigured) {
      return LLMResponse.error('LLM 未配置，请在设置中填写 API Key');
    }
    try {
      _totalRequests++;
      final uri = Uri.parse('${_config.baseUrl.replaceAll(RegExp(r'/$'), '')}/chat/completions');
      final body = jsonEncode({
        'model': model ?? _config.model,
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': temperature ?? _config.temperature,
        'max_tokens': maxTokens ?? _config.maxTokens,
        'top_p': _config.topP,
        'stream': false,
      });
      final res = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${_config.apiKey}',
            },
            body: body,
          )
          .timeout(Duration(seconds: _config.timeoutSeconds));
      if (res.statusCode != 200) {
        return LLMResponse.error('HTTP ${res.statusCode}: ${res.body}');
      }
      final data = jsonDecode(res.body);
      final choice = data['choices']?.first;
      final content = choice?['message']?['content']?.toString() ?? '';
      final usage = data['usage'] ?? {};
      _totalTokens += (usage['total_tokens'] as num?)?.toInt() ?? 0;
      return LLMResponse(
        content: content,
        model: data['model']?.toString() ?? _config.model,
        promptTokens: (usage['prompt_tokens'] as num?)?.toInt() ?? 0,
        completionTokens: (usage['completion_tokens'] as num?)?.toInt() ?? 0,
        totalTokens: (usage['total_tokens'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      return LLMResponse.error('请求失败: $e');
    }
  }

  Future<LLMResponse> complete({
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
  }) {
    return chat(
      messages: [
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: userPrompt),
      ],
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  Future<Map<String, dynamic>?> chatJson({
    required String systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
  }) async {
    final res = await complete(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      temperature: temperature ?? 0.3,
      maxTokens: maxTokens ?? 4096,
    );
    if (res.isError) return null;
    return _parseJson(res.content);
  }

  Map<String, dynamic>? _parseJson(String content) {
    try {
      final cleaned = content
          .replaceAll(RegExp(r'^```json\s*'), '')
          .replaceAll(RegExp(r'^```\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '')
          .trim();
      return Map<String, dynamic>.from(jsonDecode(cleaned));
    } catch (_) {
      final match = RegExp(r'\{[\s\S]*\}', dotAll: true).firstMatch(content);
      if (match != null) {
        try {
          return Map<String, dynamic>.from(jsonDecode(match.group(0)!));
        } catch (_) {}
      }
      return null;
    }
  }

  Future<bool> testConnection() async {
    if (!_config.isConfigured) return false;
    final res = await chat(
      messages: [ChatMessage(role: 'user', content: 'ping')],
      maxTokens: 10,
    );
    return !res.isError;
  }
}

class ChatMessage {
  final String role; // system, user, assistant
  final String content;
  final String? name;

  const ChatMessage({required this.role, required this.content, this.name});

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    if (name != null) 'name': name,
  };
}

class LLMResponse {
  final String content;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final String? error;

  const LLMResponse({
    required this.content,
    this.model = '',
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.error,
  });

  factory LLMResponse.error(String message) => LLMResponse(
    content: '',
    error: message,
  );

  bool get isError => error != null && error!.isNotEmpty;
  bool get isSuccess => !isError && content.isNotEmpty;
}
