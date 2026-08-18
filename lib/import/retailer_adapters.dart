class RetailerAdapter {
  const RetailerAdapter({
    required this.id,
    required this.merchant,
    required this.pattern,
    this.usesRepeatedGrid = false,
    this.expectedImageColumns,
    this.productLabelHints = const [],
    this.sharedCampaignHints = const [],
  });

  final String id;
  final String merchant;
  final RegExp pattern;
  final bool usesRepeatedGrid;
  final int? expectedImageColumns;
  final List<String> productLabelHints;
  final List<String> sharedCampaignHints;

  bool matches(String value) => pattern.hasMatch(value);
}

class RetailerAdapterRegistry {
  const RetailerAdapterRegistry();

  static final RetailerAdapter costco = RetailerAdapter(
    id: 'costco',
    merchant: 'Costco 好市多',
    pattern: RegExp(r'costco|好市多', caseSensitive: false),
    usesRepeatedGrid: true,
    expectedImageColumns: 4,
    productLabelHints: const ['ITEM', '賣場售價', '現省'],
    sharedCampaignHints: const ['優惠期間', '僅限好市多', '線上購物亦有優惠'],
  );

  static final RetailerAdapter pxMart = RetailerAdapter(
    id: 'pxmart',
    merchant: '全聯福利中心',
    pattern: RegExp(r'px\s*mart|全聯(?:福利中心)?', caseSensitive: false),
    usesRepeatedGrid: true,
    expectedImageColumns: 3,
    productLabelHints: const ['特價', '福利價', '任選'],
    sharedCampaignHints: const ['全聯福利中心', '活動期間', '本期優惠'],
  );

  static final RetailerAdapter familyMart = RetailerAdapter(
    id: 'familymart',
    merchant: 'FamilyMart 全家便利商店',
    pattern: RegExp(
      r'family\s*mart|全家便利商店|全家(?:會員|優惠|行動購)?',
      caseSensitive: false,
    ),
    usesRepeatedGrid: true,
    expectedImageColumns: 2,
    productLabelHints: const ['友善食光', '會員價', '任選'],
    sharedCampaignHints: const ['FamilyMart', '全家便利商店', '活動期間'],
  );

  static final RetailerAdapter generic = RetailerAdapter(
    id: 'generic',
    merchant: '',
    pattern: RegExp(r'.*'),
  );

  RetailerAdapter resolve({required String sourceName, required String text}) {
    final evidence = '$sourceName\n$text';
    for (final adapter in <RetailerAdapter>[costco, pxMart, familyMart]) {
      if (adapter.matches(evidence)) return adapter;
    }
    return generic;
  }
}
