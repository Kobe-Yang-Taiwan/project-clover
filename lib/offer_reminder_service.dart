import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'models/offer.dart';

abstract interface class OfferReminderScheduler {
  Future<bool> requestPermission();

  Future<void> sync(Iterable<Offer> activeOffers);

  Future<void> cancel(String offerId);
}

class NoopOfferReminderScheduler implements OfferReminderScheduler {
  const NoopOfferReminderScheduler();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> sync(Iterable<Offer> activeOffers) async {}

  @override
  Future<void> cancel(String offerId) async {}
}

class AndroidOfferReminderScheduler implements OfferReminderScheduler {
  AndroidOfferReminderScheduler._(this._notifications);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'offer_expiry_reminders',
      '優惠到期提醒',
      channelDescription: '在優惠到期前一天提醒使用',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  final FlutterLocalNotificationsPlugin _notifications;

  static Future<AndroidOfferReminderScheduler> create() async {
    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    return AndroidOfferReminderScheduler._(notifications);
  }

  @override
  Future<bool> requestPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<void> sync(Iterable<Offer> activeOffers) async {
    await _notifications.cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    final offers = activeOffers
        .where((offer) => !offer.isCompleted && offer.reminderEnabled)
        .take(100);

    for (final offer in offers) {
      final reminder = offer.effectiveReminderAt;
      final scheduledDate = tz.TZDateTime(
        tz.local,
        reminder.year,
        reminder.month,
        reminder.day,
        reminder.hour,
        reminder.minute,
      );
      if (!scheduledDate.isAfter(now)) continue;

      await _notifications.zonedSchedule(
        id: notificationIdFor(offer.id),
        title: '優惠即將到期：${offer.name}',
        body: '記得在期限前使用，別讓優惠悄悄溜走。',
        scheduledDate: scheduledDate,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: offer.id,
      );
    }
  }

  @override
  Future<void> cancel(String offerId) {
    return _notifications.cancel(id: notificationIdFor(offerId));
  }
}


int notificationIdFor(String offerId) {
  var hash = 0x811C9DC5;
  for (final unit in offerId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}
