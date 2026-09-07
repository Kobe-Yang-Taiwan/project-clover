import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/import/coupon_import_models.dart';
import 'package:project_clover/import/coupon_parser.dart';
import 'package:project_clover/import/document_understanding.dart';
import 'package:project_clover/models/offer.dart';

void main() {
  const parser = CouponParser();

  OcrPageResult textPage(String text) => OcrPageResult(
    sourceType: ImportSourceType.pdf,
    pageNumber: 1,
    text: text,
    lines: text.split('\n'),
    succeeded: true,
    duration: const Duration(milliseconds: 10),
  );

  OcrTextLine line(
    String text,
    double left,
    double top, {
    double width = 0.32,
    double height = 0.035,
  }) => OcrTextLine(
    text: text,
    left: left,
    top: top,
    right: left + width,
    bottom: top + height,
  );

  OcrPageResult positionedPage(List<OcrTextLine> lines) => OcrPageResult(
    sourceType: ImportSourceType.pdf,
    pageNumber: 2,
    text: lines.map((value) => value.text).join('\n'),
    lines: lines.map((value) => value.text).toList(),
    positionedLines: lines,
    succeeded: true,
    duration: const Duration(milliseconds: 20),
  );

  const invalidFragments = <String>[
    '36包入(CT)',
    '36包入(PK)',
    '2袋入(CT)',
    '30瓶入(PK)',
    '24罐入(CAN)',
    '12瓶入(PK)',
    '12個入(CT)',
    '6入(CT)',
    '40包入(CT)',
    '【賣場售價】',
    '僅限好市多',
    '商品實際顏色及尺寸以官網為準',
    '商品實際包裝以賣場陳列為準',
    '衛署醫器輸字第014442號 製造商資訊',
    '每會員卡限購 2 組，恕不接受轉售',
  ];

  for (final fragment in invalidFragments) {
    test('non-product fragment is excluded: $fragment', () {
      final result = parser.parsePagesDetailed([textPage(fragment)]);

      expect(result.candidates, isEmpty);
    });
  }

  test('adjacent bedding and frozen cranberries never contaminate', () {
    final source = positionedPage([
      line('Costco 好市多 優惠期間 2026/08/01-2026/08/31', 0.05, 0.01, width: 0.9),
      line('SEALY 雙人床墊 寢具組', 0.05, 0.12),
      line('ITEM 111111', 0.08, 0.28, width: 0.18),
      line('優惠價 19999', 0.08, 0.34, width: 0.18),
      line('KIRKLAND FROZEN CRANBERRIES 2kg', 0.55, 0.12, width: 0.4),
      line('ITEM 222222', 0.58, 0.28, width: 0.18),
      line('優惠價 399', 0.58, 0.34, width: 0.18),
    ]);

    final result = parser.parsePagesDetailed([source]);

    expect(result.candidates, hasLength(2));
    final bedding = result.candidates.singleWhere(
      (candidate) => candidate.itemNumber == '111111',
    );
    final fruit = result.candidates.singleWhere(
      (candidate) => candidate.itemNumber == '222222',
    );
    expect(bedding.title, contains('床墊'));
    expect(bedding.title, isNot(contains('CRANBERRIES')));
    expect(bedding.promotionalPrice, 19999);
    expect(fruit.title, contains('CRANBERRIES'));
    expect(fruit.title, isNot(contains('床墊')));
    expect(fruit.promotionalPrice, 399);
    expect(bedding.sourceRegionId, isNot(fruit.sourceRegionId));
    expect(result.report.crossCellContaminationCount, 0);
  });

  test('multi-product image creates one candidate per product card', () {
    final sourceLines = <OcrTextLine>[
      line('20:43 5G 71%', 0.02, 0.005, width: 0.2),
      line('全聯福利中心 本期優惠專區', 0.15, 0.04, width: 0.7),
      line('優惠期間 2026/08/01-2026/08/31', 0.2, 0.075, width: 0.6),
    ];
    for (var index = 0; index < 3; index++) {
      final x = 0.05 + index * 0.32;
      sourceLines.addAll([
        line('品牌$index 商品$index 500ml', x, 0.18, width: 0.25),
        line('ITEM ${700000 + index}', x, 0.31, width: 0.18),
        line('優惠價 ${50 + index * 10}', x, 0.37, width: 0.18),
      ]);
    }

    final result = parser.parsePagesDetailed([positionedPage(sourceLines)]);

    expect(result.candidates, hasLength(3));
    expect(result.candidates.map((value) => value.itemNumber).toSet(), {
      '700000',
      '700001',
      '700002',
    });
    expect(
      result.candidates.every(
        (candidate) =>
            !candidate.title.contains('優惠專區') &&
            !candidate.title.contains('20:43'),
      ),
      isTrue,
    );
  });

  test('plain price anchors separate cards but require confirmation', () {
    final result = parser.parsePagesDetailed([
      positionedPage([
        line('全聯福利中心 優惠期間 2026/08/01-2026/08/31', 0.05, 0.02, width: 0.9),
        line('義美 牛乳 936ml', 0.05, 0.15),
        line(r'$69', 0.10, 0.30, width: 0.12),
        line('桂格 燕麥飲 400ml', 0.55, 0.15),
        line('79元', 0.60, 0.30, width: 0.12),
      ]),
    ]);

    expect(result.candidates, hasLength(2));
    expect(result.candidates.map((value) => value.promotionalPrice), [69, 79]);
    expect(
      result.candidates.every(
        (candidate) =>
            candidate.state == CandidateState.needsReview &&
            candidate.attentionFields.contains('優惠價需要確認'),
      ),
      isTrue,
    );
  });

  test('page date is inherited only from explicit promotion validity', () {
    final unrelated = parser
        .parsePagesDetailed([
          textPage('Costco 好市多\n測試商品主體\nITEM 123456\n優惠價 999\n印刷日期 2026/08/31'),
        ])
        .candidates
        .single;
    expect(unrelated.expirationDate, isNull);
    expect(unrelated.state, CandidateState.needsReview);

    final inherited = parser
        .parsePagesDetailed([
          textPage(
            'Costco 好市多\n優惠期間 2026/08/01-2026/08/31\n'
            '測試商品主體\nITEM 123456\n優惠價 999',
          ),
        ])
        .candidates
        .single;
    expect(inherited.expirationDate, DateTime(2026, 8, 31));
    expect(inherited.state, CandidateState.ready);
  });

  test('missing price and date stay unknown rather than fabricated', () {
    final candidate = parser
        .parsePagesDetailed([
          textPage('Costco 好市多\nTP-LINK DECO X55 路由器\nITEM 123456'),
        ])
        .candidates
        .single;

    expect(candidate.originalPrice, isNull);
    expect(candidate.promotionalPrice, isNull);
    expect(candidate.savings, isNull);
    expect(candidate.expirationDate, isNull);
    expect(candidate.state, CandidateState.needsReview);
    expect(candidate.selected, isFalse);
  });

  test(
    'native Costco price stack preserves original discount and sale roles',
    () {
      final lines = [
        line('Costco 好市多 優惠期間 2026/04/13-2026/05/10', 0.02, 0.01, width: 0.96),
        line('TP-LINK DECO X55 雙頻路由器', 0.05, 0.12),
        line('ITEM 142138', 0.05, 0.20, width: 0.18),
        line('3,549', 0.10, 0.28, width: 0.12),
        line('-710', 0.10, 0.33, width: 0.12),
        line(r'$2,839', 0.10, 0.38, width: 0.12),
        line('【賣場售價】', 0.08, 0.43, width: 0.18),
      ];
      final source = OcrPageResult(
        sourceType: ImportSourceType.pdf,
        pageNumber: 2,
        text: lines.map((value) => value.text).join('\n'),
        lines: lines.map((value) => value.text).toList(),
        positionedLines: lines,
        succeeded: true,
        duration: Duration.zero,
        extractionMethod: ImportExtractionMethod.nativePdfText,
      );

      final candidate = parser.parsePagesDetailed([source]).candidates.single;

      expect(candidate.originalPrice, 3549);
      expect(candidate.promotionalPrice, 2839);
      expect(candidate.savings, 710);
      expect(
        candidate.fieldEvidence['product_name']?.regionId,
        candidate.sourceRegionId,
      );
      expect(
        candidate.fieldEvidence['promo_price']?.regionId,
        candidate.sourceRegionId,
      );
      expect(candidate.fieldEvidence['valid_until']?.regionId, 'p2-shared');
    },
  );

  test('native Costco columns preserve asymmetric product-cell ownership', () {
    const pipeline = DocumentUnderstandingPipeline();
    final lines = <OcrTextLine>[
      line('Costco 好市多 優惠期間 2026/04/13-2026/05/10', 0.02, 0.01, width: 0.96),
      for (var column = 0; column < 4; column++) ...[
        line('C$column TOP PRODUCT', column * 0.25 + 0.02, 0.12, width: 0.20),
        line('-100', column * 0.25 + 0.08, 0.25, width: 0.08),
        if (column == 2) line('-120', column * 0.25 + 0.15, 0.27, width: 0.06),
      ],
      for (final column in [0, 2, 3]) ...[
        line(
          'C$column BOTTOM PRODUCT',
          column * 0.25 + 0.02,
          0.58,
          width: 0.20,
        ),
        line('-200', column * 0.25 + 0.08, 0.70, width: 0.08),
      ],
    ];
    final source = OcrPageResult(
      sourceType: ImportSourceType.pdf,
      pageNumber: 6,
      text: lines.map((value) => value.text).join('\n'),
      lines: lines.map((value) => value.text).toList(),
      positionedLines: lines,
      succeeded: true,
      duration: Duration.zero,
      extractionMethod: ImportExtractionMethod.nativePdfText,
    );

    final result = pipeline.understand(source);

    expect(result.regions, hasLength(7));
    expect(
      result.regions.every((region) {
        final columnNames = region.lines
            .where((value) => value.contains('PRODUCT'))
            .map((value) => value.substring(0, 2))
            .toSet();
        return columnNames.length <= 1;
      }),
      isTrue,
    );
  });

  test('layout-aware structured markdown preserves product-cell ownership', () {
    const pipeline = DocumentUnderstandingPipeline();
    final source = positionedPage([
      line('Costco 好市多 優惠期間 2026/08/01-2026/08/31', 0.05, 0.01, width: 0.9),
      line('商品 A', 0.05, 0.12),
      line('ITEM 111111', 0.08, 0.28, width: 0.18),
      line('優惠價 199', 0.08, 0.34, width: 0.18),
      line('商品 B', 0.55, 0.12),
      line('ITEM 222222', 0.58, 0.28, width: 0.18),
      line('優惠價 299', 0.58, 0.34, width: 0.18),
    ]);

    final markdown = pipeline
        .understand(source)
        .toStructuredMarkdown(pageNumber: 2, merchant: 'Costco 好市多');

    expect(markdown, contains('## Product Cell 1'));
    expect(markdown, contains('## Product Cell 2'));
    expect(markdown, contains('itemNumber: ITEM 111111'));
    expect(markdown, contains('itemNumber: ITEM 222222'));
  });

  test('labeled quality metrics expose precision recall and review burden', () {
    const metrics = LabeledImportQualityMetrics(
      actualProductCount: 10,
      generatedCandidateCount: 10,
      matchedProductCount: 10,
      falseCandidateCount: 0,
      missedProductCount: 0,
      directImportCount: 8,
      needsConfirmationCount: 2,
      excludedCount: 15,
      duplicateCandidateCount: 0,
      crossCellContaminationCount: 0,
      correctRequiredFieldCount: 78,
      evaluatedRequiredFieldCount: 80,
      proposedProductRegionCount: 10,
      noTypingProductCount: 10,
      recoveryActionCount: 1,
      manualTextEntryCount: 0,
      cloudRequestCount: 0,
    );

    expect(metrics.candidatePrecision, 1);
    expect(metrics.candidateRecall, 1);
    expect(metrics.fieldAccuracy, 0.975);
    expect(metrics.duplicateRate, 0);
    expect(metrics.reviewBurden, 1);
    expect(metrics.noTypingImportRate, 1);
    expect(metrics.toJson()['cloud_requests_used'], 0);
  });

  test('final validation gate checks promotion and price relationships', () {
    final valid = CouponCandidate(
      id: 'valid',
      title: '測試商品',
      merchant: '測試商店',
      expirationDate: DateTime(2026, 12, 31),
      originalPrice: 120,
      promotionalPrice: 100,
      savings: 20,
      rawText: '測試商品',
      sourcePage: 1,
      category: OfferCategory.others,
      confidence: ImportConfidence.high,
      attentionFields: const [],
    );
    expect(valid.passesFinalValidation, isTrue);
    expect(
      valid.copyWith(promotionalPrice: 130).passesFinalValidation,
      isFalse,
    );
    expect(valid.copyWith(savings: 10).passesFinalValidation, isFalse);
    expect(
      valid
          .copyWith(clearPromotionalPrice: true, clearSavings: true)
          .passesFinalValidation,
      isFalse,
    );
  });
}
