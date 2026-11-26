import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/logger.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/balance_info.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/semantic_profile.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/services/deepseek_client.dart';
import '../../domain/semantic/llm_tagger.dart';
import '../../domain/semantic/semantic_analyzer.dart';
import '../pet/pet_controller.dart';

/// 对话控制器：串起「发送 → 流式回复 → 语义分析 → 桌宠表演」。
class ChatController extends ChangeNotifier {
  ChatController({
    required this.analyzer,
    required this.tags,
    required this.pet,
    required this.clientFactory,
    required this.settingsReader,
  });

  final SemanticAnalyzer analyzer;
  final TagRepository tags;
  final PetController pet;

  final DeepSeekClient Function(AppSettings) clientFactory;
  final AppSettings Function() settingsReader;

  final List<ChatMessage> _messages = [];
  final math.Random _random = math.Random();

  bool _generating = false;
  bool _canceled = false;
  String? _lastError;
  SemanticProfile? _lastProfile;
  BalanceInfo? _balance;
  Timer? _notifyTimer;
  int _sequence = 0;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool get isGenerating => _generating;

  String? get lastError => _lastError;

  SemanticProfile? get lastProfile => _lastProfile;

  BalanceInfo? get balance => _balance;

  AppSettings get settings => settingsReader();

  static const String _persona = '''
你是 DeepSeek 的桌面宠物「大肥鱼」，一只女仆鲸鱼娘。说话温柔、机灵、偶尔傲娇，自称「大肥鱼」或「我」。
回答要简洁：默认 1~3 句、150 字以内；只有用户明确要求详细展开时才写长。
不要使用 Markdown 标题，不要罗列大段条目，像一个真正坐在屏幕上的小家伙在聊天。
涉及技术问题时保持准确，必要时承认不确定。''';

  /// 发送一条用户消息。
  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || _generating) return;

    final settings = settingsReader();
    if (!settings.isConfigured) {
      _lastError = '未配置 API Key';
      pet.say('先把 API Key 填给我吧～');
      pet.playTag('confused');
      notifyListeners();
      return;
    }

    _messages.add(
      ChatMessage(
        id: _nextId(),
        role: ChatRole.user,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
    await _generate(content, settings);
  }

  /// 重试上一条失败的回复：不重复插入用户消息。
  Future<void> retryLast() async {
    if (_generating) return;
    final failedIndex = _messages.lastIndexWhere(
      (message) =>
          message.role == ChatRole.assistant &&
          message.status == ChatStatus.failed,
    );
    if (failedIndex < 0) return;
    final userIndex = _messages.lastIndexWhere(
      (message) => message.role == ChatRole.user,
      failedIndex,
    );
    final userText = userIndex >= 0 ? _messages[userIndex].content : '';
    _messages.removeAt(failedIndex);
    notifyListeners();
    await _generate(userText, settingsReader());
  }

  Future<void> _generate(String userText, AppSettings settings) async {
    _canceled = false;
    _lastError = null;

    final placeholderId = _nextId();
    _messages.add(
      ChatMessage(
        id: placeholderId,
        role: ChatRole.assistant,
        content: '',
        createdAt: DateTime.now(),
        status: ChatStatus.streaming,
      ),
    );
    _generating = true;
    pet.playTag('waiting', bubble: '让我想想…');
    notifyListeners();

    final client = clientFactory(settings);
    final buffer = StringBuffer();
    final reasoning = StringBuffer();
    var firstTokenSeen = false;

    try {
      final stream = client.streamChat(
        messages: _apiMessages(),
        model: settings.model,
      );
      await for (final delta in stream) {
        if (_canceled) break;
        if (!firstTokenSeen) {
          firstTokenSeen = true;
          pet.playTag('thinking');
        }
        buffer.write(delta.content);
        reasoning.write(delta.reasoning);
        _replace(
          placeholderId,
          content: buffer.toString(),
          reasoning: reasoning.toString(),
        );
        _throttledNotify();
      }

      final reply = buffer.toString().trim();
      if (reply.isEmpty) {
        throw DeepSeekException(
          _canceled
              ? DeepSeekErrorKind.canceled
              : DeepSeekErrorKind.badResponse,
          _canceled ? '已停止生成' : '模型没有返回内容',
        );
      }

      if (_canceled) {
        _replace(placeholderId, content: reply, status: ChatStatus.done);
        pet.playTag('idle', bubble: '好，停下啦');
        return;
      }

      final semantic = await _analyze(userText, reply, settings);
      _lastProfile = semantic;
      _replace(
        placeholderId,
        content: reply,
        status: ChatStatus.done,
        profile: semantic,
        reasoning: reasoning.toString(),
      );
      pet.react(
        semantic,
        bubble: settings.speechBubble ? _bubbleFor(reply) : null,
      );
    } on DeepSeekException catch (error) {
      _lastError = error.message;
      _replace(
        placeholderId,
        content: buffer.toString().trim(),
        status: ChatStatus.failed,
      );
      pet.playTag(error.feedbackTag, bubble: error.message);
      Log.e('ChatController', error);
    } catch (error, stack) {
      _lastError = '出错了：$error';
      _replace(
        placeholderId,
        content: buffer.toString().trim(),
        status: ChatStatus.failed,
      );
      pet.playTag('error', bubble: '呜…出错了');
      Log.e('ChatController', error, stack);
    } finally {
      client.dispose();
      _generating = false;
      _notifyTimer?.cancel();
      notifyListeners();
    }
  }

  void stop() {
    if (!_generating) return;
    _canceled = true;
  }

  /// 查询余额，并按档位播放对应动画。
  Future<BalanceInfo?> refreshBalance({bool announce = true}) async {
    final settings = settingsReader();
    if (!settings.isConfigured) {
      _lastError = '未配置 API Key';
      notifyListeners();
      return null;
    }
    final client = clientFactory(settings);
    try {
      pet.playTag('waiting', bubble: '看看钱包…');
      final info = await client.fetchBalance();
      _balance = info;
      _lastError = null;
      final primary = info.primary;
      if (primary == null) {
        pet.playTag('confused', bubble: '查不到余额…');
      } else if (announce) {
        pet.playTag(
          primary.tier.tagId,
          bubble: '${primary.tier.label} · ${primary.formatted}',
        );
      }
      notifyListeners();
      return info;
    } on DeepSeekException catch (error) {
      _lastError = error.message;
      pet.playTag(error.feedbackTag, bubble: error.message);
      notifyListeners();
      return null;
    } finally {
      client.dispose();
    }
  }

  void clearConversation() {
    _messages.clear();
    _lastProfile = null;
    _lastError = null;
    pet.playTag('greet', bubble: '我们重新开始吧～');
    notifyListeners();
  }

  // ---------------------------------------------------------------- 内部
  Future<SemanticProfile> _analyze(
    String userText,
    String reply,
    AppSettings settings,
  ) async {
    final local = analyzer.analyze(userText: userText, replyText: reply);
    if (!settings.llmSemanticTagging) return local;

    final client = clientFactory(settings);
    try {
      final llm = await LlmTagger(client: client).annotate(
        userText: userText,
        replyText: reply,
        tags: tags.tags,
        model: settings.model == 'deepseek-reasoner'
            ? 'deepseek-chat'
            : settings.model,
      );
      return llm == null ? local : local.merge(llm);
    } finally {
      client.dispose();
    }
  }

  List<Map<String, String>> _apiMessages() {
    final history = _messages
        .where((message) => message.content.trim().isNotEmpty)
        .where((message) => message.status != ChatStatus.failed)
        .toList(growable: false);
    final tail = history.length > 18
        ? history.sublist(history.length - 18)
        : history;
    return [
      {'role': 'system', 'content': _persona},
      ...tail.map((message) => message.toApiJson()),
    ];
  }

  String _bubbleFor(String reply) {
    final cleaned = reply
        .replaceAll(RegExp(r'[#*`>_~]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '嗯嗯～';
    final sentence = cleaned.split(RegExp(r'[。！？!?…\n]')).first.trim();
    if (sentence.isNotEmpty) return sentence;
    return cleaned;
  }

  void _replace(
    String id, {
    String? content,
    ChatStatus? status,
    SemanticProfile? profile,
    String? reasoning,
  }) {
    final index = _messages.indexWhere((message) => message.id == id);
    if (index < 0) return;
    _messages[index] = _messages[index].copyWith(
      content: content,
      status: status,
      profile: profile,
      reasoning: reasoning,
    );
  }

  void _throttledNotify() {
    if (_notifyTimer?.isActive ?? false) return;
    _notifyTimer = Timer(const Duration(milliseconds: 80), notifyListeners);
  }

  String _nextId() {
    _sequence++;
    return '${DateTime.now().microsecondsSinceEpoch}-$_sequence-${_random.nextInt(999)}';
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    super.dispose();
  }
}
