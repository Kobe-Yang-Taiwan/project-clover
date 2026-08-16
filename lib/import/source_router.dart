import 'coupon_import_models.dart';

class ImportSourceDecision {
  const ImportSourceDecision({
    required this.route,
    required this.reason,
    required this.cloudEligiblePageNumbers,
  });

  final ImportRoute route;
  final String reason;
  final List<int> cloudEligiblePageNumbers;
}

class ImportSourceRouter {
  const ImportSourceRouter();

  ImportSourceDecision forImage() => const ImportSourceDecision(
    route: ImportRoute.promotionalImage,
    reason: 'image_requires_product_region_understanding',
    cloudEligiblePageNumbers: [],
  );

  ImportSourceDecision forPdf(PdfSourcePlan plan) {
    if (!plan.requiresVision) {
      return const ImportSourceDecision(
        route: ImportRoute.nativeTextPdf,
        reason: 'reliable_native_text_layer',
        cloudEligiblePageNumbers: [],
      );
    }
    return ImportSourceDecision(
      route: ImportRoute.scannedPdf,
      reason: plan.nativeTextPages.isEmpty
          ? 'image_only_pdf'
          : 'mixed_pdf_with_unreliable_text_pages',
      cloudEligiblePageNumbers: List.unmodifiable(plan.visionPages),
    );
  }
}
