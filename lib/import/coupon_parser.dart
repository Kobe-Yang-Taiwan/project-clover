import '../models/offer.dart';
import 'coupon_import_models.dart';

class CouponParser {
  const CouponParser({DateTime Function()? now}) : _now = now;

  final DateTime Function()? _now;

  CouponCandidate parse(
    OcrPageResult page, {
    String? id,
    String documentMerchant = '',
  }) {
    final lines = page.lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !_looksLikeUiNoise(line))
        .toList();
    final dates = parseDates(lines.join('\n'));
    final merchant = _extractMerchant(lines, documentMerchant);
    final brand = _extractBrand(lines);
    final title = _extractTitle(lines);
    final prices = _extractPrices(lines);
    final conditions = _extractConditions(lines);
    final itemNumber = _extractItemNumber(lines);
    final model = _extractModel(title);
    final specification = _extractSpecification(lines, title);

    final productEvidence = _productEvidence(
      title: title,
      itemNumber: itemNumber,
      model: model,
      prices: prices,
      lines: lines,
    );
    final rejected =
        productEvidence < 2 ||
        (title.isEmpty && itemNumber.isEmpty) ||
        _isNonProductOnly(lines);
    final attention = <String>[
      if (title.isEmpty) '商品名稱不完整',
      if (title.isNotEmpty && _isIncompleteTitle(title)) '商品名稱不完整',
      if (merchant.isEmpty) '缺少商家／來源',
      if (dates.selected == null) '缺少到期日',
      if (dates.isAmbiguous || dates.yearMissing) '到期日需要確認',
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
      id: id ?? '${page.pageNumber ?? 0}-${page.text.hashCode}',
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
      offerDescription: _extractDescription(lines, title),
      valueText: _formatValue(prices, conditions),
      category: suggestCategory('$title $specification ${lines.join(' ')}'),
      sourcePage: page.pageNumber,
      confidence: confidence,
      state: state,
      attentionFields: attention.toSet().toList(),
      alternativeDates: dates.alternatives,
      rawText: page.text,
    );
  }

  List<CouponCandidate> parsePages(List<OcrPageResult> pages) =>
      parsePagesDetailed(pages).candidates;

  CouponParseResult parsePagesDetailed(List<OcrPageResult> pages) {
    final watch = Stopwatch()..start();
    final parsed = <CouponCandidate>[];
    var rawRegions = 0;
    var rejectedCount = 0;
    for (final page in pages.where((page) => page.succeeded)) {
      final merchant = _detectDocumentMerchant(page.text);
      final chunks = _splitCandidates(page);
      rawRegions += chunks.length;
      for (var index = 0; index < chunks.length; index++) {
        final candidate = parse(
          chunks[index],
          id: '${page.pageNumber ?? 0}-$index',
          documentMerchant: merchant,
        );
        if (candidate.isRejected) {
          rejectedCount++;
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
      report: ImportQualityReport(
        rawDetectedRegions: rawRegions,
        readyCount: sorted
            .where((item) => item.state == CandidateState.ready)
            .length,
        needsReviewCount: sorted
            .where((item) => item.state == CandidateState.needsReview)
            .length,
        rejectedCount: rejectedCount,
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
      ),
    );
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

  List<OcrPageResult> _splitCandidates(OcrPageResult page) {
    final positioned = page.positionedLines
        .where((line) => !_looksLikeUiNoise(line.text))
        .toList();
    final itemAnchors = positioned
        .where((line) => _itemPattern.hasMatch(line.text))
        .toList();
    if (itemAnchors.isNotEmpty) {
      final regions = _splitSpatialByAnchors(page, itemAnchors);
      if (regions.isNotEmpty) return regions;
    }
    final priceAnchors = _deduplicatePriceAnchors(
      positioned.where((line) => _isStandaloneProductPrice(line.text)).toList(),
    );
    if (priceAnchors.length > 1) {
      final regions = _splitSpatialByAnchors(page, priceAnchors);
      if (regions.length > 1) return regions;
    }
    final chunks = page.text
        .split(RegExp(r'\n\s*(?:-{3,}|={3,}|\*{3,})\s*\n'))
        .where((chunk) => chunk.trim().isNotEmpty)
        .toList();
    if (chunks.length == 1) return [page];
    return chunks
        .map(
          (chunk) => OcrPageResult(
            sourceType: page.sourceType,
            pageNumber: page.pageNumber,
            text: chunk,
            lines: chunk.split('\n'),
            succeeded: true,
            duration: page.duration,
          ),
        )
        .toList();
  }

  List<OcrPageResult> _splitSpatialByAnchors(
    OcrPageResult page,
    List<OcrTextLine> anchors,
  ) {
    final sorted = List<OcrTextLine>.from(anchors)
      ..sort((a, b) => a.centerY.compareTo(b.centerY));
    final rows = <List<OcrTextLine>>[];
    for (final anchor in sorted) {
      if (rows.isEmpty ||
          (anchor.centerY - _averageY(rows.last)).abs() > 0.12) {
        rows.add([anchor]);
      } else {
        rows.last.add(anchor);
      }
    }
    for (final row in rows) {
      row.sort((a, b) => a.centerX.compareTo(b.centerX));
    }
    final common = page.positionedLines
        .where((line) => RegExp(r'優惠期間|活動期間|有效期限|使用期限').hasMatch(line.text))
        .map((line) => line.text.trim())
        .toSet()
        .toList();
    final results = <OcrPageResult>[];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final rowY = _averageY(row);
      final previousY = rowIndex == 0 ? 0.05 : _averageY(rows[rowIndex - 1]);
      final nextY = rowIndex == rows.length - 1
          ? 0.98
          : _averageY(rows[rowIndex + 1]);
      final top = rowIndex == 0 ? 0.05 : (previousY + rowY) / 2;
      final bottom = rowIndex == rows.length - 1 ? 0.98 : (rowY + nextY) / 2;
      for (var column = 0; column < row.length; column++) {
        final anchor = row[column];
        final left = column == 0
            ? 0.0
            : (row[column - 1].centerX + anchor.centerX) / 2;
        final right = column == row.length - 1
            ? 1.0
            : (anchor.centerX + row[column + 1].centerX) / 2;
        final cellLines =
            page.positionedLines
                .where(
                  (line) =>
                      !_looksLikeUiNoise(line.text) &&
                      line.centerX >= left &&
                      line.centerX < right &&
                      line.centerY >= top &&
                      line.centerY < bottom,
                )
                .toList()
              ..sort((a, b) {
                final vertical = a.top.compareTo(b.top);
                return vertical == 0 ? a.left.compareTo(b.left) : vertical;
              });
        final textLines = cellLines
            .map((line) => line.text.trim())
            .where((line) => line.isNotEmpty)
            .toList();
        if (textLines.isEmpty) continue;
        final allLines = [...textLines, ...common];
        results.add(
          OcrPageResult(
            sourceType: page.sourceType,
            pageNumber: page.pageNumber,
            text: allLines.join('\n'),
            lines: allLines,
            succeeded: true,
            duration: page.duration,
            positionedLines: cellLines,
          ),
        );
      }
    }
    return results;
  }

  List<OcrTextLine> _deduplicatePriceAnchors(List<OcrTextLine> values) {
    final result = <OcrTextLine>[];
    for (final value in values) {
      final close = result.any(
        (item) =>
            (item.centerX - value.centerX).abs() < 0.08 &&
            (item.centerY - value.centerY).abs() < 0.08,
      );
      if (!close) result.add(value);
    }
    return result;
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
    int? labeled(String labels) {
      final pattern = RegExp(
        '(?:$labels)\\s*[:：]?\\s*(?:NT[\u0024]|NT|[\u0024＄])?\\s*([0-9][0-9,]*)',
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
    final standalone = <int>[];
    for (final line in lines) {
      if (_looksLikeDate(line) || _isBundleOrThreshold(line)) continue;
      if (RegExp(
        r'原價|原售價|一般售價|定價|優惠價|特價|促銷價|賣場售價|會員價|現省|省下|折價|折抵|共省',
      ).hasMatch(line)) {
        continue;
      }
      final match = RegExp(
        r'^(?:NT\$|NT|[$＄])?\s*([0-9][0-9,]*)\s*(?:元)?$',
      ).firstMatch(line.trim());
      if (match != null) standalone.add(_amount(match.group(1))!);
      final savingsMatch = RegExp(r'^-\s*([0-9][0-9,]*)$').firstMatch(line);
      if (savingsMatch != null)
        statedSavings ??= _amount(savingsMatch.group(1));
    }
    var ambiguous = false;
    if (promotional == null && standalone.length == 1) {
      promotional = standalone.single;
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
      savings: conflicting ? null : calculated ?? statedSavings,
      ambiguous: ambiguous,
      conflicting: conflicting,
    );
  }

  List<String> _extractConditions(List<String> lines) {
    final pattern = RegExp(
      r'任選\s*\d+\s*[件組]|任\s*\d+\s*組|第[二2]件\s*\d+折|指定(?:信用卡|支付)|會員限定|滿\s*[0-9,]+\s*(?:送|折)\s*[0-9,]+|限量|線上(?:另有|購物亦有)優惠|買.+送',
    );
    return lines.where(pattern.hasMatch).toSet().toList();
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
    if (lines.any((line) => RegExp(r'商品|組|入|包|機|器|食品|飲料').hasMatch(line)))
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
    r'^(?:原價|原售價|一般售價|定價|優惠價|特價|促銷價|賣場售價|會員價|現省|省下|折價|折抵|共省)?\s*[:：]?\s*(?:NT\$|NT|[$＄]|-)?\s*[0-9][0-9,]*(?:\s*元)?(?:\s*【?賣場售價】?)?$',
    caseSensitive: false,
  ).hasMatch(value.trim());
  bool _isStandaloneProductPrice(String value) =>
      !_looksLikeDate(value) &&
      !_isBundleOrThreshold(value) &&
      RegExp(
        r'(?:優惠價|特價|促銷價|賣場售價|會員價|NT\$|[$＄])\s*[0-9][0-9,]*|^\s*[0-9][0-9,]{2,}\s*元?\s*$',
        caseSensitive: false,
      ).hasMatch(value);
  bool _isBundleOrThreshold(String value) =>
      RegExp(r'任選|任\s*\d+|第[二2]件|滿\s*[0-9,]+|平均|每(?:件|組|入)|單價').hasMatch(value);

  int? _amount(String? source) => source == null
      ? null
      : int.tryParse(source.replaceAll(',', '').replaceAll(' ', ''));
  String _money(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  int _stateOrder(CandidateState value) => switch (value) {
    CandidateState.needsReview => 0,
    CandidateState.ready => 1,
    CandidateState.rejected => 2,
  };
  String _fingerprintTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff]'), '');
  double _averageY(List<OcrTextLine> lines) =>
      lines.map((line) => line.centerY).reduce((a, b) => a + b) / lines.length;
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
  });

  final int? original;
  final int? promotional;
  final int? savings;
  final bool ambiguous;
  final bool conflicting;
}

class _MergedCandidates {
  const _MergedCandidates(this.values, this.mergedCount);

  final List<CouponCandidate> values;
  final int mergedCount;
}
