import 'package:flutter/material.dart';

import '../../app_services.dart';
import '../../data/models/animation_clip.dart';
import '../../data/models/balance_info.dart';
import '../theme/app_theme.dart';
import '../widgets/tag_chip.dart';

/// 余额面板：查询 DeepSeek 账户余额，并按档位同步桌宠动画。
Future<void> showBalanceSheet(BuildContext context, AppServices services) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => BalanceSheet(services: services),
  );
}

class BalanceSheet extends StatefulWidget {
  const BalanceSheet({super.key, required this.services});

  final AppServices services;

  @override
  State<BalanceSheet> createState() => _BalanceSheetState();
}

class _BalanceSheetState extends State<BalanceSheet> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    await widget.services.chat.refreshBalance();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.services.chat;
    return AnimatedBuilder(
      animation: chat,
      builder: (context, _) {
        final info = chat.balance;
        final primary = info?.primary;
        final tier = primary?.tier;
        final tierClips = tier == null
            ? const <AnimationClip>[]
            : widget.services.animations.clipsWithTag(tier.tagId);
        final clip = tierClips.isEmpty ? null : tierClips.first;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Text(
                      'DeepSeek 账户余额',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _loading ? null : _refresh,
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 1.8),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      tooltip: '刷新',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (chat.lastError != null && info == null)
                  _ErrorBox(message: chat.lastError!, onRetry: _refresh)
                else
                  _AmountBlock(primary: primary, loading: _loading && info == null),
                if (primary != null) ...[
                  const SizedBox(height: 18),
                  _Breakdown(entry: primary),
                  const SizedBox(height: 16),
                  if (tier != null) ...[
                    Row(
                      children: [
                        SoftTag('档位 · ${tier.label}', icon: Icons.emoji_emotions_outlined),
                        const SizedBox(width: 8),
                        if (clip != null) SoftTag('表情 · ${clip.name}', icon: Icons.movie_outlined),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _tierHint(tier),
                      style: const TextStyle(fontSize: 12, color: AppColors.textTertiary, height: 1.5),
                    ),
                  ],
                  if (info?.fetchedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        '更新于 ${_time(info!.fetchedAt!)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('知道了'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _tierHint(BalanceTier tier) => switch (tier) {
        BalanceTier.empty => '余额已耗尽，桌宠会翻出空钱袋——记得去 platform.deepseek.com 充值。',
        BalanceTier.low => '不足 ¥5，够聊几句。桌宠在数金币，眉头皱得厉害。',
        BalanceTier.normal => '够日常使用。桌宠的钱袋不响也不瘪，刚刚好。',
        BalanceTier.good => '还算宽裕，金币叮当作响。',
        BalanceTier.rich => '钱袋满溢，桌宠已经开始得意了。',
      };

  String _time(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}

class _AmountBlock extends StatelessWidget {
  const _AmountBlock({required this.primary, required this.loading});

  final BalanceEntry? primary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (primary == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            ),
            const SizedBox(width: 10),
            Text(
              loading ? '查询中…' : '暂无数据',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            primary!.symbol,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.6),
          ),
          Text(
            primary!.totalBalance.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              primary!.currency,
              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.entry});

  final BalanceEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _Cell(label: '充值余额', value: entry.toppedUpBalance, symbol: entry.symbol)),
          Container(width: 1, height: 28, color: AppColors.border),
          Expanded(child: _Cell(label: '赠送余额', value: entry.grantedBalance, symbol: entry.symbol)),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value, required this.symbol});

  final String label;
  final double value;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary)),
        const SizedBox(height: 4),
        Text(
          '$symbol${value.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3D6D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.danger, height: 1.5),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 28),
            ),
            child: const Text('重试', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}
