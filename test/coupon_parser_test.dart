import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/import/coupon_import_models.dart';
import 'package:project_clover/import/coupon_parser.dart';
import 'package:project_clover/models/offer.dart';

void main() {
  const parser = CouponParser();

  OcrPageResult page(String text) => OcrPageResult(
    sourceType: ImportSourceType.image,
    pageNumber: 1,
    text: text,
    lines: text.split('\n'),
    succeeded: true,
    duration: const Duration(milliseconds: 10),
  );

  test('parses Gregorian date formats and a date range', () {
    expect(
      parser.parseDates('有效期限 2026/08/31').selected,
      DateTime(2026, 8, 31),
    );
    expect(parser.parseDates('截止 2026-09-15').selected, DateTime(2026, 9, 15));
    expect(parser.parseDates('至 2026.10.20').selected, DateTime(2026, 10, 20));

    final range = parser.parseDates('活動期間 2026/08/01–2026/08/31');
    expect(range.start, DateTime(2026, 8, 1));
    expect(range.selected, DateTime(2026, 8, 31));
  });

  test('parses ROC year dates', () {
    expect(parser.parseDates('兌換期限 115/08/31').selected, DateTime(2026, 8, 31));
    expect(parser.parseDates('截止 115年9月2日').selected, DateTime(2026, 9, 2));
  });

  test('does not guess missing year and flags ambiguity', () {
    final missing = parser.parseDates('有效期限 8/31');
    expect(missing.selected, isNull);
    expect(missing.yearMissing, isTrue);

    final competing = parser.parseDates('印刷 2026/01/01\n日期 2026/02/02');
    expect(competing.isAmbiguous, isTrue);
    expect(competing.alternatives, isNotEmpty);
  });

  test('extracts candidate fields and preserves raw OCR', () {
    const raw = '來源：星巴克\n星巴克好友分享券\n品牌：星巴克\n買一送一\n有效期限 2026/08/31';
    final candidate = parser.parse(page(raw));

    expect(candidate.title, '星巴克好友分享券');
    expect(candidate.merchant, '星巴克');
    expect(candidate.brand, '星巴克');
    expect(candidate.promotionConditions, contains('買一送一'));
    expect(candidate.category, OfferCategory.diningVoucher);
    expect(candidate.expirationDate, DateTime(2026, 8, 31));
    expect(candidate.rawText, raw);
    expect(candidate.confidence, ImportConfidence.high);
  });

  test('missing required values produce low-confidence attention fields', () {
    final candidate = parser.parse(page('注意事項\n本券不得兌換現金'));
    expect(candidate.expirationDate, isNull);
    expect(candidate.attentionFields, contains('缺少到期日'));
    expect(candidate.confidence, ImportConfidence.low);
  });

  test('failed pages do not discard successful PDF pages', () {
    final values = parser.parsePages([
      page('餐飲折價券\n現折100元\n截止 2026/12/31'),
      const OcrPageResult(
        sourceType: ImportSourceType.pdf,
        pageNumber: 2,
        text: '',
        lines: [],
        succeeded: false,
        duration: Duration(milliseconds: 1),
      ),
    ]);
    expect(values, hasLength(1));
  });

  test('does not use a phone status-bar time as the coupon title', () {
    final candidate = parser.parse(
      page(
        '20:43 4G 71%\nFamilyMart 全家便利商店\n牛乳成分50%以上 濃厚\n特價39元\n有效期限 2026/08/31',
      ),
    );

    expect(candidate.title, isNot(startsWith('20:43')));
    expect(candidate.title, contains('牛乳'));
  });

  test('catalogue fixture requires 100% correct candidates', () {
    final positioned = <OcrTextLine>[
      const OcrTextLine(
        text: '優惠期間 2026/04/13 2026/05/10',
        left: 0.25,
        top: 0.01,
        right: 0.75,
        bottom: 0.04,
      ),
    ];
    const expected = 10;
    for (var index = 0; index < expected; index++) {
      final row = index ~/ 5;
      final column = index % 5;
      final x = 0.05 + column * 0.2;
      final titleY = row == 0 ? 0.10 : 0.51;
      final itemY = row == 0 ? 0.25 : 0.66;
      positioned.addAll([
        OcrTextLine(
          text: '品牌$index 商品$index',
          left: x,
          top: titleY,
          right: x + 0.12,
          bottom: titleY + 0.03,
        ),
        OcrTextLine(
          text: 'ITEM ${10000 + index}',
          left: x,
          top: itemY,
          right: x + 0.10,
          bottom: itemY + 0.03,
        ),
        OcrTextLine(
          text: '-${100 + index}',
          left: x,
          top: itemY + 0.07,
          right: x + 0.06,
          bottom: itemY + 0.10,
        ),
      ]);
    }
    final source = OcrPageResult(
      sourceType: ImportSourceType.pdf,
      pageNumber: 2,
      text: positioned.map((line) => line.text).join('\n'),
      lines: positioned.map((line) => line.text).toList(),
      positionedLines: positioned,
      succeeded: true,
      duration: const Duration(seconds: 1),
    );

    final candidates = parser.parsePages([source]);
    final correct = candidates
        .where(
          (candidate) =>
              candidate.title.contains('商品') &&
              candidate.expirationDate == DateTime(2026, 5, 10) &&
              candidate.savings != null,
        )
        .length;

    expect(candidates, hasLength(expected));
    expect(correct, expected);
  });
}
