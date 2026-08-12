import '../models/offer.dart';

enum ImportSourceType { image, pdf }

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
  });

  final ImportSourceType sourceType;
  final int? pageNumber;
  final String text;
  final List<String> lines;
  final bool succeeded;
  final Duration duration;
  final String? failureCode;
  final List<OcrTextLine> positionedLines;
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
  final int? originalPrice;
  final int? promotionalPrice;
  final int? savings;
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

  String get productName => title;
  DateTime? get validFrom => startDate;
  DateTime? get validUntil => expirationDate;
  int? get promoPrice => promotionalPrice;
  int? get discountAmount => savings;
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
    int? originalPrice,
    int? promotionalPrice,
    int? savings,
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

  int get generatedCandidateCount => finalVisibleCandidateCount;
  double get reviewBurden =>
      actualProductCount == null || actualProductCount == 0
      ? finalVisibleCandidateCount.toDouble()
      : finalVisibleCandidateCount / actualProductCount!;
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
