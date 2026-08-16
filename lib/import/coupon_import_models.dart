import '../models/offer.dart';

enum ImportSourceType { image, pdf }

enum ImportExtractionMethod {
  localOcr,
  nativePdfText,
  cloudVision,
  canonicalFixture,
}

enum ImportRoute { nativeTextPdf, scannedPdf, promotionalImage }

enum ImportConfidence { high, medium, low }

enum CandidateState { ready, needsReview, rejected }

enum SemanticBlockType {
  product,
  productName,
  brand,
  specification,
  itemNumber,
  originalPrice,
  promoPrice,
  discount,
  promotion,
  date,
  merchant,
  header,
  footer,
  disclaimer,
  legal,
  paymentCampaign,
  pageDecoration,
  unknown,
}

class OcrTextLine {
  const OcrTextLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  bool overlaps(OcrRegionBounds bounds) =>
      centerX >= bounds.left &&
      centerX < bounds.right &&
      centerY >= bounds.top &&
      centerY < bounds.bottom;
}

class OcrRegionBounds {
  const OcrRegionBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

class ClassifiedOcrLine {
  const ClassifiedOcrLine({
    required this.line,
    required this.type,
    required this.readingOrder,
  });

  final OcrTextLine line;
  final SemanticBlockType type;
  final int readingOrder;
}

class OcrPageResult {
  const OcrPageResult({
    required this.sourceType,
    required this.pageNumber,
    required this.text,
    required this.lines,
    required this.succeeded,
    required this.duration,
    this.failureCode,
    this.positionedLines = const [],
    this.extractionMethod = ImportExtractionMethod.localOcr,
    this.structuredRepresentation = '',
  });

  final ImportSourceType sourceType;
  final int? pageNumber;
  final String text;
  final List<String> lines;
  final bool succeeded;
  final Duration duration;
  final String? failureCode;
  final List<OcrTextLine> positionedLines;
  final ImportExtractionMethod extractionMethod;
  final String structuredRepresentation;
}

class FieldEvidence {
  const FieldEvidence({
    required this.sourceType,
    required this.extractionMethod,
    required this.sourcePage,
    required this.regionId,
    required this.rawText,
    required this.confidence,
    this.bounds,
  });

  final ImportSourceType sourceType;
  final ImportExtractionMethod extractionMethod;
  final int? sourcePage;
  final String regionId;
  final String rawText;
  final double confidence;
  final OcrRegionBounds? bounds;

  bool get isUsable =>
      rawText.trim().isNotEmpty &&
      regionId.trim().isNotEmpty &&
      confidence >= 0 &&
      confidence <= 1;
}

class EvidencedValue<T> {
  const EvidencedValue({required this.value, required this.evidence});

  final T value;
  final FieldEvidence evidence;
}

class ReconstructedProduct {
  const ReconstructedProduct({
    required this.regionId,
    required this.sourceType,
    required this.sourcePage,
    required this.productName,
    this.merchant,
    this.brand,
    this.model,
    this.specification,
    this.itemNumber,
    this.validFrom,
    this.validUntil,
    this.originalPrice,
    this.promotionalPrice,
    this.discountAmount,
    this.promotionCondition,
    this.category,
    this.notes,
    this.regionEvidence,
    this.uncertainFields = const [],
  });

  final String regionId;
  final ImportSourceType sourceType;
  final int? sourcePage;
  final EvidencedValue<String>? merchant;
  final EvidencedValue<String>? brand;
  final EvidencedValue<String> productName;
  final EvidencedValue<String>? model;
  final EvidencedValue<String>? specification;
  final EvidencedValue<String>? itemNumber;
  final EvidencedValue<DateTime>? validFrom;
  final EvidencedValue<DateTime>? validUntil;
  final EvidencedValue<num>? originalPrice;
  final EvidencedValue<num>? promotionalPrice;
  final EvidencedValue<num>? discountAmount;
  final EvidencedValue<String>? promotionCondition;
  final EvidencedValue<String>? category;
  final EvidencedValue<String>? notes;
  final FieldEvidence? regionEvidence;
  final List<String> uncertainFields;

  Iterable<FieldEvidence> get allEvidence sync* {
    if (regionEvidence != null) yield regionEvidence!;
    for (final value in <EvidencedValue<Object>?>[
      merchant,
      brand,
      productName,
      model,
      specification,
      itemNumber,
      validFrom,
      validUntil,
      originalPrice,
      promotionalPrice,
      discountAmount,
      promotionCondition,
      category,
      notes,
    ]) {
      if (value != null) yield value.evidence;
    }
  }
}

class CloudProcessingUsage {
  const CloudProcessingUsage({
    this.provider = '',
    this.requestCount = 0,
    this.transmittedBytes = 0,
    this.estimatedCostUsd = 0,
    this.failureCount = 0,
    this.inputTokenCount = 0,
    this.outputTokenCount = 0,
    this.totalTokenCount = 0,
  });

  final String provider;
  final int requestCount;
  final int transmittedBytes;
  final double estimatedCostUsd;
  final int failureCount;
  final int inputTokenCount;
  final int outputTokenCount;
  final int totalTokenCount;

  CloudProcessingUsage operator +(CloudProcessingUsage other) =>
      CloudProcessingUsage(
        provider: provider.isNotEmpty ? provider : other.provider,
        requestCount: requestCount + other.requestCount,
        transmittedBytes: transmittedBytes + other.transmittedBytes,
        estimatedCostUsd: estimatedCostUsd + other.estimatedCostUsd,
        failureCount: failureCount + other.failureCount,
        inputTokenCount: inputTokenCount + other.inputTokenCount,
        outputTokenCount: outputTokenCount + other.outputTokenCount,
        totalTokenCount: totalTokenCount + other.totalTokenCount,
      );
}

class SourceAdaptiveImportResult {
  const SourceAdaptiveImportResult({
    required this.route,
    required this.pages,
    required this.products,
    this.cloudUsage = const CloudProcessingUsage(),
    this.cloudWasDeclined = false,
    this.localFallbackUsed = false,
  });

  final ImportRoute route;
  final List<OcrPageResult> pages;
  final List<ReconstructedProduct> products;
  final CloudProcessingUsage cloudUsage;
  final bool cloudWasDeclined;
  final bool localFallbackUsed;
}

class PdfSourcePlan {
  const PdfSourcePlan({
    required this.pageCount,
    required this.nativeTextPages,
    required this.visionPages,
  });

  final int pageCount;
  final List<int> nativeTextPages;
  final List<int> visionPages;

  bool get requiresVision => visionPages.isNotEmpty;
}

class DateInference {
  const DateInference({
    required this.selected,
    this.start,
    this.alternatives = const [],
    this.isAmbiguous = false,
    this.yearMissing = false,
  });

  final DateTime? selected;
  final DateTime? start;
  final List<DateTime> alternatives;
  final bool isAmbiguous;
  final bool yearMissing;
}

class CouponCandidate {
  const CouponCandidate({
    required this.id,
    required this.title,
    required this.merchant,
    required this.rawText,
    required this.sourcePage,
    required this.category,
    required this.confidence,
    required this.attentionFields,
    this.state = CandidateState.ready,
    this.brand = '',
    this.model = '',
    this.specification = '',
    this.itemNumber = '',
    this.originalPrice,
    this.promotionalPrice,
    this.savings,
    this.promotionConditions = const [],
    this.startDate,
    this.expirationDate,
    this.offerDescription = '',
    this.valueText = '',
    this.alternativeDates = const [],
    bool? selected,
    this.isBatchDuplicate = false,
    this.isExistingDuplicate = false,
    this.sourceRegionId = '',
    this.fieldEvidence = const {},
  }) : selected = selected ?? state == CandidateState.ready;

  final String id;
  final String title;
  final String merchant;
  final String brand;
  final String model;
  final String specification;
  final String itemNumber;
  final DateTime? startDate;
  final DateTime? expirationDate;
  final String offerDescription;
  final String valueText;
  final num? originalPrice;
  final num? promotionalPrice;
  final num? savings;
  final List<String> promotionConditions;
  final OfferCategory category;
  final int? sourcePage;
  final ImportConfidence confidence;
  final CandidateState state;
  final List<String> attentionFields;
  final List<DateTime> alternativeDates;
  final String rawText;
  final bool selected;
  final bool isBatchDuplicate;
  final bool isExistingDuplicate;
  final String sourceRegionId;
  final Map<String, FieldEvidence> fieldEvidence;

  String get productName => title;
  DateTime? get validFrom => startDate;
  DateTime? get validUntil => expirationDate;
  num? get promoPrice => promotionalPrice;
  num? get discountAmount => savings;
  List<String> get promotionCondition => promotionConditions;
  String get notes => offerDescription;
  List<String> get validationIssues => attentionFields;

  bool get needsReview => state == CandidateState.needsReview;
  bool get isRejected => state == CandidateState.rejected;
  bool get hasValidPriceRelationship {
    if (originalPrice != null && originalPrice! <= 0) return false;
    if (promotionalPrice != null && promotionalPrice! <= 0) return false;
    if (originalPrice != null &&
        promotionalPrice != null &&
        promotionalPrice! > originalPrice!) {
      return false;
    }
    if (savings != null) {
      if (originalPrice == null || promotionalPrice == null) return false;
      if (savings != originalPrice! - promotionalPrice!) return false;
    }
    return true;
  }

  bool get hasPromotionValue =>
      promotionalPrice != null || promotionConditions.isNotEmpty;

  bool get passesFinalValidation =>
      state != CandidateState.rejected &&
      title.trim().isNotEmpty &&
      merchant.trim().isNotEmpty &&
      expirationDate != null &&
      hasPromotionValue &&
      hasValidPriceRelationship &&
      attentionFields.isEmpty;

  CouponCandidate copyWith({
    String? title,
    String? merchant,
    String? brand,
    String? model,
    String? specification,
    String? itemNumber,
    DateTime? startDate,
    DateTime? expirationDate,
    String? offerDescription,
    String? valueText,
    num? originalPrice,
    num? promotionalPrice,
    num? savings,
    List<String>? promotionConditions,
    OfferCategory? category,
    ImportConfidence? confidence,
    CandidateState? state,
    List<String>? attentionFields,
    List<DateTime>? alternativeDates,
    bool? selected,
    bool? isBatchDuplicate,
    bool? isExistingDuplicate,
    String? sourceRegionId,
    Map<String, FieldEvidence>? fieldEvidence,
    String? rawText,
    bool clearOriginalPrice = false,
    bool clearPromotionalPrice = false,
    bool clearSavings = false,
  }) {
    return CouponCandidate(
      id: id,
      title: title ?? this.title,
      merchant: merchant ?? this.merchant,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      specification: specification ?? this.specification,
      itemNumber: itemNumber ?? this.itemNumber,
      startDate: startDate ?? this.startDate,
      expirationDate: expirationDate ?? this.expirationDate,
      offerDescription: offerDescription ?? this.offerDescription,
      valueText: valueText ?? this.valueText,
      originalPrice: clearOriginalPrice
          ? null
          : originalPrice ?? this.originalPrice,
      promotionalPrice: clearPromotionalPrice
          ? null
          : promotionalPrice ?? this.promotionalPrice,
      savings: clearSavings ? null : savings ?? this.savings,
      promotionConditions: promotionConditions ?? this.promotionConditions,
      category: category ?? this.category,
      sourcePage: sourcePage,
      confidence: confidence ?? this.confidence,
      state: state ?? this.state,
      attentionFields: attentionFields ?? this.attentionFields,
      alternativeDates: alternativeDates ?? this.alternativeDates,
      rawText: rawText ?? this.rawText,
      selected: selected ?? this.selected,
      isBatchDuplicate: isBatchDuplicate ?? this.isBatchDuplicate,
      isExistingDuplicate: isExistingDuplicate ?? this.isExistingDuplicate,
      sourceRegionId: sourceRegionId ?? this.sourceRegionId,
      fieldEvidence: fieldEvidence ?? this.fieldEvidence,
    );
  }
}

class ImportQualityReport {
  const ImportQualityReport({
    required this.rawDetectedRegions,
    required this.readyCount,
    required this.needsReviewCount,
    required this.rejectedCount,
    required this.mergedFragmentCount,
    required this.finalVisibleCandidateCount,
    required this.missingTitleCount,
    required this.missingDateCount,
    required this.ambiguousPriceCount,
    required this.processingDuration,
    this.actualProductCount,
    this.falseCandidateCount,
    this.missedProductCount,
    this.duplicateCandidateCount = 0,
    this.crossCellContaminationCount = 0,
    this.cloudUsage = const CloudProcessingUsage(),
  });

  final int rawDetectedRegions;
  final int readyCount;
  final int needsReviewCount;
  final int rejectedCount;
  final int mergedFragmentCount;
  final int finalVisibleCandidateCount;
  final int missingTitleCount;
  final int missingDateCount;
  final int ambiguousPriceCount;
  final Duration processingDuration;
  final int? actualProductCount;
  final int? falseCandidateCount;
  final int? missedProductCount;
  final int duplicateCandidateCount;
  final int crossCellContaminationCount;
  final CloudProcessingUsage cloudUsage;

  int get generatedCandidateCount => finalVisibleCandidateCount;
  double get reviewBurden =>
      actualProductCount == null || actualProductCount == 0
      ? finalVisibleCandidateCount.toDouble()
      : finalVisibleCandidateCount / actualProductCount!;

  Map<String, Object?> toJson() => {
    'raw_detected_regions': rawDetectedRegions,
    'generated_candidate_count': generatedCandidateCount,
    'direct_import_count': readyCount,
    'needs_confirmation_count': needsReviewCount,
    'excluded_count': rejectedCount,
    'false_candidate_count': falseCandidateCount,
    'missed_product_count': missedProductCount,
    'duplicate_candidate_count': duplicateCandidateCount,
    'cross_product_contamination_count': crossCellContaminationCount,
    'review_burden': reviewBurden,
    'processing_milliseconds': processingDuration.inMilliseconds,
    'cloud_requests_used': cloudUsage.requestCount,
    'cloud_transmitted_bytes': cloudUsage.transmittedBytes,
    'cloud_estimated_cost_usd': cloudUsage.estimatedCostUsd,
    'cloud_failure_count': cloudUsage.failureCount,
    'cloud_input_tokens': cloudUsage.inputTokenCount,
    'cloud_output_tokens': cloudUsage.outputTokenCount,
    'cloud_total_tokens': cloudUsage.totalTokenCount,
  };
}

class CouponParseResult {
  const CouponParseResult({
    required this.candidates,
    required this.report,
    this.excludedCandidates = const [],
  });

  final List<CouponCandidate> candidates;
  final List<CouponCandidate> excludedCandidates;
  final ImportQualityReport report;
}

class LabeledImportQualityMetrics {
  const LabeledImportQualityMetrics({
    required this.actualProductCount,
    required this.generatedCandidateCount,
    required this.matchedProductCount,
    required this.falseCandidateCount,
    required this.missedProductCount,
    required this.directImportCount,
    required this.needsConfirmationCount,
    required this.excludedCount,
    required this.duplicateCandidateCount,
    required this.crossCellContaminationCount,
    required this.correctRequiredFieldCount,
    required this.evaluatedRequiredFieldCount,
  });

  final int actualProductCount;
  final int generatedCandidateCount;
  final int matchedProductCount;
  final int falseCandidateCount;
  final int missedProductCount;
  final int directImportCount;
  final int needsConfirmationCount;
  final int excludedCount;
  final int duplicateCandidateCount;
  final int crossCellContaminationCount;
  final int correctRequiredFieldCount;
  final int evaluatedRequiredFieldCount;

  double get candidatePrecision => generatedCandidateCount == 0
      ? (actualProductCount == 0 ? 1 : 0)
      : matchedProductCount / generatedCandidateCount;
  double get candidateRecall =>
      actualProductCount == 0 ? 1 : matchedProductCount / actualProductCount;
  double get fieldAccuracy => evaluatedRequiredFieldCount == 0
      ? 1
      : correctRequiredFieldCount / evaluatedRequiredFieldCount;
  double get duplicateRate => actualProductCount == 0
      ? 0
      : duplicateCandidateCount / actualProductCount;
  double get reviewBurden => actualProductCount == 0
      ? generatedCandidateCount.toDouble()
      : generatedCandidateCount / actualProductCount;

  Map<String, Object> toJson() => {
    'actual_product_count': actualProductCount,
    'generated_candidate_count': generatedCandidateCount,
    'correct_product_count': matchedProductCount,
    'product_recall': candidateRecall,
    'candidate_precision': candidatePrecision,
    'field_accuracy': fieldAccuracy,
    'false_candidate_count': falseCandidateCount,
    'missed_product_count': missedProductCount,
    'duplicate_rate': duplicateRate,
    'cross_product_contamination_count': crossCellContaminationCount,
    'review_burden': reviewBurden,
    'direct_import_count': directImportCount,
    'needs_confirmation_count': needsConfirmationCount,
    'excluded_count': excludedCount,
  };
}

class ImportProgress {
  const ImportProgress({required this.completed, required this.total});

  final int completed;
  final int total;
}

class ImportCancelledException implements Exception {
  const ImportCancelledException();
}

class ImportLimitException implements Exception {
  const ImportLimitException(this.message);

  final String message;
}
