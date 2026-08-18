import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/import/coupon_import_models.dart';

void main() {
  Map<String, Object?> manifest(String name) =>
      jsonDecode(File('test/golden_dataset/$name').readAsStringSync())
          as Map<String, Object?>;

  void expectMetricTemplate(Map<String, Object?> value) {
    final metrics = value['acceptance_measurement']! as Map<String, Object?>;
    expect(
      metrics.keys.toSet(),
      containsAll(<String>{
        'detected_product_count',
        'correct_product_count',
        'product_recall',
        'candidate_precision',
        'field_accuracy',
        'false_candidate_count',
        'duplicate_rate',
        'cross_product_contamination',
        'review_burden',
        'cloud_requests_used',
        'cloud_input_tokens',
        'cloud_output_tokens',
        'cloud_total_tokens',
        'estimated_processing_cost_usd',
        'proposed_product_region_count',
        'fabricated_field_count',
        'no_typing_import_rate',
        'recovery_action_count',
        'manual_text_entry_count',
        'median_processing_milliseconds',
        'p95_processing_milliseconds',
      }),
    );
    expect(metrics['status'], startsWith('pending'));
  }

  test('Costco real-world manifest preserves all product-cell counts', () {
    final value = manifest('costco_2026_spring.json');
    final pageCounts = (value['product_count_by_page']! as List<Object?>)
        .cast<int>();

    expect(value['asset_sha256'].toString(), hasLength(64));
    expect(pageCounts, [0, 16, 16, 16, 20, 13, 16, 16, 16]);
    expect(pageCounts.fold<int>(0, (sum, count) => sum + count), 129);
    expect(value['maximum_cloud_requests'], 0);
    expect(value['expected_valid_until'], '2026-05-10');
    expectMetricTemplate(value);
  });

  test('PX Mart manifest labels 12 products and non-product UI', () {
    final value = manifest('pxmart_2026_08.json');
    final products = value['products']! as List<Object?>;
    final excluded = value['non_product_regions']! as List<Object?>;

    expect(products, hasLength(12));
    expect(
      products
          .cast<Map<String, Object?>>()
          .map((product) => product['region'])
          .toSet(),
      hasLength(12),
    );
    expect(excluded.join(' '), contains('mobile status bar'));
    expect(excluded.join(' '), contains('payment campaign'));
    expect(value['maximum_cloud_requests'], 0);
    expect(value['expected_valid_until'], '2026-08-13');
    expectMetricTemplate(value);
  });

  test('FamilyMart failure baseline records the observed P0 recall gap', () {
    final value = manifest('familymart_founder_failure.json');
    final known = value['known_v016_result']! as Map<String, Object?>;
    const baseline = LabeledImportQualityMetrics(
      actualProductCount: 8,
      generatedCandidateCount: 1,
      matchedProductCount: 1,
      falseCandidateCount: 0,
      missedProductCount: 7,
      directImportCount: 0,
      needsConfirmationCount: 1,
      excludedCount: 0,
      duplicateCandidateCount: 0,
      crossCellContaminationCount: 0,
      correctRequiredFieldCount: 0,
      evaluatedRequiredFieldCount: 0,
    );

    expect(value['ground_truth_product_count'], 8);
    expect(value['visible_region_prices'], hasLength(8));
    expect(known['detected_product_count'], 1);
    expect(baseline.candidateRecall, 0.125);
    expect(value['release_gate'], contains('founder_android'));
    expect(value['expected_validity'], isNull);
    expectMetricTemplate(value);
  });
}
