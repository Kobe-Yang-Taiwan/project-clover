import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/import/coupon_import_models.dart';
import 'package:project_clover/import/coupon_parser.dart';
import 'package:project_clover/import/local_image_region_proposal.dart';
import 'package:project_clover/import/retailer_adapters.dart';

void main() {
  OcrTextLine line(String text, double x, double y) => OcrTextLine(
    text: text,
    left: x - 0.08,
    top: y - 0.02,
    right: x + 0.08,
    bottom: y + 0.02,
  );

  OcrPageResult imagePage(List<OcrTextLine> lines) => OcrPageResult(
    sourceType: ImportSourceType.image,
    pageNumber: null,
    text: lines.map((item) => item.text).join('\n'),
    lines: lines.map((item) => item.text).toList(),
    positionedLines: lines,
    succeeded: true,
    duration: const Duration(milliseconds: 1),
  );

  test('FamilyMart repeated 2 by 4 layout proposes eight local regions', () {
    const engine = LocalImageRegionProposalEngine();
    final lines = <OcrTextLine>[
      line('09:41 5G', 0.5, 0.02),
      line('FamilyMart 夏日優惠', 0.5, 0.07),
      for (var row = 0; row < 4; row++) ...[
        line('商品 ${row * 2 + 1} 特價 ${35 + row * 10}元', 0.25, 0.22 + row * 0.21),
        line('商品 ${row * 2 + 2} ${39 + row * 10}元', 0.75, 0.22 + row * 0.21),
      ],
      line('商品實際包裝以賣場陳列為準', 0.5, 0.98),
    ];

    final regions = engine.propose(
      imagePage(lines),
      adapter: RetailerAdapterRegistry.familyMart,
    );

    expect(regions, hasLength(8));
    expect(
      regions.every(
        (region) => region.signals.contains(LocalRegionSignal.priceAnchor),
      ),
      isTrue,
    );
    expect(regions.map((region) => region.id).toSet(), hasLength(8));
  });

  test('PX Mart repeated 3 by 4 layout proposes twelve local regions', () {
    const engine = LocalImageRegionProposalEngine();
    final lines = <OcrTextLine>[
      line('全聯福利中心', 0.5, 0.04),
      for (var row = 0; row < 4; row++)
        for (var column = 0; column < 3; column++)
          line(
            '促銷商品 ${row * 3 + column + 1} 福利價 ${69 + row * 20 + column}元',
            (column + 0.5) / 3,
            0.18 + row * 0.23,
          ),
      line('PX Pay 滿2000回饋200點', 0.5, 0.97),
    ];

    final regions = engine.propose(
      imagePage(lines),
      adapter: RetailerAdapterRegistry.pxMart,
    );

    expect(regions, hasLength(12));
    expect(regions.map((region) => region.bounds.left).toSet(), hasLength(3));
  });

  test('missing price anchor does not create a guessed automatic product', () {
    const engine = LocalImageRegionProposalEngine();
    final lines = <OcrTextLine>[
      for (var row = 0; row < 4; row++)
        for (var column = 0; column < 2; column++)
          if (!(row == 2 && column == 1))
            line(
              '商品 ${row * 2 + column + 1} ${39 + row}元',
              (column + 0.5) / 2,
              0.2 + row * 0.22,
            ),
    ];

    final automatic = engine.propose(
      imagePage(lines),
      adapter: RetailerAdapterRegistry.familyMart,
    );
    final recovered = engine.recoverAt(
      x: 0.75,
      y: 0.64,
      existing: automatic,
      adapter: RetailerAdapterRegistry.familyMart,
    );

    expect(automatic, hasLength(7));
    expect(recovered.signals, contains(LocalRegionSignal.userTap));
    expect(recovered.contains(0.75, 0.64), isTrue);
  });

  test('corroborated product text can propose a region without a price', () {
    const engine = LocalImageRegionProposalEngine();
    final lines = <OcrTextLine>[
      line('光泉濃厚牛乳', 0.25, 0.30),
      line('400ml', 0.25, 0.35),
    ];

    final regions = engine.propose(
      imagePage(lines),
      adapter: RetailerAdapterRegistry.familyMart,
    );

    expect(regions, hasLength(1));
    expect(regions.single.signals, contains(LocalRegionSignal.productText));
    expect(
      regions.single.signals,
      isNot(contains(LocalRegionSignal.priceAnchor)),
    );
  });

  test('identical names in different image regions remain distinct', () {
    const parser = CouponParser();
    OcrPageResult crop(String regionId, double left, String price) =>
        OcrPageResult(
          sourceType: ImportSourceType.image,
          pageNumber: null,
          text: '同款鮮乳\n$price',
          lines: ['同款鮮乳', price],
          positionedLines: [
            line('同款鮮乳', left + 0.2, 0.2),
            line(price, left + 0.2, 0.3),
          ],
          sourceRegionId: regionId,
          sourceBounds: OcrRegionBounds(
            left: left,
            top: 0,
            right: left + 0.5,
            bottom: 0.5,
          ),
          sharedPositionedLines: [line('全家便利商店', 0.5, 0.02)],
          succeeded: true,
          duration: const Duration(milliseconds: 1),
        );

    final result = parser.parsePagesDetailed([
      crop('card-a', 0, '39元'),
      crop('card-b', 0.5, '45元'),
    ], documentMerchant: 'FamilyMart 全家便利商店');

    expect(result.candidates, hasLength(2));
    expect(result.candidates.map((item) => item.sourceRegionId).toSet(), {
      'card-a',
      'card-b',
    });
    expect(result.candidates.map((item) => item.promotionalPrice).toSet(), {
      39,
      45,
    });
  });

  test('combined product and price OCR keeps identity and price semantics', () {
    const parser = CouponParser();
    final result = parser.parsePagesDetailed([
      OcrPageResult(
        sourceType: ImportSourceType.image,
        pageNumber: null,
        text: '光泉鮮乳 特價 39元',
        lines: const ['光泉鮮乳 特價 39元'],
        positionedLines: [line('光泉鮮乳 特價 39元', 0.25, 0.25)],
        sourceRegionId: 'card-a',
        sourceBounds: const OcrRegionBounds(
          left: 0,
          top: 0,
          right: 0.5,
          bottom: 0.5,
        ),
        succeeded: true,
        duration: const Duration(milliseconds: 1),
      ),
    ], documentMerchant: 'FamilyMart 全家便利商店');

    expect(result.candidates.single.title, '光泉鮮乳');
    expect(result.candidates.single.promotionalPrice, 39);
  });

  test('price-only proposed region creates zero candidates', () {
    const parser = CouponParser();
    final result = parser.parsePagesDetailed([
      OcrPageResult(
        sourceType: ImportSourceType.image,
        pageNumber: null,
        text: r'$89',
        lines: const [r'$89'],
        positionedLines: [line(r'$89', 0.25, 0.25)],
        sourceRegionId: 'price-only',
        sourceBounds: const OcrRegionBounds(
          left: 0,
          top: 0,
          right: 0.5,
          bottom: 0.5,
        ),
        succeeded: true,
        duration: const Duration(milliseconds: 1),
      ),
    ]);

    expect(result.candidates, isEmpty);
    expect(result.excludedCandidates, hasLength(1));
  });
}
