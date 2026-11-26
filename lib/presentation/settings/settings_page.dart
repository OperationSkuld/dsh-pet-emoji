import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_services.dart';
import '../../core/app_links.dart';
import '../../data/models/app_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_chip.dart';

/// 设置页：API 接入、桌宠行为、桌面窗口、许可与出处。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.services, this.onToggleCompact});

  final AppServices services;
  final VoidCallback? onToggleCompact;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _apiKey = TextEditingController(
    text: widget.services.settings.apiKey,
  );
  late final TextEditingController _baseUrl = TextEditingController(
    text: widget.services.settings.baseUrl,
  );
  bool _obscure = true;
  bool _testing = false;

  AppSettings get _settings => widget.services.settings;

  @override
  void dispose() {
    _apiKey.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  Future<void> _save(Future<void> Function(AppSettings) change) async {
    await change(_settings);
    if (mounted) setState(() {});
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final info = await widget.services.chat.refreshBalance();
    setState(() => _testing = false);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (info == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(widget.services.chat.lastError ?? '连接失败')),
      );
    } else {
      final primary = info.primary;
      messenger.showSnackBar(
        SnackBar(content: Text('连接正常，余额 ${primary?.formatted ?? '未知'}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '设置',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        children: [
          _Section(
            title: 'DeepSeek 接入',
            subtitle: '对话与余额查询都走官方开放平台，Key 只保存在本机。',
            children: [
              TextField(
                controller: _apiKey,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                  ),
                ),
                onChanged: (value) => _save(
                  (current) => widget.services.updateSettings(
                    current.copyWith(apiKey: value.trim()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _baseUrl,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: kDefaultBaseUrl,
                  helperText: '可填反向代理地址，例如 https://api.deepseek.com 或带 /v1 的网关',
                ),
                onChanged: (value) => _save(
                  (current) => widget.services.updateSettings(
                    current.copyWith(baseUrl: value.trim()),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    '模型',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: kSupportedModels.contains(settings.model)
                        ? settings.model
                        : kSupportedModels.first,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                    ),
                    items: [
                      for (final model in kSupportedModels)
                        DropdownMenuItem(value: model, child: Text(model)),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _save(
                        (current) => widget.services.updateSettings(
                          current.copyWith(model: value),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          )
                        : const Icon(Icons.wifi_tethering_rounded, size: 15),
                    label: const Text('测试连接'),
                  ),
                ],
              ),
            ],
          ),
          _Section(
            title: '桌宠行为',
            subtitle: '表情由本地语义分析驱动，开箱即用，不额外消耗 token。',
            children: [
              _SwitchRow(
                title: '空闲氛围动画',
                subtitle: '12~26 秒随机插入一段安静的小动作',
                value: settings.ambientAnimations,
                onChanged: (value) => _save(
                  (current) => widget.services.updateSettings(
                    current.copyWith(ambientAnimations: value),
                  ),
                ),
              ),
              _SwitchRow(
                title: 'DeepSeek 辅助语义标注',
                subtitle: '额外一次极小请求，让模型直接给出标签；失败会自动退回离线分析',
                value: settings.llmSemanticTagging,
                onChanged: (value) => _save(
                  (current) => widget.services.updateSettings(
                    current.copyWith(llmSemanticTagging: value),
                  ),
                ),
              ),
              _SwitchRow(
                title: '显示语义标签',
                subtitle: '在回复下方展示标签、意图与强度',
                value: settings.showSemanticPanel,
                onChanged: (value) => _save(
                  (current) => widget.services.updateSettings(
                    current.copyWith(showSemanticPanel: value),
                  ),
                ),
              ),
              _SwitchRow(
                title: '气泡转述',
                subtitle: '让桌宠用一句话复述回复',
                value: settings.speechBubble,
                onChanged: (value) => _save(
                  (current) => widget.services.updateSettings(
                    current.copyWith(speechBubble: value),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    '桌宠尺寸',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<double>(
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          textStyle: WidgetStateProperty.all(
                            const TextStyle(fontSize: 12),
                          ),
                        ),
                        segments: const [
                          ButtonSegment(value: 0.5, label: Text('半尺寸')),
                          ButtonSegment(value: 1, label: Text('原尺寸')),
                          ButtonSegment(value: 2, label: Text('2×')),
                        ],
                        selected: {settings.normalizedPetZoom},
                        onSelectionChanged: (selection) => _save(
                          (current) => widget.services.updateSettings(
                            current.copyWith(petZoom: selection.first),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '「原尺寸」按素材原生 640×360 显示，与 WebM 母版一致、不拉伸；'
                '「半尺寸」是等比缩小，依旧锐利；「2×」用最近邻整数放大，边界是硬像素。',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.55,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          if (widget.services.isDesktop)
            _Section(
              title: '桌面窗口',
              subtitle: '无边框置顶小窗，适合把宠物摆在角落。',
              children: [
                _SwitchRow(
                  title: '始终置顶',
                  subtitle: '小窗模式下压在其他窗口之上',
                  value: settings.petWindowAlwaysOnTop,
                  onChanged: (value) => _save(
                    (current) => widget.services.updateSettings(
                      current.copyWith(petWindowAlwaysOnTop: value),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                for (final background in PetWindowBackground.values)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _save(
                      (current) => widget.services.updateSettings(
                        current.copyWith(petWindowBackground: background),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            settings.petWindowBackground == background
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 18,
                            color: settings.petWindowBackground == background
                                ? AppColors.primary
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  background.label,
                                  style: const TextStyle(fontSize: 13.5),
                                ),
                                Text(
                                  background.description,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.onToggleCompact != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: OutlinedButton.icon(
                      onPressed: widget.onToggleCompact,
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: const Text('进入桌面小窗'),
                    ),
                  ),
              ],
            ),
          _LicenseSection(),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '$kAppNameEn v$kVersion · 代码 MIT · 素材 CC BY-NC-SA 4.0',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  height: 1.5,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeThumbColor: AppColors.primary,
      title: Text(title, style: const TextStyle(fontSize: 13.5)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 11.5,
          color: AppColors.textTertiary,
          height: 1.4,
        ),
      ),
    );
  }
}

class _LicenseSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '许可与出处',
      subtitle: '本项目是 dsh-pet 的 Flutter 重写；形象与素材的授权独立于代码。',
      children: [
        const _LinkLine(label: '原作者仓库', value: kUpstreamRepoUrl),
        const _LinkLine(label: '本项目仓库', value: kRepoUrl),
        const _LinkLine(
          label: '形象原型',
          value: '「溟月」$kPrototypeAuthor\n$kPrototypeAuthorUrl',
        ),
        const _LinkLine(
          label: 'DeepSeek 版设计',
          value: '女仆鲸鱼娘 $kDeepSeekDesigner\n$kDeepSeekDesignerUrl',
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  SoftTag('形象授权'),
                  SizedBox(width: 6),
                  SoftTag('CC BY-NC-SA 4.0'),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                kLicenseStatement,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '衍生 / 改版 / 换皮作品须在 GitHub 仓库、产品官网等公开渠道附上：\n$kUpstreamRepoUrl',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkLine extends StatelessWidget {
  const _LinkLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 12,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          IconButton(
            tooltip: '复制',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text('已复制'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            icon: const Icon(
              Icons.copy_rounded,
              size: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
