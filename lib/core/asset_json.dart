import 'dart:convert';

import 'package:flutter/services.dart';

/// 读资产里的 JSON（素材清单等）。
///
/// 为什么不用 `AssetBundle.loadString`：
/// 框架对**超过 50 KB** 的字符串会改用 `compute()` 在独立 isolate 里解码
/// （见 asset_bundle.dart 的 `loadString`）。生产环境没问题，但 widget test
/// 跑在 fake async 里，isolate 的回复永远等不到，测试会直接挂死——
/// 我们踩过：给动画清单加了内容框字段后，`animations.json` 从 50 KB 以下
/// 涨到 53 KB，`flutter test` 从此卡在 `AnimationRepository.load()` 上。
///
/// 这里自己解码：53 KB 的 JSON 只要 1 ms，完全不值得为它开 isolate，
/// 换来的好处是测试与线上走同一条确定性的代码路径。
Future<Map<String, dynamic>> loadJsonAsset(
  AssetBundle bundle,
  String key,
) async {
  final data = await bundle.load(key);
  final text = utf8.decode(Uint8List.sublistView(data));
  final decoded = jsonDecode(text);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('$key 的顶层不是 JSON 对象');
  }
  return decoded;
}
