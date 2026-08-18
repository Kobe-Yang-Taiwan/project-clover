import 'coupon_import_models.dart';

class ProductRegion {
  const ProductRegion({
    required this.id,
    required this.bounds,
    required this.blocks,
  });

  final String id;
  final OcrRegionBounds bounds;
  final List<ClassifiedOcrLine> blocks;

  List<String> get lines =>
      blocks.map((block) => block.line.text.trim()).toList();
}

class DocumentUnderstandingResult {
  const DocumentUnderstandingResult({
    required this.regions,
    required this.sharedBlocks,
    required this.classifiedBlocks,
  });

  final List<ProductRegion> regions;
  final List<ClassifiedOcrLine> sharedBlocks;
  final List<ClassifiedOcrLine> classifiedBlocks;

  String toStructuredMarkdown({required int pageNumber, String merchant = ''}) {
    final buffer = StringBuffer('# Page $pageNumber\n\n');
    for (var index = 0; index < regions.length; index++) {
      final region = regions[index];
      buffer.writeln('## Product Cell ${index + 1}');
      if (merchant.trim().isNotEmpty) buffer.writeln('Merchant: $merchant');
      buffer.writeln('Region: ${region.id}');
      for (final block in region.blocks) {
        buffer.writeln(
          '${block.type.name}: ${block.line.text.trim()} '
          '[${block.line.left.toStringAsFixed(3)},'
          '${block.line.top.toStringAsFixed(3)},'
          '${block.line.right.toStringAsFixed(3)},'
          '${block.line.bottom.toStringAsFixed(3)}]',
        );
      }
      buffer.writeln();
    }
    if (sharedBlocks.isNotEmpty) {
      buffer.writeln('## Shared Page Metadata');
      for (final block in sharedBlocks) {
        buffer.writeln('${block.type.name}: ${block.line.text.trim()}');
      }
    }
    return buffer.toString();
  }
}

class DocumentUnderstandingPipeline {
  const DocumentUnderstandingPipeline();

  DocumentUnderstandingResult understand(OcrPageResult page) {
    final sourceLines = page.positionedLines.isNotEmpty
        ? page.positionedLines
        : _syntheticLines(page.lines);
    final ordered = List<OcrTextLine>.from(sourceLines)
      ..sort((a, b) {
        final vertical = a.top.compareTo(b.top);
        return vertical == 0 ? a.left.compareTo(b.left) : vertical;
      });
    final classified = <ClassifiedOcrLine>[
      for (var index = 0; index < ordered.length; index++)
        ClassifiedOcrLine(
          line: ordered[index],
          type: classify(ordered[index]),
          readingOrder: index,
        ),
    ];
    if (page.sourceRegionId != null && page.sourceBounds != null) {
      final explicitShared = <ClassifiedOcrLine>[
        for (var index = 0; index < page.sharedPositionedLines.length; index++)
          ClassifiedOcrLine(
            line: page.sharedPositionedLines[index],
            type: classify(page.sharedPositionedLines[index]),
            readingOrder: classified.length + index,
          ),
      ].where(_isSharedPageBlock).toList();
      final locallyShared = classified.where(_isSharedPageBlock).toList();
      final owned = classified
          .where((block) => !_isSharedPageBlock(block))
          .toList();
      return DocumentUnderstandingResult(
        regions: owned.isEmpty
            ? const []
            : [
                ProductRegion(
                  id: page.sourceRegionId!,
                  bounds: page.sourceBounds!,
                  blocks: owned,
                ),
              ],
        sharedBlocks: [...explicitShared, ...locallyShared],
        classifiedBlocks: [...classified, ...explicitShared],
      );
    }
    final shared = classified.where(_isSharedPageBlock).toList();
    final assignable = classified
        .where((block) => !_isSharedPageBlock(block))
        .toList();
    final costcoRegions =
        page.extractionMethod == ImportExtractionMethod.nativePdfText &&
            _looksLikeCostcoPage(classified)
        ? _costcoGridRegions(page, assignable)
        : const <ProductRegion>[];
    if (costcoRegions.isNotEmpty) {
      return DocumentUnderstandingResult(
        regions: costcoRegions,
        sharedBlocks: shared,
        classifiedBlocks: classified,
      );
    }
    final anchors = _selectAnchors(
      assignable,
      allowWeakPriceAnchors: page.positionedLines.isNotEmpty,
      allowProductNameAnchors:
          page.extractionMethod == ImportExtractionMethod.nativePdfText,
    );
    final regions = anchors.length > 1
        ? _regionsFromAnchors(page, assignable, anchors)
        : _singleOrSeparatedRegions(page, assignable);
    return DocumentUnderstandingResult(
      regions: regions,
      sharedBlocks: shared,
      classifiedBlocks: classified,
    );
  }

  SemanticBlockType classify(OcrTextLine line) {
    final value = line.text.trim();
    if (value.isEmpty || _pageDecoration.hasMatch(value)) {
      return SemanticBlockType.pageDecoration;
    }
    if (_uiNoise.hasMatch(value)) return SemanticBlockType.pageDecoration;
    if (_disclaimer.hasMatch(value)) return SemanticBlockType.disclaimer;
    if (_legal.hasMatch(value)) return SemanticBlockType.legal;
    if (_paymentCampaign.hasMatch(value)) {
      return SemanticBlockType.paymentCampaign;
    }
    if (_genericHeader.hasMatch(value)) return SemanticBlockType.header;
    if (_footer.hasMatch(value) ||
        (line.centerY > 0.965 && !_hasProductIdentityText(value))) {
      return SemanticBlockType.footer;
    }
    if (_merchant.hasMatch(value)) return SemanticBlockType.merchant;
    if (_date.hasMatch(value)) return SemanticBlockType.date;
    if (_item.hasMatch(value)) return SemanticBlockType.itemNumber;
    if (_embeddedProductPrice.hasMatch(value)) {
      return SemanticBlockType.productName;
    }
    if (_originalPrice.hasMatch(value)) return SemanticBlockType.originalPrice;
    if (_promoPrice.hasMatch(value)) return SemanticBlockType.promoPrice;
    if (_discount.hasMatch(value)) return SemanticBlockType.discount;
    if (_specificationOnly.hasMatch(value)) {
      return SemanticBlockType.specification;
    }
    if (_promotion.hasMatch(value)) return SemanticBlockType.promotion;
    if (_brand.hasMatch(value)) return SemanticBlockType.brand;
    if (_standalonePrice.hasMatch(value)) return SemanticBlockType.unknown;
    if (_hasProductIdentityText(value)) return SemanticBlockType.productName;
    return SemanticBlockType.unknown;
  }

  List<OcrTextLine> _syntheticLines(List<String> values) {
    final nonEmpty = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (nonEmpty.isEmpty) return const [];
    final step = 0.9 / nonEmpty.length;
    return [
      for (var index = 0; index < nonEmpty.length; index++)
        OcrTextLine(
          text: nonEmpty[index],
          left: 0.05,
          top: 0.05 + step * index,
          right: 0.95,
          bottom: 0.05 + step * (index + 0.8),
        ),
    ];
  }

  bool _isSharedPageBlock(ClassifiedOcrLine block) {
    final value = block.line.text.trim();
    if (block.type == SemanticBlockType.merchant) return true;
    if (block.type == SemanticBlockType.date &&
        RegExp(r'優惠期間|活動期間|有效期間|全館|本檔|本期').hasMatch(value)) {
      return true;
    }
    return block.type == SemanticBlockType.header ||
        block.type == SemanticBlockType.footer ||
        block.type == SemanticBlockType.disclaimer ||
        block.type == SemanticBlockType.legal ||
        block.type == SemanticBlockType.paymentCampaign;
  }

  List<ClassifiedOcrLine> _selectAnchors(
    List<ClassifiedOcrLine> blocks, {
    required bool allowWeakPriceAnchors,
    required bool allowProductNameAnchors,
  }) {
    final items = blocks
        .where((block) => block.type == SemanticBlockType.itemNumber)
        .toList();
    if (items.isNotEmpty) return _deduplicateAnchors(items);
    final promoPrices = blocks
        .where((block) => block.type == SemanticBlockType.promoPrice)
        .toList();
    if (promoPrices.isNotEmpty) return _deduplicateAnchors(promoPrices);
    if (allowProductNameAnchors) {
      final productNames = blocks
          .where((block) => block.type == SemanticBlockType.productName)
          .toList();
      final anchors = _deduplicateAnchors(productNames, distance: 0.08);
      if (anchors.length > 1) return anchors;
    }
    if (!allowWeakPriceAnchors) return const [];
    final standalonePrices = blocks
        .where(
          (block) =>
              block.type == SemanticBlockType.unknown &&
              _standalonePrice.hasMatch(block.line.text.trim()),
        )
        .toList();
    return _deduplicateAnchors(standalonePrices);
  }

  List<ClassifiedOcrLine> _deduplicateAnchors(
    List<ClassifiedOcrLine> values, {
    double distance = 0.045,
  }) {
    final result = <ClassifiedOcrLine>[];
    for (final value in values) {
      final duplicate = result.any(
        (existing) =>
            (existing.line.centerX - value.line.centerX).abs() < distance &&
            (existing.line.centerY - value.line.centerY).abs() < distance,
      );
      if (!duplicate) result.add(value);
    }
    return result;
  }

  List<ProductRegion> _regionsFromAnchors(
    OcrPageResult page,
    List<ClassifiedOcrLine> blocks,
    List<ClassifiedOcrLine> anchors,
  ) {
    final rows = <List<ClassifiedOcrLine>>[];
    final sorted = List<ClassifiedOcrLine>.from(anchors)
      ..sort((a, b) => a.line.centerY.compareTo(b.line.centerY));
    for (final anchor in sorted) {
      if (rows.isEmpty ||
          (anchor.line.centerY - _averageY(rows.last)).abs() > 0.10) {
        rows.add([anchor]);
      } else {
        rows.last.add(anchor);
      }
    }
    for (final row in rows) {
      row.sort((a, b) => a.line.centerX.compareTo(b.line.centerX));
    }

    final regions = <ProductRegion>[];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final rowY = _averageY(row);
      final previousY = rowIndex == 0 ? 0.0 : _averageY(rows[rowIndex - 1]);
      final nextY = rowIndex == rows.length - 1
          ? 1.0
          : _averageY(rows[rowIndex + 1]);
      final top = rowIndex == 0 ? 0.0 : (previousY + rowY) / 2;
      final bottom = rowIndex == rows.length - 1 ? 1.0 : (rowY + nextY) / 2;
      for (var column = 0; column < row.length; column++) {
        final anchor = row[column].line;
        final left = column == 0
            ? 0.0
            : (row[column - 1].line.centerX + anchor.centerX) / 2;
        final right = column == row.length - 1
            ? 1.0
            : (anchor.centerX + row[column + 1].line.centerX) / 2;
        final bounds = OcrRegionBounds(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
        );
        final owned =
            blocks.where((block) => block.line.overlaps(bounds)).toList()
              ..sort((a, b) => a.readingOrder.compareTo(b.readingOrder));
        if (owned.isEmpty) continue;
        regions.add(
          ProductRegion(
            id: 'p${page.pageNumber ?? 0}-r$rowIndex-c$column',
            bounds: bounds,
            blocks: owned,
          ),
        );
      }
    }
    return regions;
  }

  /// Costco native-text catalogs use four independent vertical columns.
  /// Discount labels are stable cell-local anchors, while ITEM labels are not
  /// present for every product. Grouping anchors independently per column
  /// preserves ownership when columns contain different row counts.
  List<ProductRegion> _costcoGridRegions(
    OcrPageResult page,
    List<ClassifiedOcrLine> blocks,
  ) {
    final discountAnchors = blocks
        .where((block) => block.type == SemanticBlockType.discount)
        .toList();
    if (discountAnchors.length < 4) return const [];

    final columns = List.generate(4, (_) => <List<ClassifiedOcrLine>>[]);
    for (final anchor in discountAnchors) {
      final column = (anchor.line.centerX.clamp(0.0, 0.999999) * 4).floor();
      final groups = columns[column];
      List<ClassifiedOcrLine>? matching;
      for (final group in groups) {
        if ((anchor.line.centerY - _averageY(group)).abs() < 0.055) {
          matching = group;
          break;
        }
      }
      if (matching == null) {
        groups.add([anchor]);
      } else {
        matching.add(anchor);
      }
    }

    final regions = <ProductRegion>[];
    for (var columnIndex = 0; columnIndex < columns.length; columnIndex++) {
      final groups = columns[columnIndex]
        ..sort((a, b) => _averageY(a).compareTo(_averageY(b)));
      if (groups.isEmpty) continue;
      for (var rowIndex = 0; rowIndex < groups.length; rowIndex++) {
        final centerY = _averageY(groups[rowIndex]);
        final previousY = rowIndex == 0 ? 0.0 : _averageY(groups[rowIndex - 1]);
        final nextY = rowIndex == groups.length - 1
            ? 1.0
            : _averageY(groups[rowIndex + 1]);
        final bounds = OcrRegionBounds(
          left: columnIndex / 4,
          top: rowIndex == 0 ? 0.0 : (previousY + centerY) / 2,
          right: (columnIndex + 1) / 4,
          bottom: rowIndex == groups.length - 1 ? 1.0 : (centerY + nextY) / 2,
        );
        final owned =
            blocks
                .where(
                  (block) =>
                      block.line.centerX >= bounds.left &&
                      block.line.centerX < bounds.right &&
                      block.line.centerY >= bounds.top &&
                      block.line.centerY < bounds.bottom,
                )
                .toList()
              ..sort((a, b) => a.readingOrder.compareTo(b.readingOrder));
        if (owned.isEmpty) continue;
        regions.add(
          ProductRegion(
            id: 'p${page.pageNumber ?? 0}-costco-c$columnIndex-r$rowIndex',
            bounds: bounds,
            blocks: owned,
          ),
        );
      }
    }
    regions.sort((a, b) {
      final vertical = a.bounds.top.compareTo(b.bounds.top);
      return vertical == 0 ? a.bounds.left.compareTo(b.bounds.left) : vertical;
    });
    return regions;
  }

  bool _looksLikeCostcoPage(List<ClassifiedOcrLine> blocks) => blocks.any(
    (block) =>
        RegExp(r'Costco|好市多', caseSensitive: false).hasMatch(block.line.text),
  );

  List<ProductRegion> _singleOrSeparatedRegions(
    OcrPageResult page,
    List<ClassifiedOcrLine> blocks,
  ) {
    final separators = blocks
        .where((block) => block.type == SemanticBlockType.pageDecoration)
        .map((block) => block.readingOrder)
        .toSet();
    final groups = <List<ClassifiedOcrLine>>[[]];
    for (final block in blocks) {
      if (separators.contains(block.readingOrder)) {
        if (groups.last.isNotEmpty) groups.add([]);
        continue;
      }
      groups.last.add(block);
    }
    return [
      for (var index = 0; index < groups.length; index++)
        if (groups[index].isNotEmpty)
          ProductRegion(
            id: 'p${page.pageNumber ?? 0}-g$index',
            bounds: const OcrRegionBounds(left: 0, top: 0, right: 1, bottom: 1),
            blocks: groups[index],
          ),
    ];
  }

  double _averageY(List<ClassifiedOcrLine> values) =>
      values.map((value) => value.line.centerY).reduce((a, b) => a + b) /
      values.length;

  bool _hasProductIdentityText(String value) =>
      value.length >= 3 &&
      value.length <= 90 &&
      RegExp(r'[A-Za-z\u4e00-\u9fff]{2,}').hasMatch(value) &&
      !_specificationOnly.hasMatch(value);

  static final RegExp _pageDecoration = RegExp(r'^(?:[-=*•·_]{3,}|\d{1,3})$');
  static final RegExp _uiNoise = RegExp(
    r'^\s*\d{1,2}[:：]\d{2}|\b(?:4G|5G|LTE|VoLTE|Wi-?Fi)\b|^(?:返回|首頁|搜尋|購物車|我的|分享|更多|通知)$',
    caseSensitive: false,
  );
  static final RegExp _disclaimer = RegExp(
    r'商品實際(?:包裝|顏色|尺寸)|實際商品以|售價以(?:官網|賣場)|圖片僅供參考|依(?:官網|賣場)為準|活動辦法以|本公司保留|每(?:會員卡|卡|人)限購|限購\s*\d|恕不接受|不得轉售',
  );
  static final RegExp _legal = RegExp(
    r'衛署|衛部|醫器|許可證|製造商|經銷商|進口商|藥商|統一編號|公司地址|客服專線|核准字號|字第\s*\d+號',
  );
  static final RegExp _paymentCampaign = RegExp(
    r'信用卡|行動支付|刷卡|銀行卡|紅利點數|回饋金|分期|支付享|卡友',
  );
  static final RegExp _genericHeader = RegExp(
    r'^(?:【?賣場售價】?|僅限好市多|.+(?:優惠專區|活動專區)|本期優惠|會員限定優惠)$',
  );
  static final RegExp _footer = RegExp(r'^(?:注意事項|頁碼|第\s*\d+\s*頁|詳情請見|更多資訊)');
  static final RegExp _merchant = RegExp(
    r'^(?:店家|商家|適用門市|來源)[:：]|Costco|好市多|全聯(?:福利中心)?|家樂福|FamilyMart|全家便利商店|7-ELEVEN|統一超商',
    caseSensitive: false,
  );
  static final RegExp _date = RegExp(
    r'(?:優惠期間|活動期間|有效期間|有效期限|使用期限|兌換期限|截止|至)?\s*(?:\d{2,4}\s*[年./-]\s*)?\d{1,2}\s*[月./-]\s*\d{1,2}',
  );
  static final RegExp _item = RegExp(
    r'\bI[T7][E3]M\s*[:#-]?\s*\d{4,}\b',
    caseSensitive: false,
  );
  static final RegExp _originalPrice = RegExp(
    r'(?:原價|原售價|一般售價|定價)\s*[:：]?\s*(?:NT\$|NT|[$＄])?\s*[0-9][0-9,]*(?:\.[0-9]+)?',
    caseSensitive: false,
  );
  static final RegExp _embeddedProductPrice = RegExp(
    r'^[A-Za-z\u4e00-\u9fff].{1,70}(?:優惠價|特價|促銷價|會員價|福利價|售價|NT\$|[$＄])\s*[:：]?\s*[0-9][0-9,]*(?:\.[0-9]+)?\s*(?:元)?$',
    caseSensitive: false,
  );
  static final RegExp _promoPrice = RegExp(
    r'(?:優惠價|特價|促銷價|賣場售價|會員價)\s*[:：]?\s*(?:NT\$|NT|[$＄])?\s*[0-9][0-9,]*(?:\.[0-9]+)?',
    caseSensitive: false,
  );
  static final RegExp _discount = RegExp(
    r'(?:現省|省下|折價|折抵|共省)\s*[:：]?\s*[0-9][0-9,]*(?:\.[0-9]+)?|^-\s*[0-9][0-9,]*(?:\.[0-9]+)?$',
  );
  static final RegExp _specificationOnly = RegExp(
    r'^\s*\d+(?:\.\d+)?\s*(?:(?:包|瓶|罐|個|袋|盒|組)入?|入|g|kg|ml|l|公升|吋|GB|TB)(?:\s*\([A-Z]{2,4}\))?\s*$',
    caseSensitive: false,
  );
  static final RegExp _promotion = RegExp(
    r'買.+送|任選\s*\d+|任\s*\d+\s*組|第[二2]件|滿\s*[0-9,]+\s*(?:送|折)|限量|加價購|現折\s*[0-9,]+|折$',
  );
  static final RegExp _brand = RegExp(r'^品牌[:：]\s*.+$');
  static final RegExp _standalonePrice = RegExp(
    r'^(?:NT\$|NT|[$＄])?\s*[0-9][0-9,]*(?:\.[0-9]+)?\s*(?:元)?$',
    caseSensitive: false,
  );
}
