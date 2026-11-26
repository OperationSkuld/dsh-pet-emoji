import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 轻量富文本：只处理代码块与换行，其余按正文渲染。
///
/// 刻意不引入 Markdown 依赖——对话界面需要的是「干净」，不是完整的排版能力。
class RichTextView extends StatelessWidget {
  const RichTextView({
    super.key,
    required this.text,
    this.selectable = true,
    this.style,
  });

  final String text;
  final bool selectable;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? AppTheme.body;
    final segments = _split(text);
    if (segments.length == 1 && segments.first.code == null) {
      return _paragraph(segments.first.text, baseStyle);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final segment in segments)
          if (segment.text.trim().isEmpty)
            const SizedBox.shrink()
          else if (segment.code != null)
            _codeBlock(segment.code!, segment.language)
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _paragraph(segment.text, baseStyle),
            ),
      ],
    );
  }

  Widget _paragraph(String content, TextStyle baseStyle) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final textSpan = TextSpan(text: trimmed, style: baseStyle);
    return selectable
        ? SelectableText.rich(textSpan)
        : Text.rich(textSpan);
  }

  Widget _codeBlock(String code, String? language) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              (language == null || language.isEmpty) ? 'code' : language,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: SelectableText(
              code.trimRight(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.55,
                color: Color(0xFF25282D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 用 ``` 切分：[{普通文本}, {code: 代码, language: 语言}, ...]
  List<_Segment> _split(String source) {
    final segments = <_Segment>[];
    final pattern = RegExp(r'```([a-zA-Z0-9_+-]*)\n?');
    var index = 0;
    while (true) {
      final match = pattern.firstMatch(source.substring(index));
      if (match == null) {
        segments.add(_Segment(source.substring(index)));
        break;
      }
      final start = index + match.start;
      if (start > index) {
        segments.add(_Segment(source.substring(index, start)));
      }
      final afterFence = index + match.end;
      final close = source.indexOf('```', afterFence);
      if (close < 0) {
        segments.add(_Segment(source.substring(afterFence), code: source.substring(afterFence)));
        index = source.length;
        break;
      }
      segments.add(
        _Segment('', code: source.substring(afterFence, close), language: match.group(1)),
      );
      index = close + 3;
    }
    return segments;
  }
}

class _Segment {
  const _Segment(this.text, {this.code, this.language});

  final String text;
  final String? code;
  final String? language;
}
