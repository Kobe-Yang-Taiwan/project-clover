import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/models/offer.dart';
import 'package:project_clover/offer_reminder_service.dart';

void main() {
  test('legacy offers default to 9 AM one day before expiry', () {
    final offer = Offer(
      id: 'reminder-test',
      name: '提醒測試',
      expiresAt: DateTime(2026, 8, 10),
    );

    expect(offer.effectiveReminderAt, DateTime(2026, 8, 9, 9));
  });

  test('custom reminder date and time override the default', () {
    final offer = Offer(
      id: 'custom-reminder',
      name: '自訂提醒',
      expiresAt: DateTime(2026, 8, 10),
      reminderAt: DateTime(2026, 8, 8, 18, 30),
    );

    expect(offer.effectiveReminderAt, DateTime(2026, 8, 8, 18, 30));
  });

  test('notification IDs are deterministic and distinct', () {
    expect(notificationIdFor('same-offer'), notificationIdFor('same-offer'));
    expect(notificationIdFor('offer-a'), isNot(notificationIdFor('offer-b')));
  });
}
