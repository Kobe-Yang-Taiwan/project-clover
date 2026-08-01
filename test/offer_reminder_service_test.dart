import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/models/offer.dart';
import 'package:project_clover/offer_reminder_service.dart';

void main() {
  test('offers default to 9 AM one day before expiry', () {
    final offer = Offer(
      id: 'reminder-test',
      name: '提醒測試',
      expiresAt: DateTime(2026, 8, 10),
    );

    expect(offer.effectiveReminderAt, DateTime(2026, 8, 9, 9));
  });

  test('1 3 and 7 day presets keep the same selected time', () {
    for (final days in Offer.supportedReminderDays) {
      final offer = Offer(
        id: 'preset-$days',
        name: '提前 $days 天',
        expiresAt: DateTime(2026, 8, 10),
        reminderDaysBefore: days,
        reminderHour: 18,
        reminderMinute: 30,
      );

      expect(
        offer.effectiveReminderAt,
        DateTime(2026, 8, 10 - days, 18, 30),
      );
    }
  });

  test('notification IDs are deterministic and distinct', () {
    expect(notificationIdFor('same-offer'), notificationIdFor('same-offer'));
    expect(notificationIdFor('offer-a'), isNot(notificationIdFor('offer-b')));
  });
}
