import '../models/offer.dart';
import 'coupon_import_models.dart';

class CouponParser {
  const CouponParser({DateTime Function()? now}) : _now = now;

  final DateTime Function()? _now;

  CouponCandidate parse(OcrPageResult page, {String? id}) {
    final lines = page.lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final dates = parseDates(page.text);
    final title = _extractTitle(lines);
    final merchant = _extractMerchant(lines, title);
    final value = _extractValue(lines);
    final attention = <String>[
      if (title.isEmpty) '優惠名稱',
      if (dates.selected == null) '到期日',
      if (dates.isAmbiguous) '到期日有多個可能值',
      if (dates.yearMissing) '日期缺少年份',
    ];
    final confidence = attention.isEmpty
        ? ImportConfidence.high
        : attention.length == 1 && title.isNotEmpty
        ? ImportConfidence.medium
        : ImportConfidence.low;
    return CouponCandidate(
      id: id ?? '${page.pageNumber ?? 0}-${page.text.hashCode}',
      title: title,
      merchant: merchant,
      startDate: dates.start,
      expirationDate: dates.selected,
      offerDescription: _extractDescription(lines, title, merchant),
      valueText: value,
      category: suggestCategory('$title $merchant ${page.text}'),
      sourcePage: page.pageNumber,
      confidence: confidence,
      attentionFields: attention,
      alternativeDates: dates.alternatives,
      rawText: page.text,
    );
  }

  List<CouponCandidate> parsePages(List<OcrPageResult> pages) {
    final candidates = <CouponCandidate>[];
    for (final page in pages.where((page) => page.succeeded)) {
      final chunks = _splitCandidates(page);
      for (var index = 0; index < chunks.length; index++) {
        candidates.add(parse(chunks[index], id: '${page.pageNumber}-$index'));
      }
    }
    return candidates;
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
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      final parsed = _validDate(year, month, day);
      if (parsed == null) continue;
      all.add(parsed);
      final prefixStart = match.start > 12 ? match.start - 12 : 0;
      final prefix = text.substring(prefixStart, match.start);
      if (RegExp(r'有效期限|使用期限|活動期間|兌換期限|截止|至\s*$').hasMatch(prefix)) {
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
    if (_contains(value, ['咖啡', '拿鐵', 'coffee', '星巴克']))
      return OfferCategory.coffee;
    if (_contains(value, ['超商', '7-eleven', '全家', '萊爾富'])) {
      return OfferCategory.convenienceStore;
    }
    if (_contains(value, ['餐', '食品', '飲料', 'food', 'pizza', '麥當勞'])) {
      return OfferCategory.food;
    }
    if (_contains(value, ['百貨', 'mall', '購物中心']))
      return OfferCategory.departmentStore;
    if (_contains(value, ['網購', '電商', '蝦皮', 'momo', 'pchome'])) {
      return OfferCategory.onlineShopping;
    }
    if (_contains(value, ['電影', '影城', '遊樂園', '娛樂']))
      return OfferCategory.entertainment;
    if (_contains(value, ['旅館', '飯店', '住宿', '旅行', '機票']))
      return OfferCategory.travel;
    if (_contains(value, ['捷運', '高鐵', '計程車', '停車', '交通'])) {
      return OfferCategory.transportation;
    }
    return OfferCategory.others;
  }

  List<OcrPageResult> _splitCandidates(OcrPageResult page) {
    final spatial = _splitCatalogueByItemAnchors(page);
    if (spatial.length > 1) return spatial;
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

  List<OcrPageResult> _splitCatalogueByItemAnchors(OcrPageResult page) {
    final positioned = page.positionedLines;
    final anchors =
        positioned.where((line) => _itemPattern.hasMatch(line.text)).toList()
          ..sort((a, b) => a.centerY.compareTo(b.centerY));
    if (anchors.length < 2) return const [];

    final rows = <List<OcrTextLine>>[];
    for (final anchor in anchors) {
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

    final commonDateLines = positioned
        .where((line) => RegExp(r'優惠期間|活動期間|有效期限|使用期限').hasMatch(line.text))
        .map((line) => line.text.trim())
        .where((line) => line.isNotEmpty)
        .toSet()
        .toList();
    final results = <OcrPageResult>[];
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
        final anchor = row[column];
        final left = column == 0
            ? 0.0
            : (row[column - 1].centerX + anchor.centerX) / 2;
        final right = column == row.length - 1
            ? 1.0
            : (anchor.centerX + row[column + 1].centerX) / 2;
        final cellLines =
            positioned
                .where(
                  (line) =>
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
        if (!textLines.any((line) => _itemPattern.hasMatch(line))) continue;
        final combined = [...textLines, ...commonDateLines].join('\n');
        results.add(
          OcrPageResult(
            sourceType: page.sourceType,
            pageNumber: page.pageNumber,
            text: combined,
            lines: [...textLines, ...commonDateLines],
            succeeded: true,
            duration: page.duration,
            positionedLines: cellLines,
          ),
        );
      }
    }
    return results;
  }

  double _averageY(List<OcrTextLine> lines) =>
      lines.map((line) => line.centerY).reduce((a, b) => a + b) / lines.length;

  String _extractTitle(List<String> lines) {
    final itemIndex = lines.indexWhere(_itemPattern.hasMatch);
    if (itemIndex > 0) {
      final productLines = lines
          .take(itemIndex)
          .where(_isPlausibleTitle)
          .take(2)
          .toList();
      if (productLines.isNotEmpty) return productLines.join(' ');
    }
    final ranked = lines.where(_isPlausibleTitle).toList()
      ..sort((a, b) => _titleScore(b).compareTo(_titleScore(a)));
    if (ranked.isNotEmpty) {
      return ranked.first;
    }
    return '';
  }

  String _extractMerchant(List<String> lines, String title) {
    final labeled = RegExp(r'^(?:品牌|店家|商家|適用門市|來源)[:：]\s*(.+)$');
    for (final line in lines) {
      final match = labeled.firstMatch(line);
      if (match != null) return match.group(1)!.trim();
    }
    final itemIndex = lines.indexWhere(_itemPattern.hasMatch);
    if (itemIndex > 0) {
      return lines
          .take(itemIndex)
          .firstWhere(_isPlausibleTitle, orElse: () => '');
    }
    return lines.firstWhere(
      (line) => line != title && _isPlausibleTitle(line),
      orElse: () => '',
    );
  }

  String _extractValue(List<String> lines) {
    final discount = lines.firstWhere(
      (line) => RegExp(r'(?:^|\s)-\s*\d[\d,]*').hasMatch(line),
      orElse: () => '',
    );
    if (discount.isNotEmpty) return discount;
    return lines.firstWhere(
      (line) =>
          !_looksLikeStatusBar(line) &&
          RegExp(
            r'(\d+\s*%|\d+\s*折|[$NT＄]\s*\d[\d,]*|特價\s*\d+|\d+\s*元|現折|折抵|買.+送)',
          ).hasMatch(line),
      orElse: () => '',
    );
  }

  String _extractDescription(
    List<String> lines,
    String title,
    String merchant,
  ) => lines
      .where((line) => line != title && line != merchant)
      .take(4)
      .join('\n');

  bool _looksLikeDate(String value) =>
      RegExp(r'\d{1,4}\s*[年./-]\s*\d{1,2}').hasMatch(value);
  bool _looksLikeStatusBar(String value) =>
      RegExp(r'^\s*\d{1,2}[:：]\d{2}').hasMatch(value) ||
      RegExp(r'\b(?:4G|5G|LTE|VoLTE)\b', caseSensitive: false).hasMatch(value);
  bool _isPlausibleTitle(String line) {
    final value = line.trim();
    if (value.length < 2 || value.length > 60) return false;
    if (_looksLikeDate(value) || _itemPattern.hasMatch(value)) return false;
    if (_looksLikeStatusBar(value) ||
        RegExp(r'^(?:\d+[.,]?\d*|[-+＄$]\s*\d)').hasMatch(value)) {
      return false;
    }
    if (RegExp(
      r'^(優惠期間|活動期間|有效期限|使用期限|兌換期限|注意事項|本券|售完為止|活動數量有限|線上購物|售價以|賣場售價|共\s*\d+\s*週)',
    ).hasMatch(value)) {
      return false;
    }
    return RegExp(r'[A-Za-z\u4e00-\u9fff]').hasMatch(value);
  }

  int _titleScore(String line) {
    var score = 0;
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(line)) score += 4;
    if (RegExp(r'優惠|券|折|送|商品|組|入').hasMatch(line)) score += 3;
    if (RegExp(r'商店|門市|公司|股份|品牌').hasMatch(line)) score -= 3;
    if (line.length >= 4 && line.length <= 32) score += 2;
    if (RegExp(r'^[A-Z0-9 .&-]+$').hasMatch(line)) score -= 2;
    return score;
  }

  static final RegExp _itemPattern = RegExp(
    r'\bI[T7][E3]M\s*[:#-]?\s*\d{4,}\b',
    caseSensitive: false,
  );
  bool _contains(String text, List<String> terms) => terms.any(text.contains);
  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  DateTime? _validDate(int year, int month, int day) {
    if (year < 2000 || year > (_now?.call() ?? DateTime.now()).year + 10)
      return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final value = DateTime(year, month, day);
    return value.year == year && value.month == month && value.day == day
        ? value
        : null;
  }
}
