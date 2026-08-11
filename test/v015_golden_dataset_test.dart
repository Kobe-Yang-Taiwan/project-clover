import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/import/coupon_import_models.dart';
import 'package:project_clover/import/coupon_parser.dart';
import 'package:project_clover/models/offer.dart';

void main() {
  const parser = CouponParser();

  OcrPageResult page(String text, {List<OcrTextLine> positioned = const []}) =>
      OcrPageResult(
        sourceType: ImportSourceType.image,
        pageNumber: 1,
        text: text,
        lines: text.split('\n'),
        positionedLines: positioned,
        succeeded: true,
        duration: const Duration(milliseconds: 12),
      );

  test('golden A: one screenshot becomes multiple product candidates', () {
    const lines = <OcrTextLine>[
      OcrTextLine(
        text: '全聯福利中心 優惠期間 2026/08/01-2026/08/31',
        left: 0.05,
        top: 0.01,
        right: 0.95,
        bottom: 0.04,
      ),
      OcrTextLine(
        text: '義美 牛乳 936ml',
        left: 0.05,
        top: 0.15,
        right: 0.40,
        bottom: 0.20,
      ),
      OcrTextLine(
        text: '優惠價 69',
        left: 0.10,
        top: 0.30,
        right: 0.30,
        bottom: 0.35,
      ),
      OcrTextLine(
        text: '桂格 燕麥飲 400ml',
        left: 0.55,
        top: 0.15,
        right: 0.90,
        bottom: 0.20,
      ),
      OcrTextLine(
        text: '優惠價 79',
        left: 0.62,
        top: 0.30,
        right: 0.82,
        bottom: 0.35,
      ),
    ];
    final source = page(
      lines.map((line) => line.text).join('\n'),
      positioned: lines,
    );

    final result = parser.parsePagesDetailed([source]);

    expect(result.candidates, hasLength(2));
    expect(result.candidates.map((item) => item.merchant).toSet(), {'全聯福利中心'});
    expect(result.candidates.map((item) => item.promotionalPrice), [69, 79]);
  });

  test('golden B: Costco product region keeps merchant and brand separate', () {
    final candidate = parser.parsePages([
      page(
        'Costco 好市多\n品牌：TP-LINK\nTP-LINK DECO X55 Mesh 雙頻路由器\n'
        'ITEM 123456\n原價 13,999\n賣場售價 11,999\n'
        '優惠期間 2026/08/01-2026/08/31\n線上購物亦有優惠',
      ),
    ]).single;

    expect(candidate.merchant, 'Costco 好市多');
    expect(candidate.brand, 'TP-LINK');
    expect(candidate.title, contains('DECO X55'));
    expect(candidate.title, isNot(contains('11,999')));
    expect(candidate.originalPrice, 13999);
    expect(candidate.promotionalPrice, 11999);
    expect(candidate.savings, 2000);
    expect(candidate.promotionConditions, contains('線上購物亦有優惠'));
  });

  test('golden C: a valid single coupon remains one candidate', () {
    final candidate = parser.parsePages([
      page(
        '來源：星巴克\n品牌：STARBUCKS\n星巴克好友分享券\n買一送一\n'
        '有效期限 2026/08/31',
      ),
    ]).single;

    expect(candidate.title, '星巴克好友分享券');
    expect(candidate.state, CandidateState.ready);
    expect(candidate.selected, isTrue);
  });

  test(
    'golden D/K/L: disclaimers prices and campaign headers are rejected',
    () {
      final candidates = parser.parsePages([
        page(
          '中元優惠專區\n售價以官網為準\n線上購物亦有優惠\n'
          r'$11,999'
          '\n-6,000\n活動數量有限\n售完為止',
        ),
      ]);

      expect(candidates, isEmpty);
    },
  );

  test('golden E: missing original price remains null', () {
    final candidate = parser.parse(
      page(
        '來源：家樂福\nWHIRLPOOL 惠而浦 定頻除濕機 20L\n'
        '優惠價 9,999\n有效期限 2026/08/31',
      ),
    );

    expect(candidate.originalPrice, isNull);
    expect(candidate.promotionalPrice, 9999);
    expect(candidate.savings, isNull);
    expect(candidate.valueText, contains('原價：未提供'));
  });

  test(
    'golden F: bundle and threshold prices are conditions not original price',
    () {
      final candidate = parser.parse(
        page(
          '來源：全聯福利中心\n堅果隨手包 30g\n任選 2 件 199 元\n'
          '滿 2,000 送 300\n有效期限 2026/08/31',
        ),
      );

      expect(candidate.originalPrice, isNull);
      expect(candidate.promotionConditions, contains('任選 2 件 199 元'));
      expect(candidate.promotionConditions, contains('滿 2,000 送 300'));
    },
  );

  test('golden G: multiple nearby dates require review', () {
    final candidate = parser.parse(
      page(
        '來源：測試商店\n測試商品組\n優惠價 999\n'
        '印刷 2026/01/01\n日期 2026/02/02',
      ),
    );

    expect(candidate.state, CandidateState.needsReview);
    expect(candidate.attentionFields, contains('到期日需要確認'));
    expect(candidate.selected, isFalse);
  });

  test('golden H: same brand with different ITEM stays separate', () {
    final values = parser.parsePages([
      page(
        'Costco\nTP-LINK 路由器 A\nITEM 11111\n優惠價 999\n'
        '有效期限 2026/08/31\n---\nTP-LINK 路由器 B\nITEM 22222\n'
        '優惠價 1,999\n有效期限 2026/08/31',
      ),
    ]);

    expect(values, hasLength(2));
    expect(values.map((item) => item.itemNumber).toSet(), {'11111', '22222'});
  });

  test('golden I: status bar and navigation are not product titles', () {
    final candidate = parser.parse(
      page(
        '20:43 5G 71%\n首頁\n來源：全家便利商店\n光泉濃厚牛乳 400ml\n'
        '優惠價 39\n有效期限 2026/08/31',
      ),
    );

    expect(candidate.title, contains('牛乳'));
    expect(candidate.title, isNot(startsWith('20:43')));
  });

  test('golden J: fragments with the same ITEM merge to one candidate', () {
    final values = parser.parsePages([
      page(
        'Costco\nMIO MiVue 955W 行車記錄器\nITEM 98765\n優惠價 9,999\n'
        '有效期限 2026/08/31\n---\nMIO MiVue 955W 雙 2K 鏡頭\n'
        'ITEM 98765\n原價 11,999\n有效期限 2026/08/31',
      ),
    ]);

    expect(values, hasLength(1));
    expect(values.single.itemNumber, '98765');
  });

  test('price semantics never fabricate savings', () {
    final ambiguous = parser.parse(
      page(
        '來源：測試商店\n測試家電產品\n9,999\n11,999\n'
        '有效期限 2026/08/31',
      ),
    );
    expect(ambiguous.originalPrice, isNull);
    expect(ambiguous.promotionalPrice, isNull);
    expect(ambiguous.savings, isNull);
    expect(ambiguous.state, CandidateState.needsReview);

    final valid = parser.parse(
      page(
        '來源：測試商店\n測試家電產品\n原價 11,999\n優惠價 9,999\n'
        '有效期限 2026/08/31',
      ),
    );
    expect(valid.savings, 2000);
  });

  test('controlled category classification uses product context', () {
    expect(
      parser.suggestCategory('WHIRLPOOL 定頻除濕機 20L'),
      OfferCategory.appliances,
    );
    expect(
      parser.suggestCategory('TP-LINK DECO X55 Mesh 路由器'),
      OfferCategory.electronics,
    );
    expect(parser.suggestCategory('品牌相同但內容為維生素保健食品'), OfferCategory.health);
  });
}
