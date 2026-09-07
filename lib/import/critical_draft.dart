import 'coupon_import_models.dart';
import 'coupon_parser.dart';

enum FieldConfidence { high, medium, low }

class DraftField<T> {
  const DraftField(this.value, this.candidates, this.confidence);
  final T? value;
  final List<T> candidates;
  final FieldConfidence confidence;
}

class CriticalDraft {
  const CriticalDraft({
    required this.name,
    required this.expiration,
    required this.value,
  });
  final DraftField<String> name;
  final DraftField<DateTime> expiration;
  final DraftField<String> value;

  /// One intended benefit, local evidence only. This is not a product parser.
  factory CriticalDraft.fromPage(OcrPageResult page) {
    final lines = page.succeeded
        ? page.lines
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList()
        : <String>[];
    final values = <String>[];
    final names = <String>[];
    final dates = <DateTime>[];
    var explicitExpiry = false;
    final discount = RegExp(
      r'買[一二三四五六七八九十\d]+送[一二三四五六七八九十\d]+|buy\s*\d+\s*get\s*\d+|\d+(?:\.\d+)?\s*%\s*off|\d(?:\.\d+)?\s*折|(?:折抵|現折|折扣|折價|省)\s*(?:NT\s*\$|\$)?\s*\d+(?:\.\d+)?\s*元?|(?:NT\s*\$|\$)\s*\d+(?:\.\d+)?\s*(?:折扣|優惠券|折價券)|\d+(?:\.\d+)?\s*元\s*(?:折扣|優惠券|折價券)',
      caseSensitive: false,
    );
    final excluded = RegExp(
      r'ITEM|品號|貨號|條款|聲明|不得|不適用|詳情|依現場|以.*為準|續下頁|客服|電話|製造|保存|有效|期限|到期|截止|期間|expiry|expires|valid|https?://',
      caseSensitive: false,
    );
    for (final line in lines) {
      // Keep qualifying text such as minimum spend. Long, unclear terms need
      // correction, not an amount stripped of its conditions.
      if (line.length <= 80 && discount.hasMatch(line) && !values.contains(line)) {
        values.add(line);
      }
      // Dates without a year remain unknown. Do not mistake manufacture dates
      // for expiration, or silently select between unrelated coupon dates.
      if (!RegExp(
        r'製造|出廠|出生|manufactur',
        caseSensitive: false,
      ).hasMatch(line)) {
        final parsed = const CouponParser().parseDates(line);
        if (parsed.selected != null &&
            (parsed.start == null ||
                !parsed.selected!.isBefore(parsed.start!))) {
          final selected = parsed.selected!;
          if (!dates.contains(selected)) dates.add(selected);
          if (parsed.isAmbiguous) {
            for (final alternative in parsed.alternatives) {
              if (!dates.contains(alternative)) dates.add(alternative);
            }
          }
          explicitExpiry =
              explicitExpiry ||
              RegExp(
                r'有效|期限|到期|截止|expiry|expires|valid until',
                caseSensitive: false,
              ).hasMatch(line);
        }
      }
      final onlyDiscount = discount.stringMatch(line) == line;
      final numericOrSpec = RegExp(
        r'^[\d\s.,×xX*/$%+\-()入包組盒瓶公克毫升gGmMlL]+$',
      ).hasMatch(line);
      if (line.length >= 3 &&
          line.length <= 60 &&
          !excluded.hasMatch(line) &&
          !onlyDiscount &&
          !numericOrSpec &&
          !RegExp(r'^\d{2,4}[./年-]').hasMatch(line) &&
          RegExp(r'[a-zA-Z\u4e00-\u9fff]').hasMatch(line) &&
          !names.contains(line)) {
        names.add(line);
      }
    }
    final nameChoices = names.take(5).toList();
    return CriticalDraft(
      name: DraftField(
        nameChoices.length == 1 ? nameChoices.single : null,
        nameChoices,
        nameChoices.length == 1 ? FieldConfidence.medium : FieldConfidence.low,
      ),
      expiration: DraftField(
        dates.length == 1 ? dates.single : null,
        dates.take(8).toList(),
        dates.length == 1
            ? (explicitExpiry ? FieldConfidence.high : FieldConfidence.medium)
            : FieldConfidence.low,
      ),
      value: DraftField(
        values.length == 1 ? values.single : null,
        values.take(8).toList(),
        values.length == 1 ? FieldConfidence.medium : FieldConfidence.low,
      ),
    );
  }
}

String draftDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime criticalDraftReminderTime(DateTime expiry, DateTime now) {
  final day = DateTime(expiry.year, expiry.month, expiry.day);
  final normal = day
      .add(const Duration(hours: 9))
      .subtract(const Duration(days: 1));
  if (normal.isAfter(now)) return normal;
  final today = DateTime(now.year, now.month, now.day);
  return day.isAfter(today)
      ? day.add(const Duration(hours: 9))
      : now.add(const Duration(minutes: 2));
}
