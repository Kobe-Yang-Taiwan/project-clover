import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_clover/import/cloud_vision_provider.dart';
import 'package:project_clover/import/coupon_import_models.dart';
import 'package:project_clover/import/coupon_parser.dart';
import 'package:project_clover/import/source_router.dart';

void main() {
  FieldEvidence evidence(
    String text,
    String regionId, {
    double confidence = 0.95,
    int? page = 1,
  }) => FieldEvidence(
    sourceType: ImportSourceType.image,
    extractionMethod: ImportExtractionMethod.cloudVision,
    sourcePage: page,
    regionId: regionId,
    rawText: text,
    confidence: confidence,
    bounds: const OcrRegionBounds(left: 0.1, top: 0.1, right: 0.4, bottom: 0.4),
  );

  test('source router keeps reliable native PDF local', () {
    const router = ImportSourceRouter();
    final decision = router.forPdf(
      const PdfSourcePlan(
        pageCount: 3,
        nativeTextPages: [1, 2, 3],
        visionPages: [],
      ),
    );

    expect(decision.route, ImportRoute.nativeTextPdf);
    expect(decision.cloudEligiblePageNumbers, isEmpty);
  });

  test('source router sends only image-only PDF pages to vision path', () {
    const router = ImportSourceRouter();
    final decision = router.forPdf(
      const PdfSourcePlan(
        pageCount: 4,
        nativeTextPages: [1, 3],
        visionPages: [2, 4],
      ),
    );

    expect(decision.route, ImportRoute.scannedPdf);
    expect(decision.cloudEligiblePageNumbers, [2, 4]);
  });

  test('canonical products require evidence and preserve cell ownership', () {
    const parser = CouponParser();
    final products = <ReconstructedProduct>[
      ReconstructedProduct(
        regionId: 'card-a',
        sourceType: ImportSourceType.image,
        sourcePage: 1,
        merchant: EvidencedValue(
          value: '全家便利商店',
          evidence: evidence('全家便利商店', 'card-a'),
        ),
        brand: EvidencedValue(value: '光泉', evidence: evidence('光泉', 'card-a')),
        productName: EvidencedValue(
          value: '濃厚牛乳',
          evidence: evidence('濃厚牛乳', 'card-a'),
        ),
        specification: EvidencedValue(
          value: '400ml',
          evidence: evidence('400ml', 'card-a'),
        ),
        validUntil: EvidencedValue(
          value: DateTime(2026, 8, 31),
          evidence: evidence('2026/08/31', 'card-a'),
        ),
        promotionalPrice: EvidencedValue(
          value: 39,
          evidence: evidence('39元', 'card-a'),
        ),
        regionEvidence: evidence('光泉濃厚牛乳 400ml 39元', 'card-a'),
      ),
      ReconstructedProduct(
        regionId: 'card-b',
        sourceType: ImportSourceType.image,
        sourcePage: 1,
        merchant: EvidencedValue(
          value: '全家便利商店',
          evidence: evidence('全家便利商店', 'card-b'),
        ),
        productName: EvidencedValue(
          value: '義美紅豆牛奶冰棒',
          evidence: evidence('義美紅豆牛奶冰棒', 'card-b'),
        ),
        validUntil: EvidencedValue(
          value: DateTime(2026, 8, 31),
          evidence: evidence('2026/08/31', 'card-b'),
        ),
        promotionalPrice: EvidencedValue(
          value: 39.8,
          evidence: evidence('特價 39.8元', 'card-b'),
        ),
        regionEvidence: evidence('義美紅豆牛奶冰棒 特價 39.8元', 'card-b'),
      ),
    ];

    final result = parser.parseAdaptive(
      SourceAdaptiveImportResult(
        route: ImportRoute.promotionalImage,
        pages: const [],
        products: products,
        cloudUsage: const CloudProcessingUsage(requestCount: 1),
      ),
    );

    expect(result.candidates, hasLength(2));
    expect(
      result.candidates[0].sourceRegionId,
      isNot(result.candidates[1].sourceRegionId),
    );
    expect(result.candidates.map((item) => item.promotionalPrice).toSet(), {
      39,
      39.8,
    });
    expect(result.report.crossCellContaminationCount, 0);
  });

  test('cross-region field evidence is rejected and counted', () {
    const parser = CouponParser();
    final product = ReconstructedProduct(
      regionId: 'card-a',
      sourceType: ImportSourceType.image,
      sourcePage: 1,
      productName: EvidencedValue(
        value: '商品 A',
        evidence: evidence('商品 A', 'card-a'),
      ),
      merchant: EvidencedValue(
        value: '全聯福利中心',
        evidence: evidence('全聯福利中心', 'card-a'),
      ),
      promotionalPrice: EvidencedValue(
        value: 99,
        evidence: evidence('99元', 'card-b'),
      ),
      validUntil: EvidencedValue(
        value: DateTime(2026, 8, 31),
        evidence: evidence('2026/08/31', 'card-a'),
      ),
      regionEvidence: evidence('商品 A 99元', 'card-a'),
    );

    final result = parser.parseAdaptive(
      SourceAdaptiveImportResult(
        route: ImportRoute.promotionalImage,
        pages: const [],
        products: [product],
        cloudUsage: const CloudProcessingUsage(requestCount: 1),
      ),
    );

    expect(result.candidates, isEmpty);
    expect(result.excludedCandidates, hasLength(1));
    expect(result.report.crossCellContaminationCount, 1);
  });

  test('explicit page-level validity may be shared without contamination', () {
    const parser = CouponParser();
    final product = ReconstructedProduct(
      regionId: 'card-a',
      sourceType: ImportSourceType.image,
      sourcePage: 1,
      productName: EvidencedValue(
        value: '商品 A',
        evidence: evidence('商品 A', 'card-a'),
      ),
      merchant: EvidencedValue(
        value: '全聯福利中心',
        evidence: evidence('全聯福利中心', 'page-shared'),
      ),
      promotionalPrice: EvidencedValue(
        value: 99,
        evidence: evidence('99元', 'card-a'),
      ),
      validUntil: EvidencedValue(
        value: DateTime(2026, 8, 31),
        evidence: evidence('活動期間至 2026/08/31', 'campaign-banner'),
      ),
      regionEvidence: evidence('商品 A 99元', 'card-a'),
    );

    final result = parser.parseAdaptive(
      SourceAdaptiveImportResult(
        route: ImportRoute.promotionalImage,
        pages: const [],
        products: [product],
        cloudUsage: const CloudProcessingUsage(requestCount: 1),
      ),
    );

    expect(result.candidates, hasLength(1));
    expect(result.report.crossCellContaminationCount, 0);
  });

  test('average unit price cannot become the promotional price', () {
    const parser = CouponParser();
    final product = ReconstructedProduct(
      regionId: 'card-a',
      sourceType: ImportSourceType.image,
      sourcePage: 1,
      productName: EvidencedValue(
        value: '舒跑運動飲料 250ml 6入組',
        evidence: evidence('舒跑運動飲料 250ml 6入組', 'card-a'),
      ),
      merchant: EvidencedValue(
        value: '全聯福利中心',
        evidence: evidence('全聯福利中心', 'card-a'),
      ),
      promotionalPrice: EvidencedValue(
        value: 39.8,
        evidence: evidence('平均一組 39.8元', 'card-a'),
      ),
      promotionCondition: EvidencedValue(
        value: '4組159元',
        evidence: evidence('4組159元', 'card-a'),
      ),
      validUntil: EvidencedValue(
        value: DateTime(2026, 8, 13),
        evidence: evidence('2026/8/7-8/13', 'card-a'),
      ),
      regionEvidence: evidence('舒跑 4組159元 平均一組39.8元', 'card-a'),
    );

    final result = parser.parseAdaptive(
      SourceAdaptiveImportResult(
        route: ImportRoute.promotionalImage,
        pages: const [],
        products: [product],
        cloudUsage: const CloudProcessingUsage(requestCount: 1),
      ),
    );

    expect(result.candidates.single.promotionalPrice, isNull);
    expect(result.candidates.single.promotionConditions, ['4組159元']);
    expect(result.candidates.single.attentionFields, contains('優惠價需要確認'));
  });

  test(
    'cloud provider accepts structured evidence and never retries',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        final requestJson = jsonDecode(request.body) as Map<String, Object?>;
        expect(requestJson['schema_version'], 'clover.import.v1');
        expect(requestJson['page_number'], 2);
        return http.Response(
          jsonEncode({
            'products': [
              {
                'region_id': 'p2-card1',
                'region_evidence': {
                  'text': 'TP-LINK DECO X55 11999',
                  'confidence': 0.98,
                  'bounds': {
                    'left': 0.1,
                    'top': 0.1,
                    'right': 0.45,
                    'bottom': 0.45,
                  },
                },
                'merchant': {
                  'value': 'Costco 好市多',
                  'evidence': {'text': 'Costco 好市多', 'confidence': 0.99},
                },
                'product_name': {
                  'value': 'DECO X55 雙頻路由器',
                  'evidence': {'text': 'DECO X55 雙頻路由器', 'confidence': 0.96},
                },
                'brand': {
                  'value': 'TP-LINK',
                  'evidence': {'text': 'TP-LINK', 'confidence': 0.97},
                },
                'promo_price': {
                  'value': 11999,
                  'evidence': {'text': '賣場售價 11,999', 'confidence': 0.96},
                },
                'valid_until': {
                  'value': '2026-08-31',
                  'evidence': {'text': '優惠期間至 2026/08/31', 'confidence': 0.94},
                },
              },
            ],
            'usage': {'estimated_cost_usd': 0.006},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final provider = HttpCloudVisionProvider(
        endpoint: 'https://vision.example.test/analyze',
        providerName: 'test-provider',
        privacyDisclosure: '測試資料不保留且不作模型訓練。',
        client: client,
      );
      final asset = VisionAsset(
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
        sourceType: ImportSourceType.pdf,
        requestKey: 'same-page-once',
        retailerHint: 'costco',
        pageNumber: 2,
      );

      final result = await provider.analyze(asset);

      expect(result.products, hasLength(1));
      expect(result.products.single.productName.value, contains('DECO X55'));
      expect(result.usage.requestCount, 1);
      expect(result.usage.estimatedCostUsd, 0.006);
      await expectLater(
        provider.analyze(asset),
        throwsA(
          isA<CloudVisionUnavailableException>().having(
            (error) => error.code,
            'code',
            'duplicate_request_blocked',
          ),
        ),
      );
      expect(calls, 1);
    },
  );

  test('provider cannot activate without an explicit privacy disclosure', () {
    final provider = HttpCloudVisionProvider(
      endpoint: 'https://vision.example.test/analyze',
      providerName: 'test-provider',
      privacyDisclosure: '',
      client: MockClient((request) async => http.Response('{}', 200)),
    );

    expect(provider.isConfigured, isFalse);
  });

  test(
    'cloud value without matching visible evidence remains unknown',
    () async {
      final provider = HttpCloudVisionProvider(
        endpoint: 'https://vision.example.test/analyze',
        providerName: 'test-provider',
        privacyDisclosure: '測試資料不保留且不作模型訓練。',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'products': [
                {
                  'region_id': 'card-1',
                  'region_evidence': {
                    'text': '測試牛乳 賣場售價 119',
                    'confidence': 0.98,
                  },
                  'product_name': {
                    'value': '測試牛乳',
                    'evidence': {'text': '測試牛乳', 'confidence': 0.98},
                  },
                  'promo_price': {
                    'value': 999,
                    'evidence': {'text': '賣場售價 119', 'confidence': 0.98},
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      final result = await provider.analyze(
        VisionAsset(
          bytes: Uint8List.fromList([1]),
          mimeType: 'image/png',
          sourceType: ImportSourceType.image,
          requestKey: 'unsupported-value',
          retailerHint: 'generic',
        ),
      );

      expect(result.products.single.promotionalPrice, isNull);
    },
  );
}
