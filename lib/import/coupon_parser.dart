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

  String _extractTitle(List<String> lines) {
    for (final line in lines) {
      if (line.length < 2 || line.length > 50 || _looksLikeDate(line)) continue;
      if (RegExp(r'^(有效期限|使用期限|活動期間|兌換期限|注意事項|本券)').hasMatch(line)) {
        continue;
      }
      return line;
    }
    return '';
  }

  String _extractMerchant(List<String> lines, String title) {
    final labeled = RegExp(r'^(?:品牌|店家|商家|適用門市|來源)[:：]\s*(.+)$');
    for (final line in lines) {
      final match = labeled.firstMatch(line);
      if (match != null) return match.group(1)!.trim();
    }
    return lines.firstWhere(
      (line) => line != title && line.length <= 24 && !_looksLikeDate(line),
      orElse: () => '',
    );
  }

  String _extractValue(List<String> lines) => lines.firstWhere(
    (line) =>
        RegExp(r'(\d+\s*%|\d+\s*折|[$NT＄]\s*\d+|現折|折抵|買.+送)').hasMatch(line),
    orElse: () => '',
  );

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
