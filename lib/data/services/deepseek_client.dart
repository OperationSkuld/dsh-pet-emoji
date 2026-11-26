import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/app_links.dart';
import '../../core/logger.dart';
import '../models/balance_info.dart';

/// 失败类型。UI 与桌宠动画都依赖它做反馈。
enum DeepSeekErrorKind {
  network,
  unauthorized,
  insufficientBalance,
  rateLimited,
  server,
  badRequest,
  canceled,
  badResponse,
}

class DeepSeekException implements Exception {
  DeepSeekException(this.kind, this.message, {this.statusCode, this.detail});

  final DeepSeekErrorKind kind;
  final String message;
  final int? statusCode;
  final String? detail;

  /// 桌宠应当播放的反馈标签。
  String get feedbackTag => switch (kind) {
        DeepSeekErrorKind.insufficientBalance => 'balance_empty',
        DeepSeekErrorKind.unauthorized => 'confused',
        DeepSeekErrorKind.canceled => 'idle',
        _ => 'error',
      };

  @override
  String toString() => message;
}

/// 流式增量。reasoner 模型会额外给出 [reasoning]。
class ChatDelta {
  const ChatDelta({this.content = '', this.reasoning = ''});

  final String content;
  final String reasoning;
}

/// DeepSeek 开放平台客户端。
///
/// 只做两件事：`/chat/completions` 流式对话、`/user/balance` 余额查询。
/// 不做重试与降级——调用方（ChatController）负责。
class DeepSeekClient {
  DeepSeekClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 60),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final Duration timeout;
  final http.Client _http;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  Uri _endpoint(String path) {
    var base = baseUrl.trim();
    if (base.isEmpty) base = kDefaultBaseUrl;
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return Uri.parse('$base$path');
  }

  /// 流式对话。逐条 yield 增量，异常统一抛 [DeepSeekException]。
  Stream<ChatDelta> streamChat({
    required List<Map<String, String>> messages,
    String model = kDefaultModel,
    double temperature = 1.0,
  }) async* {
    final payload = jsonEncode({
      'model': model,
      'messages': messages,
      'stream': true,
      'temperature': temperature,
    });

    final request = http.Request('POST', _endpoint('/chat/completions'))
      ..headers.addAll(_headers)
      ..body = payload;

    late final http.StreamedResponse response;
    try {
      response = await _http.send(request).timeout(timeout);
    } on TimeoutException {
      throw DeepSeekException(
        DeepSeekErrorKind.network,
        '请求超时，请检查网络或稍后重试',
      );
    } on SocketException catch (error) {
      throw DeepSeekException(
        DeepSeekErrorKind.network,
        '网络不可达：${error.message}',
      );
    } on http.ClientException catch (error) {
      throw DeepSeekException(
        DeepSeekErrorKind.network,
        '连接失败：${error.message}',
      );
    }

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw _mapHttpError(response.statusCode, body);
    }

    try {
      await for (final line
          in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
        final data = trimmed.substring(5).trim();
        if (data == '[DONE]') break;
        final delta = _parseDelta(data);
        if (delta != null) yield delta;
      }
    } on FormatException catch (error) {
      throw DeepSeekException(
        DeepSeekErrorKind.badResponse,
        '响应解析失败：${error.message}',
      );
    }
  }

  ChatDelta? _parseDelta(String data) {
    final decoded = jsonDecode(data);
    if (decoded is! Map<String, dynamic>) return null;
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map<String, dynamic>) return null;
    final delta = first['delta'];
    if (delta is! Map<String, dynamic>) return null;
    final content = delta['content'] as String? ?? '';
    final reasoning = delta['reasoning_content'] as String? ?? '';
    if (content.isEmpty && reasoning.isEmpty) return null;
    return ChatDelta(content: content, reasoning: reasoning);
  }

  /// 余额查询。
  Future<BalanceInfo> fetchBalance() async {
    late final http.Response response;
    try {
      response = await _http
          .get(_endpoint('/user/balance'), headers: _headers)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw DeepSeekException(DeepSeekErrorKind.network, '余额查询超时');
    } on SocketException catch (error) {
      throw DeepSeekException(
        DeepSeekErrorKind.network,
        '网络不可达：${error.message}',
      );
    }

    if (response.statusCode != 200) {
      throw _mapHttpError(response.statusCode, response.body);
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('余额响应不是对象');
      }
      return BalanceInfo.fromJson(decoded);
    } on FormatException catch (error) {
      throw DeepSeekException(
        DeepSeekErrorKind.badResponse,
        '余额响应解析失败：${error.message}',
      );
    }
  }

  DeepSeekException _mapHttpError(int statusCode, String body) {
    final detail = _extractMessage(body);
    Log.e('DeepSeekClient', 'HTTP $statusCode: $body');
    final suffix = detail == null ? '' : '（$detail）';
    return switch (statusCode) {
      400 => DeepSeekException(
          DeepSeekErrorKind.badRequest,
          '请求参数有误$suffix',
          statusCode: statusCode,
          detail: detail,
        ),
      401 => DeepSeekException(
          DeepSeekErrorKind.unauthorized,
          'API Key 无效或已失效$suffix',
          statusCode: statusCode,
          detail: detail,
        ),
      402 => DeepSeekException(
          DeepSeekErrorKind.insufficientBalance,
          '账户余额不足，请先充值$suffix',
          statusCode: statusCode,
          detail: detail,
        ),
      429 => DeepSeekException(
          DeepSeekErrorKind.rateLimited,
          '请求过于频繁，请稍后再试$suffix',
          statusCode: statusCode,
          detail: detail,
        ),
      >= 500 => DeepSeekException(
          DeepSeekErrorKind.server,
          'DeepSeek 服务端异常（$statusCode）$suffix',
          statusCode: statusCode,
          detail: detail,
        ),
      _ => DeepSeekException(
          DeepSeekErrorKind.badResponse,
          '请求失败（$statusCode）$suffix',
          statusCode: statusCode,
          detail: detail,
        ),
    };
  }

  String? _extractMessage(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.isNotEmpty) return message;
        }
        final message = decoded['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  /// 一次性（非流式）补全，用于语义辅助标注。
  Future<String> complete({
    required List<Map<String, String>> messages,
    String model = kDefaultModel,
    double temperature = 0.2,
    int maxTokens = 256,
  }) async {
    final request = http.Request('POST', _endpoint('/chat/completions'))
      ..headers.addAll(_headers)
      ..body = jsonEncode({
        'model': model,
        'messages': messages,
        'stream': false,
        'temperature': temperature,
        'max_tokens': maxTokens,
      });

    late final http.StreamedResponse streamed;
    try {
      streamed = await _http.send(request).timeout(timeout);
    } on TimeoutException {
      throw DeepSeekException(DeepSeekErrorKind.network, '标注请求超时');
    } on SocketException catch (error) {
      throw DeepSeekException(DeepSeekErrorKind.network, '网络不可达：${error.message}');
    }

    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw _mapHttpError(streamed.statusCode, body);
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw DeepSeekException(DeepSeekErrorKind.badResponse, '补全响应格式异常');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw DeepSeekException(DeepSeekErrorKind.badResponse, '补全响应缺少 choices');
    }
    final message = (choices.first as Map<String, dynamic>)['message'];
    if (message is! Map<String, dynamic>) {
      throw DeepSeekException(DeepSeekErrorKind.badResponse, '补全响应缺少 message');
    }
    return message['content'] as String? ?? '';
  }

  void dispose() => _http.close();
}
