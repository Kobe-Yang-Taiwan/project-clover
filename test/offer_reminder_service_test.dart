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

      expect(offer.effectiveReminderAt, DateTime(2026, 8, 10 - days, 18, 30));
    }
  });

  test('notification IDs are deterministic and distinct', () {
    expect(notificationIdFor('same-offer'), notificationIdFor('same-offer'));
    expect(notificationIdFor('offer-a'), isNot(notificationIdFor('offer-b')));
  });

  test('future active enabled reminder is eligible for scheduling', () {
    final offer = Offer(
      id: 'future',
      name: '未來提醒',
      expiresAt: DateTime(2026, 8, 10),
      reminderDaysBefore: 1,
      reminderHour: 9,
    );

    expect(
      shouldScheduleOfferReminder(
        offer,
        scheduledDate: offer.effectiveReminderAt,
        now: DateTime(2026, 8, 9, 8, 59),
      ),
      isTrue,
    );
  });

  test('past disabled and completed reminders are not scheduled', () {
    final past = Offer(
      id: 'past',
      name: '已過時間',
      expiresAt: DateTime(2026, 8, 10),
    );
    final disabled = Offer(
      id: 'disabled',
      name: '關閉提醒',
      expiresAt: DateTime(2026, 8, 20),
      reminderEnabled: false,
    );
    final completed = Offer(
      id: 'completed',
      name: '已完成',
      expiresAt: DateTime(2026, 8, 20),
      status: OfferStatus.completed,
    );

    expect(
      shouldScheduleOfferReminder(
        past,
        scheduledDate: past.effectiveReminderAt,
        now: DateTime(2026, 8, 9, 9),
      ),
      isFalse,
    );
    expect(
      shouldScheduleOfferReminder(
        disabled,
        scheduledDate: disabled.effectiveReminderAt,
        now: DateTime(2026, 8, 1),
      ),
      isFalse,
    );
    expect(
      shouldScheduleOfferReminder(
        completed,
        scheduledDate: completed.effectiveReminderAt,
        now: DateTime(2026, 8, 1),
      ),
      isFalse,
    );
  });

  test(
    'noop cancellation remains safe when notifications are unavailable',
    () async {
      const scheduler = NoopOfferReminderScheduler();

      await expectLater(
        scheduler.cancel('offer-without-notifications'),
        completes,
      );
    },
  );
}
