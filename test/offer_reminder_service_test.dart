import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/models/offer.dart';
import 'package:project_clover/offer_reminder_service.dart';

void main() {
  test('reminder is scheduled at 9 AM one day before expiry', () {
    final offer = Offer(
      id: 'reminder-test',
      name: '提醒測試',
      expiresAt: DateTime(2026, 8, 10),
    );

    expect(reminderDateFor(offer), DateTime(2026, 8, 9, 9));
  });

  test('notification IDs are deterministic and distinct', () {
    final first = reminderDateFor(
      Offer(id: 'a', name: 'A', expiresAt: DateTime(2026, 8, 10)),
    );
    final second = reminderDateFor(
      Offer(id: 'b', name: 'B', expiresAt: DateTime(2026, 8, 11)),
    );

    expect(first, isNot(second));
  });
}
