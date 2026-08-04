import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'models/offer.dart';

enum NotificationPermissionState { granted, denied, unknown }

bool shouldScheduleOfferReminder(
  Offer offer, {
  required DateTime scheduledDate,
  required DateTime now,
}) {
  return !offer.isCompleted &&
      offer.reminderEnabled &&
      scheduledDate.isAfter(now);
}

abstract interface class OfferReminderScheduler {
  String? get initialOfferId;

  Future<bool> requestPermission();

  Future<NotificationPermissionState> permissionState();

  Future<void> sync(Iterable<Offer> activeOffers);

  Future<void> cancel(String offerId);
}

class NoopOfferReminderScheduler implements OfferReminderScheduler {
  const NoopOfferReminderScheduler();

  @override
  String? get initialOfferId => null;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<NotificationPermissionState> permissionState() async =>
      NotificationPermissionState.unknown;

  @override
  Future<void> sync(Iterable<Offer> activeOffers) async {}

  @override
  Future<void> cancel(String offerId) async {}
}

class AndroidOfferReminderScheduler implements OfferReminderScheduler {
  AndroidOfferReminderScheduler._(
    this._notifications,
    this.initialOfferId,
  );

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'offer_expiry_reminders',
      '優惠到期提醒',
      channelDescription: '依照選擇的提前天數與時間提醒使用',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  final FlutterLocalNotificationsPlugin _notifications;

  @override
  final String? initialOfferId;

  static Future<AndroidOfferReminderScheduler> create({
    required void Function(String offerId) onOfferSelected,
  }) async {
    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final offerId = response.payload;
        if (offerId != null && offerId.isNotEmpty) {
          onOfferSelected(offerId);
        }
      },
    );
    final launchDetails =
        await notifications.getNotificationAppLaunchDetails();
    final initialOfferId = launchDetails?.didNotificationLaunchApp ?? false
        ? launchDetails?.notificationResponse?.payload
        : null;
    return AndroidOfferReminderScheduler._(
      notifications,
      initialOfferId,
    );
  }

  @override
  Future<bool> requestPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  @override
  Future<NotificationPermissionState> permissionState() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final enabled = await android?.areNotificationsEnabled();
    return switch (enabled) {
      true => NotificationPermissionState.granted,
      false => NotificationPermissionState.denied,
      null => NotificationPermissionState.unknown,
    };
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
      if (!shouldScheduleOfferReminder(
        offer,
        scheduledDate: scheduledDate,
        now: now,
      )) {
        continue;
      }

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
