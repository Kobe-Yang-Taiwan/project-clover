import '../models/offer.dart';
import 'coupon_import_models.dart';
import 'document_understanding.dart';

class CouponParser {
  const CouponParser({
    DateTime Function()? now,
    DocumentUnderstandingPipeline understanding =
        const DocumentUnderstandingPipeline(),
  }) : _now = now,
       _understanding = understanding;

  final DateTime Function()? _now;
  final DocumentUnderstandingPipeline _understanding;

  CouponCandidate parse(
    OcrPageResult page, {
    String? id,
    String documentMerchant = '',
  }) {
    final understood = _understanding.understand(page);
    final region = understood.regions.isEmpty
        ? ProductRegion(
            id: 'p${page.pageNumber ?? 0}-empty',
            bounds: const OcrRegionBounds(left: 0, top: 0, right: 1, bottom: 1),
            blocks: const [],
          )
        : understood.regions.first;
    return _reconstruct(
      page: page,
      region: region,
      sharedBlocks: understood.sharedBlocks,
      id: id ?? region.id,
      documentMerchant: documentMerchant,
    ).copyWith(rawText: page.text);
  }

  CouponCandidate _reconstruct({
    required OcrPageResult page,
    required ProductRegion region,
    required List<ClassifiedOcrLine> sharedBlocks,
    required String id,
    required String documentMerchant,
  }) {
    final localLines = region.lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final identityLines = region.blocks
        .where((block) => block.type == SemanticBlockType.productName)
        .map((block) => _withoutTrailingPrice(block.line.text.trim()))
        .where(_isPlausibleTitle)
        .toList();
    final title = _extractTitle(identityLines);
    final sharedText = sharedBlocks
        .map((block) => block.line.text.trim())
        .join('\n');
    final localDateText = region.blocks
        .where(
          (block) =>
              block.type == SemanticBlockType.date &&
              RegExp(
                r'優惠期間|活動期間|有效期間|有效期限|使用期限|兌換期限|截止|至\s*\d',
              ).hasMatch(block.line.text),
        )
        .map((block) => block.line.text)
        .join('\n');
    final localDates = parseDates(localDateText);
    final inheritedDates = localDates.selected == null
        ? _sharedDateInference(sharedText)
        : const DateInference(selected: null);
    final dates = localDates.selected != null ? localDates : inheritedDates;
    final merchant = _extractMerchant([
      ...sharedBlocks.map((block) => block.line.text.trim()),
      ...localLines,
    ], documentMerchant);
    final brand = _extractBrand(localLines);
    var prices = _extractPrices(localLines);
    if (page.extractionMethod == ImportExtractionMethod.nativePdfText) {
      prices = _extractNativeSpatialPrices(region, prices);
    }
    final conditions = _extractConditions(localLines);
    final itemNumber = _extractItemNumber(localLines);
    final model = _extractModel(title);
    final specification = _extractSpecification(localLines, title);

    final productEvidence = _productEvidence(
      title: title,
      itemNumber: itemNumber,
      model: model,
      prices: prices,
      lines: localLines,
    );
    final hasPromotionValue =
        prices.promotional != null ||
        prices.savings != null ||
        conditions.isNotEmpty;
    final hasCommercialEvidence =
        hasPromotionValue || prices.ambiguous || prices.conflicting;
    final rejected =
        title.isEmpty ||
        productEvidence < 3 ||
        (!hasCommercialEvidence && itemNumber.isEmpty) ||
        _isNonProductOnly(localLines);
    final attention = <String>[
      if (title.isEmpty) '商品名稱不完整',
      if (title.isNotEmpty && _isIncompleteTitle(title)) '商品名稱不完整',
      if (merchant.isEmpty) '缺少商家／來源',
      if (dates.selected == null) '缺少到期日',
      if (dates.isAmbiguous || dates.yearMissing) '到期日需要確認',
      if (!hasPromotionValue) '缺少優惠價／優惠內容',
      if (prices.inferredStandalone) '優惠價需要確認',
      if (prices.ambiguous) '優惠價需要確認',
      if (prices.conflicting) '價格互相衝突',
    ];
    final state = rejected
        ? CandidateState.rejected
        : attention.isEmpty
        ? CandidateState.ready
        : CandidateState.needsReview;
    final confidence = state == CandidateState.ready
        ? ImportConfidence.high
        : state == CandidateState.rejected || attention.length > 2
        ? ImportConfidence.low
        : ImportConfidence.medium;

    return CouponCandidate(
      id: id,
      title: title,
      merchant: merchant,
      brand: brand,
      model: model,
      specification: specification,
      itemNumber: itemNumber,
      startDate: dates.start,
      expirationDate: dates.selected,
      originalPrice: prices.original,
      promotionalPrice: prices.promotional,
      savings: prices.savings,
      promotionConditions: conditions,
      offerDescription: _extractDescription(localLines, title),
      valueText: _formatValue(prices, conditions),
      category: suggestCategory(
        '$title $specification ${localLines.join(' ')}',
      ),
      sourcePage: page.pageNumber,
      confidence: confidence,
      state: state,
      attentionFields: attention.toSet().toList(),
      alternativeDates: dates.alternatives,
      rawText: localLines.join('\n'),
      sourceRegionId: region.id,
      fieldEvidence: _localFieldEvidence(
        page: page,
        region: region,
        sharedBlocks: sharedBlocks,
        title: title,
        merchant: merchant,
        brand: brand,
        model: model,
        specification: specification,
        itemNumber: itemNumber,
        startDate: dates.start,
        expirationDate: dates.selected,
        originalPrice: prices.original,
        promotionalPrice: prices.promotional,
        savings: prices.savings,
      ),
    );
  }

  List<CouponCandidate> parsePages(List<OcrPageResult> pages) =>
      parsePagesDetailed(pages).candidates;

  CouponParseResult parseAdaptive(SourceAdaptiveImportResult source) {
    final cloudSucceeded =
        source.cloudUsage.requestCount > 0 && !source.localFallbackUsed;
    final localPages = source.pages
        .where(
          (page) =>
              page.extractionMethod != ImportExtractionMethod.cloudVision &&
              !(source.route == ImportRoute.promotionalImage && cloudSucceeded),
        )
        .toList();
    final local = parsePagesDetailed(
      localPages,
      documentMerchant: source.merchantHint,
    );
    final canonical = <CouponCandidate>[];
    final excluded = <CouponCandidate>[...local.excludedCandidates];
    var contaminationCount = 0;
    for (var index = 0; index < source.products.length; index++) {
      final reconstructed = _candidateFromCanonical(
        source.products[index],
        index,
      );
      contaminationCount += reconstructed.contaminationCount;
      if (reconstructed.candidate.isRejected) {
        excluded.add(reconstructed.candidate);
      } else {
        canonical.add(reconstructed.candidate);
      }
    }
    final candidates = <CouponCandidate>[...local.candidates, ...canonical]
      ..sort((a, b) {
        final state = _stateOrder(a.state).compareTo(_stateOrder(b.state));
        if (state != 0) return state;
        final page = (a.sourcePage ?? 0).compareTo(b.sourcePage ?? 0);
        return page != 0 ? page : a.sourceRegionId.compareTo(b.sourceRegionId);
      });
    return CouponParseResult(
      candidates: candidates,
      excludedCandidates: excluded,
      report: ImportQualityReport(
        rawDetectedRegions:
            local.report.rawDetectedRegions + source.products.length,
        readyCount: candidates
            .where((item) => item.state == CandidateState.ready)
            .length,
        needsReviewCount: candidates
            .where((item) => item.state == CandidateState.needsReview)
            .length,
        rejectedCount: excluded.length,
        mergedFragmentCount: local.report.mergedFragmentCount,
        finalVisibleCandidateCount: candidates.length,
        missingTitleCount: candidates
            .where((item) => item.title.isEmpty)
            .length,
        missingDateCount: candidates
            .where((item) => item.expirationDate == null)
            .length,
        ambiguousPriceCount: candidates
            .where(
              (item) => item.attentionFields.any(
                (reason) => reason.contains('價格') || reason.contains('優惠價'),
              ),
            )
            .length,
        processingDuration: local.report.processingDuration,
        duplicateCandidateCount: local.report.duplicateCandidateCount,
        crossCellContaminationCount:
            local.report.crossCellContaminationCount + contaminationCount,
        cloudUsage: source.cloudUsage,
        localImageMetrics: source.localImageMetrics,
      ),
    );
  }

  _CanonicalCandidate _candidateFromCanonical(
    ReconstructedProduct product,
    int index,
  ) {
    final productBounds = product.regionEvidence?.bounds;
    final productSpecificEvidence = <FieldEvidence?>[
      product.regionEvidence,
      product.productName.evidence,
      product.brand?.evidence,
      product.model?.evidence,
      product.specification?.evidence,
      product.itemNumber?.evidence,
      product.originalPrice?.evidence,
      product.promotionalPrice?.evidence,
      product.discountAmount?.evidence,
    ].whereType<FieldEvidence>();
    final sharedEligibleEvidence = <FieldEvidence?>[
      product.merchant?.evidence,
      product.validFrom?.evidence,
      product.validUntil?.evidence,
      product.promotionCondition?.evidence,
    ].whereType<FieldEvidence>();
    final ownershipViolation =
        productSpecificEvidence.any(
          (evidence) =>
              evidence.regionId != product.regionId ||
              (productBounds != null &&
                  evidence.bounds != null &&
                  !_boundsContain(productBounds, evidence.bounds!)),
        ) ||
        sharedEligibleEvidence.any(
          (evidence) =>
              evidence.sourcePage != product.sourcePage ||
              (evidence.regionId != product.regionId &&
                  !_isSharedEvidenceRegion(evidence.regionId)),
        );
    final baseName = product.productName.value.trim();
    final identityParts = <String>[
      if (_reliableText(product.brand)) product.brand!.value.trim(),
      baseName,
      if (_reliableText(product.model)) product.model!.value.trim(),
      if (_reliableText(product.specification))
        product.specification!.value.trim(),
    ];
    final title = _joinIdentity(identityParts);
    final merchant = product.merchant?.value.trim() ?? '';
    final original = _reliableInt(product.originalPrice);
    final promotional = _reliableInt(product.promotionalPrice);
    final explicitDiscount = _reliableInt(product.discountAmount);
    final derivedDiscount = original != null && promotional != null
        ? original - promotional
        : null;
    final discountConflict =
        explicitDiscount != null &&
        derivedDiscount != null &&
        explicitDiscount != derivedDiscount;
    final discount =
        discountConflict || (derivedDiscount != null && derivedDiscount <= 0)
        ? null
        : derivedDiscount ?? explicitDiscount;
    final condition = product.promotionCondition?.value.trim();
    final conditions = condition == null || condition.isEmpty
        ? const <String>[]
        : <String>[condition];
    final nonProduct = _isCanonicalNonProduct(title);
    final attention = <String>[
      if (title.isEmpty || _isIncompleteTitle(title)) '商品名稱不完整',
      if (product.productName.evidence.confidence < 0.75) '商品名稱需要確認',
      if (merchant.isEmpty) '缺少商家／來源',
      if (product.merchant != null &&
          product.merchant!.evidence.confidence < 0.75)
        '商家／來源需要確認',
      if (product.validUntil == null) '缺少到期日',
      if (product.validUntil != null &&
          product.validUntil!.evidence.confidence < 0.75)
        '到期日需要確認',
      if (promotional == null && conditions.isEmpty) '缺少優惠價／優惠內容',
      if (product.promotionalPrice != null && promotional == null) '優惠價需要確認',
      if (original != null && promotional != null && promotional > original)
        '價格互相衝突',
      if (discountConflict) '折扣與價格互相衝突',
      if (ownershipViolation) '跨商品欄位污染',
      ...product.uncertainFields.map((field) => '$field 需要確認'),
    ];
    final rejected =
        ownershipViolation || nonProduct || baseName.isEmpty || title.isEmpty;
    final state = rejected
        ? CandidateState.rejected
        : attention.isEmpty
        ? CandidateState.ready
        : CandidateState.needsReview;
    final evidenceText = product.allEvidence
        .map((evidence) => evidence.rawText.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .join('\n');
    return _CanonicalCandidate(
      contaminationCount: ownershipViolation ? 1 : 0,
      candidate: CouponCandidate(
        id: 'canonical-${product.sourcePage ?? 0}-$index',
        title: title,
        merchant: merchant,
        brand: product.brand?.value.trim() ?? '',
        model: product.model?.value.trim() ?? '',
        specification: product.specification?.value.trim() ?? '',
        itemNumber: product.itemNumber?.value.trim() ?? '',
        startDate: product.validFrom?.value,
        expirationDate: product.validUntil?.value,
        originalPrice: original,
        promotionalPrice: promotional,
        savings: discount,
        promotionConditions: conditions,
        offerDescription: product.notes?.value.trim() ?? '',
        valueText: _formatCanonicalValue(
          original: original,
          promotional: promotional,
          discount: discount,
          conditions: conditions,
        ),
        category: suggestCategory('$title ${product.category?.value ?? ''}'),
        sourcePage: product.sourcePage,
        confidence: state == CandidateState.ready
            ? ImportConfidence.high
            : state == CandidateState.rejected
            ? ImportConfidence.low
            : ImportConfidence.medium,
        state: state,
        attentionFields: attention.toSet().toList(),
        rawText: evidenceText,
        selected: state == CandidateState.ready,
        sourceRegionId: product.regionId,
        fieldEvidence: {
          'product_name': product.productName.evidence,
          if (product.merchant != null) 'merchant': product.merchant!.evidence,
          if (product.brand != null) 'brand': product.brand!.evidence,
          if (product.model != null) 'model': product.model!.evidence,
          if (product.specification != null)
            'specification': product.specification!.evidence,
          if (product.itemNumber != null)
            'item_number': product.itemNumber!.evidence,
          if (product.validFrom != null)
            'valid_from': product.validFrom!.evidence,
          if (product.validUntil != null)
            'valid_until': product.validUntil!.evidence,
          if (product.originalPrice != null)
            'original_price': product.originalPrice!.evidence,
          if (product.promotionalPrice != null)
            'promo_price': product.promotionalPrice!.evidence,
          if (product.discountAmount != null)
            'discount_amount': product.discountAmount!.evidence,
          if (product.promotionCondition != null)
            'promotion_condition': product.promotionCondition!.evidence,
        },
      ),
    );
  }

  Map<String, FieldEvidence> _localFieldEvidence({
    required OcrPageResult page,
    required ProductRegion region,
    required List<ClassifiedOcrLine> sharedBlocks,
    required String title,
    required String merchant,
    required String brand,
    required String model,
    required String specification,
    required String itemNumber,
    required DateTime? startDate,
    required DateTime? expirationDate,
    required num? originalPrice,
    required num? promotionalPrice,
    required num? savings,
  }) {
    final confidence =
        page.extractionMethod == ImportExtractionMethod.nativePdfText
        ? 0.95
        : 0.70;
    FieldEvidence local(String rawText) => FieldEvidence(
      sourceType: page.sourceType,
      extractionMethod: page.extractionMethod,
      sourcePage: page.pageNumber,
      regionId: region.id,
      rawText: rawText,
      confidence: confidence,
      bounds: region.bounds,
    );
    FieldEvidence shared(String rawText) => FieldEvidence(
      sourceType: page.sourceType,
      extractionMethod: page.extractionMethod,
      sourcePage: page.pageNumber,
      regionId: 'p${page.pageNumber ?? 0}-shared',
      rawText: rawText,
      confidence: confidence,
    );
    final sharedText = sharedBlocks
        .map((block) => block.line.text.trim())
        .where((value) => value.isNotEmpty)
        .join('\n');
    return {
      if (title.isNotEmpty) 'product_name': local(title),
      if (merchant.isNotEmpty) 'merchant': shared(merchant),
      if (brand.isNotEmpty) 'brand': local(brand),
      if (model.isNotEmpty) 'model': local(model),
      if (specification.isNotEmpty) 'specification': local(specification),
      if (itemNumber.isNotEmpty) 'item_number': local(itemNumber),
      if (startDate != null) 'valid_from': shared(sharedText),
      if (expirationDate != null) 'valid_until': shared(sharedText),
      if (originalPrice != null)
        'original_price': local(_rawLineForAmount(region, originalPrice)),
      if (promotionalPrice != null)
        'promo_price': local(_rawLineForAmount(region, promotionalPrice)),
      if (savings != null)
        'discount_amount': local(_rawLineForAmount(region, savings)),
    };
  }

  String _rawLineForAmount(ProductRegion region, num amount) {
    final digits = amount.toString().replaceAll(RegExp(r'\.0$'), '');
    for (final line in region.lines) {
      if (line.replaceAll(',', '').contains(digits)) return line;
    }
    return digits;
  }

  bool _reliableText(EvidencedValue<String>? value) =>
      value != null &&
      value.value.trim().isNotEmpty &&
      value.evidence.isUsable &&
      value.evidence.confidence >= 0.65;

  num? _reliableInt(EvidencedValue<num>? value) =>
      value != null &&
          value.value > 0 &&
          value.evidence.isUsable &&
          value.evidence.confidence >= 0.75 &&
          !RegExp(
            r'平均|單價|每(?:件|組|包|瓶|罐)|滿\s*[0-9,]+|回饋|紅利|點數',
          ).hasMatch(value.evidence.rawText)
      ? value.value
      : null;

  bool _boundsContain(OcrRegionBounds region, OcrRegionBounds field) {
    const tolerance = 0.005;
    return field.left >= region.left - tolerance &&
        field.top >= region.top - tolerance &&
        field.right <= region.right + tolerance &&
        field.bottom <= region.bottom + tolerance;
  }

  bool _isSharedEvidenceRegion(String regionId) => RegExp(
    r'(?:shared|page|campaign|banner)',
    caseSensitive: false,
  ).hasMatch(regionId);

  String _joinIdentity(List<String> values) {
    final result = <String>[];
    for (final value in values) {
      final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (clean.isEmpty) continue;
      final lower = clean.toLowerCase();
      final duplicate = result.indexWhere((existing) {
        final existingLower = existing.toLowerCase();
        return existingLower.contains(lower) || lower.contains(existingLower);
      });
      if (duplicate >= 0) {
        if (clean.length > result[duplicate].length) result[duplicate] = clean;
        continue;
      }
      result.add(clean);
    }
    return result.join(' ').trim();
  }

  bool _isCanonicalNonProduct(String value) => RegExp(
    r'^(?:【?賣場售價】?|僅限好市多|售價以官網為準|商品實際(?:包裝|顏色|尺寸).+|注意事項|活動辦法|信用卡.+|\d+(?:\.\d+)?\s*(?:g|kg|ml|l|包|瓶|罐|個|袋|盒|組|入).*)$',
    caseSensitive: false,
  ).hasMatch(value.trim());

  String _formatCanonicalValue({
    required num? original,
    required num? promotional,
    required num? discount,
    required List<String> conditions,
  }) {
    final values = <String>[
      if (original != null) '原價：$original 元',
      if (promotional != null) '優惠價：$promotional 元',
      if (discount != null) '共省：$discount 元',
      ...conditions,
    ];
    return values.join('｜');
  }

  CouponParseResult parsePagesDetailed(
    List<OcrPageResult> pages, {
    String documentMerchant = '',
  }) {
    final watch = Stopwatch()..start();
    final parsed = <CouponCandidate>[];
    final excluded = <CouponCandidate>[];
    final excludedSharedKeys = <String>{};
    var rawRegions = 0;
    for (final page in pages.where((page) => page.succeeded)) {
      final detectedMerchant = _detectDocumentMerchant(page.text);
      final merchant = detectedMerchant.isNotEmpty
          ? detectedMerchant
          : documentMerchant;
      final understood = _understanding.understand(page);
      for (final block in understood.sharedBlocks.where(
        (block) =>
            block.type != SemanticBlockType.merchant &&
            block.type != SemanticBlockType.date,
      )) {
        final sharedKey =
            '${page.pageNumber ?? 0}|${block.type.name}|'
            '${block.line.text.trim()}';
        if (!excludedSharedKeys.add(sharedKey)) continue;
        excluded.add(
          _excludedBlockCandidate(
            page: page,
            block: block,
            id: '${page.pageNumber ?? 0}-excluded-${block.readingOrder}',
          ),
        );
      }
      rawRegions += understood.regions.length;
      for (var index = 0; index < understood.regions.length; index++) {
        final region = understood.regions[index];
        final candidate = _reconstruct(
          page: page,
          region: region,
          sharedBlocks: understood.sharedBlocks,
          id: page.sourceRegionId ?? '${page.pageNumber ?? 0}-$index',
          documentMerchant: merchant,
        );
        if (candidate.isRejected) {
          excluded.add(candidate);
        } else {
          parsed.add(candidate);
        }
      }
    }
    final merged = _mergeFragments(parsed);
    final sorted = List<CouponCandidate>.from(merged.values)
      ..sort((a, b) {
        final state = _stateOrder(a.state).compareTo(_stateOrder(b.state));
        if (state != 0) return state;
        final page = (a.sourcePage ?? 0).compareTo(b.sourcePage ?? 0);
        return page != 0 ? page : a.id.compareTo(b.id);
      });
    watch.stop();
    return CouponParseResult(
      candidates: sorted,
      excludedCandidates: excluded,
      report: ImportQualityReport(
        rawDetectedRegions: rawRegions,
        readyCount: sorted
            .where((item) => item.state == CandidateState.ready)
            .length,
        needsReviewCount: sorted
            .where((item) => item.state == CandidateState.needsReview)
            .length,
        rejectedCount: excluded.length,
        mergedFragmentCount: merged.mergedCount,
        finalVisibleCandidateCount: sorted.length,
        missingTitleCount: sorted.where((item) => item.title.isEmpty).length,
        missingDateCount: sorted
            .where((item) => item.expirationDate == null)
            .length,
        ambiguousPriceCount: sorted
            .where(
              (item) => item.attentionFields.any(
                (reason) => reason.contains('價格') || reason.contains('優惠價'),
              ),
            )
            .length,
        processingDuration: pages.fold<Duration>(
          watch.elapsed,
          (total, page) => total + page.duration,
        ),
        duplicateCandidateCount: merged.mergedCount,
        crossCellContaminationCount: 0,
      ),
    );
  }

  CouponCandidate _excludedBlockCandidate({
    required OcrPageResult page,
    required ClassifiedOcrLine block,
    required String id,
  }) => CouponCandidate(
    id: id,
    title: '',
    merchant: '',
    rawText: block.line.text.trim(),
    sourcePage: page.pageNumber,
    category: OfferCategory.others,
    confidence: ImportConfidence.high,
    state: CandidateState.rejected,
    selected: false,
    attentionFields: const ['非商品內容'],
    sourceRegionId: 'p${page.pageNumber ?? 0}-shared',
  );

  DateInference _sharedDateInference(String text) {
    if (!RegExp(r'優惠期間|活動期間|有效期間|本期|本檔').hasMatch(text)) {
      return const DateInference(selected: null);
    }
    return parseDates(text);
  }

  DateInference parseDates(String text) {
    final contextual = <DateTime>[];
    final all = <DateTime>[];
    var yearMissing = false;
    final datePattern = RegExp(
      r'(?:(\d{2,4})\s*[年./-]\s*)?(\d{1,2})\s*[月./-]\s*(\d{1,2})\s*日?',
    );
    for (final match in datePattern.allMatches(text)) {
      final yearText = match.group(1);
      if (yearText == null) {
        yearMissing = true;
        continue;
      }
      var year = int.parse(yearText);
      if (year < 1911) year += 1911;
      final parsed = _validDate(
        year,
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
      );
      if (parsed == null) continue;
      all.add(parsed);
      final prefixStart = match.start > 14 ? match.start - 14 : 0;
      final prefix = text.substring(prefixStart, match.start);
      if (RegExp(r'有效期限|使用期限|活動期間|優惠期間|兌換期限|截止|至\s*$').hasMatch(prefix)) {
        contextual.add(parsed);
      }
    }
    final unique = <DateTime>[];
    for (final date in [...contextual, ...all]) {
      if (!unique.any((item) => _sameDate(item, date))) unique.add(date);
    }
    if (unique.isEmpty) {
      return DateInference(selected: null, yearMissing: yearMissing);
    }
    final range = RegExp(
      r'(\d{2,4})\s*[年./-]\s*(\d{1,2})\s*[月./-]\s*(\d{1,2})\s*日?\s*(?:至|到|[-–—~～])\s*(?:(\d{2,4})\s*[年./-]\s*)?(\d{1,2})\s*[月./-]\s*(\d{1,2})\s*日?',
    ).firstMatch(text);
    DateTime? start;
    DateTime? selected;
    if (range != null) {
      var startYear = int.parse(range.group(1)!);
      if (startYear < 1911) startYear += 1911;
      var endYear = range.group(4) == null
          ? startYear
          : int.parse(range.group(4)!);
      if (endYear < 1911) endYear += 1911;
      start = _validDate(
        startYear,
        int.parse(range.group(2)!),
        int.parse(range.group(3)!),
      );
      selected = _validDate(
        endYear,
        int.parse(range.group(5)!),
        int.parse(range.group(6)!),
      );
    }
    if (range == null &&
        RegExp(r'優惠期間|活動期間').hasMatch(text) &&
        unique.length >= 2) {
      final ordered = List<DateTime>.from(unique)..sort();
      start = ordered.first;
      selected = ordered.last;
    }
    selected ??= contextual.isNotEmpty ? contextual.last : unique.last;
    final alternatives = unique
        .where((date) => !_sameDate(date, selected!))
        .toList();
    return DateInference(
      selected: selected,
      start: start,
      alternatives: alternatives,
      isAmbiguous:
          alternatives.isNotEmpty && contextual.length != 1 && range == null,
      yearMissing: false,
    );
  }

  OfferCategory suggestCategory(String text) {
    final value = text.toLowerCase();
    if (_contains(value, ['冷凍', '冷藏', '鮮奶', '肉品', '蔬果', '海鮮'])) {
      return OfferCategory.freshAndChilled;
    }
    if (_contains(value, ['洗衣', '清潔劑', '洗碗', '漂白', '柔軟精'])) {
      return OfferCategory.cleaningAndLaundry;
    }
    if (_contains(value, ['保養', '面膜', '洗髮', '沐浴', '彩妝', '乳液'])) {
      return OfferCategory.beautyAndCare;
    }
    if (_contains(value, ['維生素', '保健', '益生菌', '魚油', '營養補充'])) {
      return OfferCategory.health;
    }
    if (_contains(value, ['除濕機', '微波爐', '冰箱', '家電', '電鍋'])) {
      return OfferCategory.appliances;
    }
    if (_contains(value, ['路由器', '攝影機', '電腦', '耳機', '3c', 'mesh'])) {
      return OfferCategory.electronics;
    }
    if (_contains(value, ['家具', '寢具', '床墊', '鍋具', '收納'])) {
      return OfferCategory.homeLiving;
    }
    if (_contains(value, ['服飾', '鞋', '外套', '包包'])) return OfferCategory.fashion;
    if (_contains(value, ['尿布', '奶粉', '嬰兒', '兒童'])) return OfferCategory.baby;
    if (_contains(value, ['寵物', '貓糧', '狗糧', '貓砂'])) return OfferCategory.pets;
    if (_contains(value, ['汽車', '車用', '露營', '戶外', '運動'])) {
      return OfferCategory.automotiveAndOutdoor;
    }
    if (_contains(value, ['住宿', '機票', '展演', '電影', '遊樂園', '旅遊'])) {
      return OfferCategory.travelAndEntertainment;
    }
    if (_contains(value, ['餐廳', '咖啡', '外送', '餐飲票券'])) {
      return OfferCategory.diningVoucher;
    }
    if (_contains(value, ['星巴克', '拿鐵', 'coffee', 'starbucks'])) {
      return OfferCategory.diningVoucher;
    }
    if (_contains(value, ['衛生紙', '生活用品', '日用品', '垃圾袋'])) {
      return OfferCategory.dailyNecessities;
    }
    if (_contains(value, ['食品', '飲料', '零食', '咖啡', '茶', '餅乾'])) {
      return OfferCategory.foodAndDrink;
    }
    return OfferCategory.others;
  }

  _MergedCandidates _mergeFragments(List<CouponCandidate> values) {
    final merged = <CouponCandidate>[];
    var mergedCount = 0;
    for (final value in values) {
      final index = merged.indexWhere((item) => _sameProduct(item, value));
      if (index == -1) {
        merged.add(value);
        continue;
      }
      final current = merged[index];
      final mergedOriginal = current.originalPrice ?? value.originalPrice;
      final mergedPromotional =
          current.promotionalPrice ?? value.promotionalPrice;
      merged[index] = current.copyWith(
        title: current.title.length >= value.title.length
            ? current.title
            : value.title,
        merchant: current.merchant.isNotEmpty
            ? current.merchant
            : value.merchant,
        brand: current.brand.isNotEmpty ? current.brand : value.brand,
        model: current.model.isNotEmpty ? current.model : value.model,
        specification: current.specification.isNotEmpty
            ? current.specification
            : value.specification,
        itemNumber: current.itemNumber.isNotEmpty
            ? current.itemNumber
            : value.itemNumber,
        originalPrice: mergedOriginal,
        promotionalPrice: mergedPromotional,
        savings: mergedOriginal != null && mergedPromotional != null
            ? mergedOriginal - mergedPromotional
            : current.savings ?? value.savings,
        promotionConditions: {
          ...current.promotionConditions,
          ...value.promotionConditions,
        }.toList(),
        attentionFields: {
          ...current.attentionFields,
          ...value.attentionFields,
        }.toList(),
        state: current.needsReview || value.needsReview
            ? CandidateState.needsReview
            : CandidateState.ready,
        selected: false,
      );
      mergedCount++;
    }
    return _MergedCandidates(merged, mergedCount);
  }

  bool _sameProduct(CouponCandidate a, CouponCandidate b) {
    if (a.sourcePage != b.sourcePage) return false;
    if (a.sourceRegionId.isNotEmpty &&
        b.sourceRegionId.isNotEmpty &&
        a.sourceRegionId != b.sourceRegionId) {
      return false;
    }
    if (a.itemNumber.isNotEmpty && b.itemNumber.isNotEmpty) {
      return a.itemNumber == b.itemNumber;
    }
    if (a.model.isNotEmpty && b.model.isNotEmpty) {
      return a.model.toLowerCase() == b.model.toLowerCase() &&
          a.brand.toLowerCase() == b.brand.toLowerCase();
    }
    final left = _fingerprintTitle(a.title);
    final right = _fingerprintTitle(b.title);
    return left.length >= 8 && left == right;
  }

  String _extractTitle(List<String> lines) {
    final itemIndex = lines.indexWhere(_itemPattern.hasMatch);
    final pool = itemIndex > 0 ? lines.take(itemIndex) : lines;
    final ranked = pool.where(_isPlausibleTitle).toList()
      ..sort((a, b) => _titleScore(b).compareTo(_titleScore(a)));
    if (ranked.isEmpty) return '';
    final best = ranked.first;
    final sourceIndex = lines.indexOf(best);
    if (sourceIndex >= 0 && sourceIndex + 1 < lines.length) {
      final next = lines[sourceIndex + 1];
      if (_isPlausibleTitle(next) &&
          !_looksLikePrice(next) &&
          '$best $next'.length <= 70) {
        return '$best $next';
      }
    }
    return best;
  }

  String _withoutTrailingPrice(String value) => value
      .replaceFirst(
        RegExp(
          r'\s*(?:優惠價|特價|促銷價|會員價|福利價|售價|NT\$|[$＄])\s*[:：]?\s*[0-9][0-9,]*(?:\.[0-9]+)?\s*(?:元)?$',
          caseSensitive: false,
        ),
        '',
      )
      .trim();

  String _extractMerchant(List<String> lines, String documentMerchant) {
    final labeled = RegExp(r'^(?:店家|商家|適用門市|來源)[:：]\s*(.+)$');
    for (final line in lines) {
      final match = labeled.firstMatch(line);
      if (match != null && !_looksLikePrice(match.group(1)!)) {
        return match.group(1)!.trim();
      }
    }
    return documentMerchant;
  }

  String _extractBrand(List<String> lines) {
    final labeled = RegExp(r'^品牌[:：]\s*(.+)$');
    for (final line in lines) {
      final match = labeled.firstMatch(line);
      if (match != null) return match.group(1)!.trim();
    }
    final title = _extractTitle(lines);
    final match = RegExp(
      r'^([A-Z][A-Z0-9.&-]{1,20})(?:\s+|$)',
    ).firstMatch(title);
    return match?.group(1) ?? '';
  }

  _PriceSemantics _extractPrices(List<String> lines) {
    num? labeled(String labels) {
      final pattern = RegExp(
        '(?:$labels)\\s*[:：]?\\s*(?:NT[\u0024]|NT|[\u0024＄])?\\s*([0-9][0-9,]*(?:\\.[0-9]+)?)',
        caseSensitive: false,
      );
      for (final line in lines) {
        final match = pattern.firstMatch(line);
        if (match != null) return _amount(match.group(1));
      }
      return null;
    }

    final original = labeled('原價|原售價|一般售價|定價');
    var promotional = labeled('優惠價|特價|促銷價|賣場售價|會員價');
    var statedSavings = labeled('現省|省下|折價|折抵|共省');
    final standalone = <num>[];
    for (final line in lines) {
      if (_looksLikeDate(line) || _isBundleOrThreshold(line)) continue;
      if (RegExp(
        r'原價|原售價|一般售價|定價|優惠價|特價|促銷價|賣場售價|會員價|現省|省下|折價|折抵|共省',
      ).hasMatch(line)) {
        continue;
      }
      final match = RegExp(
        r'^(?:NT\$|NT|[$＄])?\s*([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:元)?$',
      ).firstMatch(line.trim());
      if (match != null) standalone.add(_amount(match.group(1))!);
      final savingsMatch = RegExp(
        r'^-\s*([0-9][0-9,]*(?:\.[0-9]+)?)$',
      ).firstMatch(line);
      if (savingsMatch != null)
        statedSavings ??= _amount(savingsMatch.group(1));
    }
    var ambiguous = false;
    var inferredStandalone = false;
    if (promotional == null && standalone.length == 1) {
      promotional = standalone.single;
      inferredStandalone = true;
    } else if (promotional == null && standalone.length > 1) {
      ambiguous = true;
    }
    final calculated = original != null && promotional != null
        ? original - promotional
        : null;
    final conflicting =
        original != null &&
        promotional != null &&
        (promotional > original ||
            (statedSavings != null && statedSavings != calculated));
    return _PriceSemantics(
      original: original,
      promotional: promotional,
      savings: conflicting ? null : calculated,
      ambiguous: ambiguous,
      conflicting: conflicting,
      inferredStandalone: inferredStandalone,
    );
  }

  _PriceSemantics _extractNativeSpatialPrices(
    ProductRegion region,
    _PriceSemantics fallback,
  ) {
    if (fallback.original != null && fallback.promotional != null) {
      return fallback;
    }
    final positives = <({num value, double top})>[];
    final discounts = <num>[];
    for (final block in region.blocks) {
      final text = block.line.text.trim();
      final discountMatch = RegExp(
        r'^-\s*([0-9][0-9,]*(?:\.[0-9]+)?)$',
      ).firstMatch(text);
      if (discountMatch != null) {
        final value = _amount(discountMatch.group(1));
        if (value != null) discounts.add(value);
        continue;
      }
      if (_isBundleOrThreshold(text)) continue;
      final priceMatch = RegExp(
        r'^(?:NT\$|NT|[$＄])?\s*([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:元)?$',
        caseSensitive: false,
      ).firstMatch(text);
      final value = _amount(priceMatch?.group(1));
      if (value != null && value > 0) {
        positives.add((value: value, top: block.line.top));
      }
    }
    if (positives.length != 2 || discounts.length != 1) return fallback;
    positives.sort((a, b) => a.top.compareTo(b.top));
    final original = positives.first.value;
    final promotional = positives.last.value;
    final savings = discounts.single;
    if (original <= promotional || original - promotional != savings) {
      return fallback;
    }
    return _PriceSemantics(
      original: original,
      promotional: promotional,
      savings: savings,
      ambiguous: false,
      conflicting: false,
      inferredStandalone: false,
    );
  }

  List<String> _extractConditions(List<String> lines) {
    final pattern = RegExp(
      r'任選\s*\d+\s*[件組]|任\s*\d+\s*組|第[二2]件\s*\d+折|指定(?:信用卡|支付)|會員限定|滿\s*[0-9,]+\s*(?:送|折)\s*[0-9,]+|限量|線上(?:另有|購物亦有)優惠|買.+送|(?:現省|省下|折價|折抵|共省|現折)\s*[0-9,]+|^-\s*[0-9][0-9,]*$',
    );
    return lines
        .where(pattern.hasMatch)
        .map((line) {
          final standaloneDiscount = RegExp(
            r'^-\s*([0-9][0-9,]*)$',
          ).firstMatch(line.trim());
          return standaloneDiscount == null
              ? line
              : '折價 ${standaloneDiscount.group(1)} 元';
        })
        .toSet()
        .toList();
  }

  String _extractItemNumber(List<String> lines) {
    for (final line in lines) {
      final match = _itemPattern.firstMatch(line);
      if (match != null) {
        return RegExp(r'\d{4,}').firstMatch(match.group(0)!)?.group(0) ?? '';
      }
    }
    return '';
  }

  String _extractModel(String title) {
    final values =
        RegExp(r'\b(?=[A-Z0-9-]*[A-Z])(?=[A-Z0-9-]*\d)[A-Z0-9-]{3,}\b')
            .allMatches(title)
            .map((match) => match.group(0)!)
            .where((value) => value != '2K' && value != '3C')
            .toList();
    return values.isEmpty ? '' : values.first;
  }

  String _extractSpecification(List<String> lines, String title) => lines
      .where(
        (line) =>
            line != title &&
            RegExp(
              r'\b\d+(?:\.\d+)?\s*(?:g|kg|ml|l|公升|入|包|吋|GB|TB|K)\b',
              caseSensitive: false,
            ).hasMatch(line) &&
            !_looksLikePrice(line),
      )
      .take(2)
      .join(' ');

  String _extractDescription(List<String> lines, String title) => lines
      .where(
        (line) =>
            line != title &&
            !_itemPattern.hasMatch(line) &&
            !_looksLikePrice(line) &&
            !_isNonProductLine(line),
      )
      .take(4)
      .join('\n');

  String _formatValue(_PriceSemantics prices, List<String> conditions) => [
    if (prices.original != null)
      '原價：${_money(prices.original!)} 元'
    else
      '原價：未提供',
    if (prices.promotional != null) '優惠價：${_money(prices.promotional!)} 元',
    if (prices.savings != null) '共省：${_money(prices.savings!)} 元',
    if (conditions.isNotEmpty) '優惠條件：${conditions.join('、')}',
  ].join('\n');

  String _detectDocumentMerchant(String text) {
    final value = text.toLowerCase();
    if (value.contains('costco') || text.contains('好市多')) return 'Costco 好市多';
    if (text.contains('全聯福利中心') || text.contains('全聯')) return '全聯福利中心';
    if (text.contains('家樂福') || value.contains('carrefour')) return '家樂福';
    if (text.contains('全家便利商店') || value.contains('familymart')) {
      return '全家便利商店';
    }
    if (value.contains('7-eleven') || text.contains('統一超商')) return '7-ELEVEN';
    return '';
  }

  int _productEvidence({
    required String title,
    required String itemNumber,
    required String model,
    required _PriceSemantics prices,
    required List<String> lines,
  }) {
    var score = 0;
    if (title.isNotEmpty) score += 2;
    if (itemNumber.isNotEmpty) score += 2;
    if (model.isNotEmpty) score++;
    if (prices.promotional != null || prices.original != null) score++;
    if (lines.any(
      (line) => RegExp(r'商品|產品|優惠券|折價券|分享券|組|機|器|食品|飲料').hasMatch(line),
    ))
      score++;
    return score;
  }

  bool _isNonProductOnly(List<String> lines) =>
      lines.isEmpty || lines.every(_isNonProductLine);

  bool _isNonProductLine(String value) =>
      RegExp(
        r'^(?:.+)?(?:優惠專區|活動專區)$|^(售價以官網為準|線上購物亦有優惠|活動數量有限|售完為止|【?賣場售價】?|商品實際顏色及尺寸以賣場陳列|注意事項|頁碼|第\s*\d+\s*頁)$',
      ).hasMatch(value.trim()) ||
      _looksLikeUiNoise(value) ||
      _itemPattern.hasMatch(value) ||
      _looksLikePrice(value);

  bool _isPlausibleTitle(String line) {
    final value = line.trim();
    if (value.length < 2 || value.length > 70) return false;
    if (_looksLikeDate(value) || _itemPattern.hasMatch(value)) return false;
    if (_looksLikeUiNoise(value) || _looksLikePrice(value)) return false;
    if (_isNonProductLine(value) || _extractConditions([value]).isNotEmpty)
      return false;
    if (RegExp(
      r'^(平均一組|優惠期間|活動期間|有效期限|使用期限|兌換期限|注意事項|本券|共\s*\d+\s*週)',
    ).hasMatch(value)) {
      return false;
    }
    if (RegExp(r'^(品牌|店家|商家|適用門市|來源)[:：]').hasMatch(value)) {
      return false;
    }
    return RegExp(r'[A-Za-z\u4e00-\u9fff]').hasMatch(value);
  }

  bool _isIncompleteTitle(String title) =>
      title.length < 4 ||
      RegExp(r'[#：:]$').hasMatch(title) ||
      !RegExp(r'[A-Za-z\u4e00-\u9fff]{2,}').hasMatch(title);

  int _titleScore(String line) {
    var score = 0;
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(line)) score += 4;
    if (RegExp(r'商品|組|入|機|器|食品|飲料|路由器|除濕機').hasMatch(line)) score += 3;
    if (line.length >= 5 && line.length <= 45) score += 2;
    if (RegExp(r'^[A-Z0-9 .&-]+$').hasMatch(line)) score -= 2;
    return score;
  }

  bool _looksLikeDate(String value) =>
      RegExp(r'\d{1,4}\s*[年./-]\s*\d{1,2}').hasMatch(value);
  bool _looksLikeUiNoise(String value) =>
      RegExp(r'^\s*\d{1,2}[:：]\d{2}').hasMatch(value) ||
      RegExp(
        r'\b(?:4G|5G|LTE|VoLTE|Wi-?Fi)\b',
        caseSensitive: false,
      ).hasMatch(value) ||
      RegExp(r'^(返回|首頁|搜尋|購物車|我的|分享|更多)$').hasMatch(value.trim());
  bool _looksLikePrice(String value) => RegExp(
    r'^(?:原價|原售價|一般售價|定價|優惠價|特價|促銷價|賣場售價|會員價|現省|省下|折價|折抵|共省)?\s*[:：]?\s*(?:NT\$|NT|[$＄]|-)?\s*[0-9][0-9,]*(?:\.[0-9]+)?(?:\s*元)?(?:\s*【?賣場售價】?)?$',
    caseSensitive: false,
  ).hasMatch(value.trim());
  bool _isBundleOrThreshold(String value) =>
      RegExp(r'任選|任\s*\d+|第[二2]件|滿\s*[0-9,]+|平均|每(?:件|組|入)|單價').hasMatch(value);

  num? _amount(String? source) => source == null
      ? null
      : num.tryParse(source.replaceAll(',', '').replaceAll(' ', ''));
  String _money(num value) {
    final raw = value is double && value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    final parts = raw.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return parts.length == 1 ? whole : '$whole.${parts.last}';
  }

  int _stateOrder(CandidateState value) => switch (value) {
    CandidateState.needsReview => 0,
    CandidateState.ready => 1,
    CandidateState.rejected => 2,
  };
  String _fingerprintTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]'), '');
  bool _contains(String text, List<String> terms) => terms.any(text.contains);
  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  DateTime? _validDate(int year, int month, int day) {
    if (year < 2000 || year > (_now?.call() ?? DateTime.now()).year + 10) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final value = DateTime(year, month, day);
    return value.year == year && value.month == month && value.day == day
        ? value
        : null;
  }

  static final RegExp _itemPattern = RegExp(
    r'\bI[T7][E3]M\s*[:#-]?\s*\d{4,}\b',
    caseSensitive: false,
  );
}

class _PriceSemantics {
  const _PriceSemantics({
    required this.original,
    required this.promotional,
    required this.savings,
    required this.ambiguous,
    required this.conflicting,
    required this.inferredStandalone,
  });

  final num? original;
  final num? promotional;
  final num? savings;
  final bool ambiguous;
  final bool conflicting;
  final bool inferredStandalone;
}

class _MergedCandidates {
  const _MergedCandidates(this.values, this.mergedCount);

  final List<CouponCandidate> values;
  final int mergedCount;
}

class _CanonicalCandidate {
  const _CanonicalCandidate({
    required this.candidate,
    required this.contaminationCount,
  });

  final CouponCandidate candidate;
  final int contaminationCount;
}
