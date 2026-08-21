import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../database/repository.dart';

class LLMProviderPreset {
  final String id;
  final String name;
  final String baseUrl;
  final String model;
  final String description;
  final bool usesAnthropicMessages;

  const LLMProviderPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.model,
    required this.description,
    this.usesAnthropicMessages = false,
  });

  static const String customId = 'custom';
  static const String anthropicId = 'anthropic';

  static const List<LLMProviderPreset> presets = [
    LLMProviderPreset(
      id: 'openai',
      name: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4o-mini',
      description: 'OpenAI Chat Completions',
    ),
    LLMProviderPreset(
      id: 'deepseek',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com/v1',
      model: 'deepseek-chat',
      description: 'OpenAI 兼容接口',
    ),
    LLMProviderPreset(
      id: 'sensenova',
      name: '商汤日日新',
      baseUrl: 'https://api.sensenova.cn/compatible-mode/v2',
      model: 'SenseChat-5',
      description: 'OpenAI 兼容接口',
    ),
    LLMProviderPreset(
      id: 'gemini',
      name: 'Google AI Studio',
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
      model: 'gemini-3.7-flash',
      description: 'Gemini OpenAI 兼容接口',
    ),
    LLMProviderPreset(
      id: anthropicId,
      name: 'Claude',
      baseUrl: 'https://api.anthropic.com/v1',
      model: 'claude-sonnet-5',
      description: 'Anthropic Messages API',
      usesAnthropicMessages: true,
    ),
    LLMProviderPreset(
      id: 'kimi',
      name: 'Kimi',
      baseUrl: 'https://api.moonshot.ai/v1',
      model: 'kimi-k2.6',
      description: 'Moonshot OpenAI 兼容接口',
    ),
    LLMProviderPreset(
      id: 'glm',
      name: 'GLM',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      model: 'glm-5.3',
      description: '智谱 OpenAI 兼容接口',
    ),
    LLMProviderPreset(
      id: 'openrouter',
      name: 'OpenRouter',
      baseUrl: 'https://openrouter.ai/api/v1',
      model: '~openai/gpt-latest',
      description: '多模型聚合 OpenAI 兼容接口',
    ),
  ];

  static const LLMProviderPreset custom = LLMProviderPreset(
    id: customId,
    name: '自定义兼容接口',
    baseUrl: '',
    model: '',
    description: '填写任意 OpenAI 兼容服务地址',
  );

  static LLMProviderPreset fromId(String id) {
    if (id == 'openai_compatible') return custom;
    return presets.firstWhere(
      (preset) => preset.id == id,
      orElse: () => custom,
    );
  }
}

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
    this.provider = 'openai',
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

  Map<String, dynamic> toJson({bool includeApiKey = true}) => {
        'provider': provider,
        if (includeApiKey) 'api_key': apiKey,
        'base_url': baseUrl,
        'model': model,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'top_p': topP,
        'timeout_seconds': timeoutSeconds,
      };

  factory LLMConfig.fromJson(Map<String, dynamic> json) => LLMConfig(
        provider: json['provider']?.toString() ?? 'openai',
        apiKey: json['api_key']?.toString() ?? '',
        baseUrl: json['base_url']?.toString() ?? 'https://api.openai.com/v1',
        model: json['model']?.toString() ?? 'gpt-4o-mini',
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
        maxTokens: (json['max_tokens'] as num?)?.toInt() ?? 2048,
        topP: (json['top_p'] as num?)?.toDouble() ?? 1.0,
        timeoutSeconds: (json['timeout_seconds'] as num?)?.toInt() ?? 60,
      );

  bool get isConfigured => validationError == null;

  bool get usesAnthropicMessages => provider == LLMProviderPreset.anthropicId;

  String? get validationError {
    if (apiKey.trim().isEmpty) return '请填写 API Key';
    if (baseUrl.trim().isEmpty) return '请填写 Base URL';
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Base URL 格式无效';
    }
    if (model.trim().isEmpty) return '请填写模型名称';
    if (maxTokens <= 0) return '最大输出 Token 必须大于 0';
    if (timeoutSeconds <= 0) return '超时时间必须大于 0';
    return null;
  }
}

class LLMService {
  static const _apiKeyStorageKey = 'fuguang_llm_api_key_v1';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final AppRepository _repo = AppRepository();
  final http.Client _client = http.Client();
  LLMConfig _config = const LLMConfig();
  int _totalRequests = 0;
  int _totalTokens = 0;

  LLMService._internal();
  static final LLMService instance = LLMService._internal();

  Future<void> init() async {
    LLMConfig loaded = const LLMConfig();
    final configStr = await _repo.getConfig('llm_config');
    if (configStr != null) {
      try {
        loaded = LLMConfig.fromJson(
          Map<String, dynamic>.from(jsonDecode(configStr)),
        );
      } catch (_) {
        loaded = const LLMConfig();
      }
    }

    final storedKey = await _secureStorage.read(key: _apiKeyStorageKey);
    final legacyKey = loaded.apiKey.trim();
    final resolvedKey =
        (storedKey?.trim().isNotEmpty ?? false) ? storedKey!.trim() : legacyKey;

    if (legacyKey.isNotEmpty && (storedKey?.trim().isEmpty ?? true)) {
      await _secureStorage.write(key: _apiKeyStorageKey, value: legacyKey);
    }
    _config = loaded.copyWith(apiKey: resolvedKey);

    if (legacyKey.isNotEmpty) {
      await _persistConfigWithoutApiKey(_config);
    }
  }

  LLMConfig get config => _config;
  bool get isReady => _config.isConfigured;
  int get totalRequests => _totalRequests;
  int get totalTokens => _totalTokens;

  Future<void> updateConfig(LLMConfig config) async {
    final normalized = config.copyWith(
      provider: config.provider.trim().isEmpty
          ? LLMProviderPreset.customId
          : config.provider.trim(),
      apiKey: config.apiKey.trim(),
      baseUrl: config.baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
      model: config.model.trim(),
    );

    if (normalized.apiKey.isEmpty) {
      await _secureStorage.delete(key: _apiKeyStorageKey);
    } else {
      await _secureStorage.write(
        key: _apiKeyStorageKey,
        value: normalized.apiKey,
      );
    }
    _config = normalized;
    await _persistConfigWithoutApiKey(normalized);
  }

  Future<void> _persistConfigWithoutApiKey(LLMConfig config) {
    return _repo.setConfig(
      'llm_config',
      jsonEncode(config.copyWith(apiKey: '').toJson(includeApiKey: false)),
    );
  }

  Future<LLMResponse> chat({
    required List<ChatMessage> messages,
    double? temperature,
    int? maxTokens,
    String? model,
  }) async {
    final validationError = _config.validationError;
    if (validationError != null) return LLMResponse.error(validationError);

    final effectiveTemperature = temperature ?? _config.temperature;
    final effectiveMaxTokens = maxTokens ?? _config.maxTokens;
    final effectiveModel = model ?? _config.model;

    try {
      _totalRequests++;
      final response = _config.usesAnthropicMessages
          ? await _sendAnthropicRequest(
              messages: messages,
              temperature: effectiveTemperature,
              maxTokens: effectiveMaxTokens,
              model: effectiveModel,
            )
          : await _sendOpenAiCompatibleRequest(
              messages: messages,
              temperature: effectiveTemperature,
              maxTokens: effectiveMaxTokens,
              model: effectiveModel,
            );
      return response;
    } on TimeoutException {
      return LLMResponse.error('请求超时，请检查网络或提高超时时间');
    } on FormatException {
      return LLMResponse.error('服务返回的数据格式无效，请检查服务商与接口地址');
    } catch (e) {
      return LLMResponse.error('请求失败: $e');
    }
  }

  Future<LLMResponse> _sendOpenAiCompatibleRequest({
    required List<ChatMessage> messages,
    required double temperature,
    required int maxTokens,
    required String model,
  }) async {
    final uri = _endpoint('/chat/completions');
    final body = jsonEncode({
      'model': model,
      'messages': messages.map((message) => message.toJson()).toList(),
      'temperature': temperature,
      'max_tokens': maxTokens,
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

    if (res.statusCode < 200 || res.statusCode >= 300) {
      return LLMResponse.error(_httpError(res));
    }
    final data = Map<String, dynamic>.from(jsonDecode(res.body));
    final choice = (data['choices'] as List?)?.isNotEmpty == true
        ? (data['choices'] as List).first
        : null;
    final content = _contentToText(
      choice is Map && choice['message'] is Map
          ? choice['message']['content']
          : null,
    );
    final usage = data['usage'] is Map
        ? Map<String, dynamic>.from(data['usage'])
        : const <String, dynamic>{};
    final totalTokens = (usage['total_tokens'] as num?)?.toInt() ?? 0;
    _totalTokens += totalTokens;
    return LLMResponse(
      content: content,
      model: data['model']?.toString() ?? model,
      promptTokens: (usage['prompt_tokens'] as num?)?.toInt() ?? 0,
      completionTokens: (usage['completion_tokens'] as num?)?.toInt() ?? 0,
      totalTokens: totalTokens,
    );
  }

  Future<LLMResponse> _sendAnthropicRequest({
    required List<ChatMessage> messages,
    required double temperature,
    required int maxTokens,
    required String model,
  }) async {
    final systemPrompt = messages
        .where((message) => message.role == 'system')
        .map((message) => message.content)
        .join('\n\n');
    final convertedMessages = messages
        .where((message) => message.role != 'system')
        .map(
          (message) => {
            'role': message.role == 'assistant' ? 'assistant' : 'user',
            'content': message.content,
          },
        )
        .toList();
    if (convertedMessages.isEmpty) {
      convertedMessages.add({'role': 'user', 'content': 'ping'});
    }

    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'messages': convertedMessages,
      'temperature': temperature,
    };
    if (systemPrompt.isNotEmpty) body['system'] = systemPrompt;

    final res = await _client
        .post(
          _endpoint('/messages'),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': _config.apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode(body),
        )
        .timeout(Duration(seconds: _config.timeoutSeconds));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      return LLMResponse.error(_httpError(res));
    }
    final data = Map<String, dynamic>.from(jsonDecode(res.body));
    final usage = data['usage'] is Map
        ? Map<String, dynamic>.from(data['usage'])
        : const <String, dynamic>{};
    final promptTokens = (usage['input_tokens'] as num?)?.toInt() ?? 0;
    final completionTokens = (usage['output_tokens'] as num?)?.toInt() ?? 0;
    final totalTokens = promptTokens + completionTokens;
    _totalTokens += totalTokens;
    return LLMResponse(
      content: _contentToText(data['content']),
      model: data['model']?.toString() ?? model,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
    );
  }

  Uri _endpoint(String path) {
    final baseUrl = _config.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$baseUrl$path');
  }

  String _httpError(http.Response response) {
    var detail = response.body.trim();
    if (detail.length > 600) detail = '${detail.substring(0, 600)}…';
    return detail.isEmpty
        ? 'HTTP ${response.statusCode}'
        : 'HTTP ${response.statusCode}: $detail';
  }

  String _contentToText(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      return content
          .whereType<Map>()
          .map((item) => item['text']?.toString() ?? '')
          .where((text) => text.isNotEmpty)
          .join('\n');
    }
    return content?.toString() ?? '';
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
      messages: const [ChatMessage(role: 'user', content: 'ping')],
      maxTokens: 10,
    );
    return !res.isError;
  }
}

class ChatMessage {
  final String role;
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
