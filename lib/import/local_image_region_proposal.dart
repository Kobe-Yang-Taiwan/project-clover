import 'coupon_import_models.dart';
import 'document_understanding.dart';
import 'retailer_adapters.dart';

class LocalImageRegionProposalEngine {
  const LocalImageRegionProposalEngine({
    DocumentUnderstandingPipeline understanding =
        const DocumentUnderstandingPipeline(),
  }) : _understanding = understanding;

  final DocumentUnderstandingPipeline _understanding;

  List<ProposedImageRegion> propose(
    OcrPageResult page, {
    required RetailerAdapter adapter,
  }) {
    final usable = page.positionedLines
        .where((line) => line.text.trim().isNotEmpty)
        .toList();
    if (usable.isEmpty) return const [];

    final priceAnchors = _deduplicate(
      usable.where((line) => _isPriceAnchor(line)).toList(),
    );
    final identityAnchors = _deduplicate(
      usable
          .where((line) => _isCorroboratedIdentity(line, usable))
          .where(
            (line) => !priceAnchors.any(
              (price) =>
                  (price.centerX - line.centerX).abs() < 0.16 &&
                  (price.centerY - line.centerY).abs() < 0.11,
            ),
          )
          .toList(),
    );
    final anchors = _deduplicate([...priceAnchors, ...identityAnchors]);
    if (anchors.isEmpty) return const [];

    final rows = _rows(anchors);
    final rowCenters = rows.map(_averageY).toList();
    final typicalRowSpacing = _medianSpacing(rowCenters);
    final regions = <ProposedImageRegion>[];
    final occupied = <String>{};

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final rowY = rowCenters[rowIndex];
      final top = rowIndex == 0
          ? (rowY - typicalRowSpacing * 0.62).clamp(0.0, 1.0).toDouble()
          : (rowCenters[rowIndex - 1] + rowY) / 2;
      final bottom = rowIndex == rows.length - 1
          ? (rowY + typicalRowSpacing * 0.38).clamp(0.0, 1.0).toDouble()
          : (rowY + rowCenters[rowIndex + 1]) / 2;

      for (var anchorIndex = 0; anchorIndex < row.length; anchorIndex++) {
        final anchor = row[anchorIndex];
        final horizontal = _horizontalBounds(
          row,
          anchorIndex,
          expectedColumns: adapter.expectedImageColumns,
        );
        final columnKey = adapter.expectedImageColumns == null
            ? anchorIndex
            : (anchor.centerX * adapter.expectedImageColumns!)
                  .clamp(0, adapter.expectedImageColumns! - 1)
                  .floor();
        final key = '$rowIndex-$columnKey';
        if (!occupied.add(key)) continue;
        final bounds = OcrRegionBounds(
          left: horizontal.$1,
          top: top,
          right: horizontal.$2,
          bottom: bottom,
        );
        final hasProductText = usable.any(
          (line) =>
              line.overlaps(bounds) &&
              _understanding.classify(line) == SemanticBlockType.productName,
        );
        final isPriceAnchor = _isPriceAnchor(anchor);
        regions.add(
          ProposedImageRegion(
            id: 'image-r$rowIndex-c$columnKey',
            bounds: bounds,
            signals: {
              if (isPriceAnchor) LocalRegionSignal.priceAnchor,
              if (!isPriceAnchor || hasProductText)
                LocalRegionSignal.productText,
              LocalRegionSignal.spatialSeparation,
              if (hasProductText) LocalRegionSignal.productText,
              if (rows.length > 1 || row.length > 1)
                LocalRegionSignal.repeatedGrid,
              if (adapter.id != 'generic') LocalRegionSignal.retailerHint,
            },
            confidence: isPriceAnchor && hasProductText
                ? 0.9
                : isPriceAnchor
                ? 0.68
                : 0.74,
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

  ProposedImageRegion recoverAt({
    required double x,
    required double y,
    required List<ProposedImageRegion> existing,
    required RetailerAdapter adapter,
  }) {
    final columns = adapter.expectedImageColumns ?? _estimatedColumns(existing);
    final horizontalPadding = 0.5 / columns;
    final rowHeight = _estimatedRowHeight(existing);
    return ProposedImageRegion(
      id: 'image-recovery-${(x * 10000).round()}-${(y * 10000).round()}',
      bounds: OcrRegionBounds(
        left: (x - horizontalPadding).clamp(0.0, 1.0).toDouble(),
        top: (y - rowHeight * 0.62).clamp(0.0, 1.0).toDouble(),
        right: (x + horizontalPadding).clamp(0.0, 1.0).toDouble(),
        bottom: (y + rowHeight * 0.38).clamp(0.0, 1.0).toDouble(),
      ),
      signals: {
        LocalRegionSignal.userTap,
        LocalRegionSignal.spatialSeparation,
        if (adapter.id != 'generic') LocalRegionSignal.retailerHint,
      },
      confidence: 0.72,
    );
  }

  bool _isPriceAnchor(OcrTextLine line) {
    final value = line.text.trim();
    final type = _understanding.classify(line);
    if ({
      SemanticBlockType.date,
      SemanticBlockType.itemNumber,
      SemanticBlockType.specification,
      SemanticBlockType.discount,
      SemanticBlockType.paymentCampaign,
      SemanticBlockType.disclaimer,
      SemanticBlockType.legal,
      SemanticBlockType.header,
      SemanticBlockType.footer,
      SemanticBlockType.pageDecoration,
    }.contains(type)) {
      return false;
    }
    if (RegExp(r'平均|每(?:件|組|包|瓶|罐)|點|回饋|滿\s*[0-9,]+').hasMatch(value)) {
      return false;
    }
    if (RegExp(r'\d{1,2}[:：/]\d{1,2}|20\d{2}').hasMatch(value)) return false;
    return RegExp(
          r'(?:優惠價|特價|促銷價|會員價|福利價|售價|NT\$|[$＄])\s*[:：]?\s*[0-9][0-9,]*(?:\.[0-9]+)?',
          caseSensitive: false,
        ).hasMatch(value) ||
        RegExp(r'^[0-9][0-9,]{1,5}(?:\.[0-9]+)?\s*(?:元)?$').hasMatch(value) ||
        RegExp(
          r'[A-Za-z\u4e00-\u9fff]{2,}.*[0-9][0-9,]{1,5}(?:\.[0-9]+)?\s*元?$',
        ).hasMatch(value);
  }

  bool _isCorroboratedIdentity(OcrTextLine line, List<OcrTextLine> allLines) {
    if (_understanding.classify(line) != SemanticBlockType.productName ||
        _isPriceAnchor(line)) {
      return false;
    }
    final value = line.text.trim();
    if (RegExp(r'優惠|活動|專區|會員|門市|詳情|辦法|限定').hasMatch(value)) {
      return false;
    }
    return allLines.any((other) {
      if (identical(other, line)) return false;
      if ((other.centerX - line.centerX).abs() > 0.18 ||
          (other.centerY - line.centerY).abs() > 0.10) {
        return false;
      }
      return {
        SemanticBlockType.specification,
        SemanticBlockType.promotion,
        SemanticBlockType.brand,
        SemanticBlockType.itemNumber,
      }.contains(_understanding.classify(other));
    });
  }

  List<OcrTextLine> _deduplicate(List<OcrTextLine> values) {
    final result = <OcrTextLine>[];
    for (final value in values) {
      if (result.any(
        (existing) =>
            (existing.centerX - value.centerX).abs() < 0.035 &&
            (existing.centerY - value.centerY).abs() < 0.025,
      )) {
        continue;
      }
      result.add(value);
    }
    return result;
  }

  List<List<OcrTextLine>> _rows(List<OcrTextLine> anchors) {
    final sorted = List<OcrTextLine>.from(anchors)
      ..sort((a, b) => a.centerY.compareTo(b.centerY));
    final rows = <List<OcrTextLine>>[];
    for (final anchor in sorted) {
      if (rows.isEmpty ||
          (anchor.centerY - _averageY(rows.last)).abs() > 0.075) {
        rows.add([anchor]);
      } else {
        rows.last.add(anchor);
      }
    }
    for (final row in rows) {
      row.sort((a, b) => a.centerX.compareTo(b.centerX));
    }
    return rows;
  }

  (double, double) _horizontalBounds(
    List<OcrTextLine> row,
    int index, {
    required int? expectedColumns,
  }) {
    final anchor = row[index];
    if (expectedColumns != null && expectedColumns > 1) {
      final column = (anchor.centerX * expectedColumns)
          .clamp(0, expectedColumns - 1)
          .floor();
      return (column / expectedColumns, (column + 1) / expectedColumns);
    }
    final left = index == 0
        ? 0.0
        : (row[index - 1].centerX + anchor.centerX) / 2;
    final right = index == row.length - 1
        ? 1.0
        : (anchor.centerX + row[index + 1].centerX) / 2;
    return (left, right);
  }

  double _averageY(List<OcrTextLine> values) =>
      values.map((value) => value.centerY).reduce((a, b) => a + b) /
      values.length;

  double _medianSpacing(List<double> centers) {
    if (centers.length < 2) return 0.30;
    final gaps = <double>[
      for (var index = 1; index < centers.length; index++)
        centers[index] - centers[index - 1],
    ]..sort();
    return gaps[gaps.length ~/ 2].clamp(0.12, 0.5).toDouble();
  }

  int _estimatedColumns(List<ProposedImageRegion> existing) {
    if (existing.isEmpty) return 2;
    final centers = existing
        .map((region) => (region.bounds.left + region.bounds.right) / 2)
        .toSet();
    return centers.length.clamp(1, 4).toInt();
  }

  double _estimatedRowHeight(List<ProposedImageRegion> existing) {
    if (existing.isEmpty) return 0.28;
    final heights =
        existing
            .map((region) => region.bounds.bottom - region.bounds.top)
            .toList()
          ..sort();
    return heights[heights.length ~/ 2].clamp(0.14, 0.5).toDouble();
  }
}
