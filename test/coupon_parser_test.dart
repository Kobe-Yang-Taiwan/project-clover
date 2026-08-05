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
    const raw = '星巴克好友分享券\n品牌：星巴克\n買一送一\n有效期限 2026/08/31';
    final candidate = parser.parse(page(raw));

    expect(candidate.title, '星巴克好友分享券');
    expect(candidate.merchant, '星巴克');
    expect(candidate.valueText, '買一送一');
    expect(candidate.category, OfferCategory.coffee);
    expect(candidate.expirationDate, DateTime(2026, 8, 31));
    expect(candidate.rawText, raw);
    expect(candidate.confidence, ImportConfidence.high);
  });

  test('missing required values produce low-confidence attention fields', () {
    final candidate = parser.parse(page('注意事項\n本券不得兌換現金'));
    expect(candidate.expirationDate, isNull);
    expect(candidate.attentionFields, contains('到期日'));
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
}
