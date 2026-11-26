/// 余额档位。档位直接对应 6 段「余额」系列动画。
enum BalanceTier {
  empty('余额耗尽', 'balance_empty'),
  low('余额偏低', 'balance_low'),
  normal('余额正常', 'balance_normal'),
  good('余额充足', 'balance_good'),
  rich('余额富余', 'balance_rich');

  const BalanceTier(this.label, this.tagId);

  final String label;
  final String tagId;

  /// 分档阈值（元）。与 `docs/TAGS.md` 中的表格保持一致。
  static const double lowThreshold = 0;
  static const double normalThreshold = 5;
  static const double goodThreshold = 20;
  static const double richThreshold = 100;

  static BalanceTier fromAmount(double amount) {
    if (amount <= lowThreshold) return BalanceTier.empty;
    if (amount < normalThreshold) return BalanceTier.low;
    if (amount < goodThreshold) return BalanceTier.normal;
    if (amount < richThreshold) return BalanceTier.good;
    return BalanceTier.rich;
  }
}

/// 单个币种的余额明细。
class BalanceEntry {
  const BalanceEntry({
    required this.currency,
    required this.totalBalance,
    required this.grantedBalance,
    required this.toppedUpBalance,
  });

  final String currency;
  final double totalBalance;
  final double grantedBalance;
  final double toppedUpBalance;

  String get symbol => switch (currency.toUpperCase()) {
        'CNY' => '¥',
        'USD' => r'$',
        _ => '$currency ',
      };

  String get formatted => '$symbol${totalBalance.toStringAsFixed(2)}';

  BalanceTier get tier => BalanceTier.fromAmount(totalBalance);

  static BalanceEntry fromJson(Map<String, dynamic> json) {
    return BalanceEntry(
      currency: json['currency'] as String? ?? 'CNY',
      totalBalance: _toDouble(json['total_balance']),
      grantedBalance: _toDouble(json['granted_balance']),
      toppedUpBalance: _toDouble(json['topped_up_balance']),
    );
  }

  static double _toDouble(Object? raw) =>
      raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
}

/// `GET /user/balance` 的返回结构。
class BalanceInfo {
  const BalanceInfo({
    required this.isAvailable,
    required this.entries,
    this.fetchedAt,
  });

  final bool isAvailable;
  final List<BalanceEntry> entries;
  final DateTime? fetchedAt;

  bool get isEmpty => entries.isEmpty;

  /// 主展示条目（优先 CNY）。
  BalanceEntry? get primary {
    if (entries.isEmpty) return null;
    for (final entry in entries) {
      if (entry.currency.toUpperCase() == 'CNY') return entry;
    }
    return entries.first;
  }

  static BalanceInfo fromJson(Map<String, dynamic> json) {
    final infos = json['balance_infos'] as List<dynamic>? ?? const [];
    return BalanceInfo(
      isAvailable: json['is_available'] as bool? ?? false,
      entries: infos
          .map((item) => BalanceEntry.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      fetchedAt: DateTime.now(),
    );
  }
}
