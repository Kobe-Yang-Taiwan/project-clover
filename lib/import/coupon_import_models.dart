import '../models/offer.dart';

enum ImportSourceType { image, pdf }

enum ImportConfidence { high, medium, low }

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
    this.startDate,
    this.expirationDate,
    this.offerDescription = '',
    this.valueText = '',
    this.alternativeDates = const [],
    this.selected = true,
    this.isBatchDuplicate = false,
    this.isExistingDuplicate = false,
  });

  final String id;
  final String title;
  final String merchant;
  final DateTime? startDate;
  final DateTime? expirationDate;
  final String offerDescription;
  final String valueText;
  final OfferCategory category;
  final int? sourcePage;
  final ImportConfidence confidence;
  final List<String> attentionFields;
  final List<DateTime> alternativeDates;
  final String rawText;
  final bool selected;
  final bool isBatchDuplicate;
  final bool isExistingDuplicate;

  bool get needsReview => attentionFields.isNotEmpty;

  CouponCandidate copyWith({
    String? title,
    String? merchant,
    DateTime? startDate,
    DateTime? expirationDate,
    String? offerDescription,
    String? valueText,
    OfferCategory? category,
    ImportConfidence? confidence,
    List<String>? attentionFields,
    List<DateTime>? alternativeDates,
    bool? selected,
    bool? isBatchDuplicate,
    bool? isExistingDuplicate,
  }) {
    return CouponCandidate(
      id: id,
      title: title ?? this.title,
      merchant: merchant ?? this.merchant,
      startDate: startDate ?? this.startDate,
      expirationDate: expirationDate ?? this.expirationDate,
      offerDescription: offerDescription ?? this.offerDescription,
      valueText: valueText ?? this.valueText,
      category: category ?? this.category,
      sourcePage: sourcePage,
      confidence: confidence ?? this.confidence,
      attentionFields: attentionFields ?? this.attentionFields,
      alternativeDates: alternativeDates ?? this.alternativeDates,
      rawText: rawText,
      selected: selected ?? this.selected,
      isBatchDuplicate: isBatchDuplicate ?? this.isBatchDuplicate,
      isExistingDuplicate: isExistingDuplicate ?? this.isExistingDuplicate,
    );
  }
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
