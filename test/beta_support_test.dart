import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/beta_support.dart';
import 'package:project_clover/offer_reminder_service.dart';

void main() {
  const info = DiagnosticInfo(
    appVersion: '0.12.0',
    buildNumber: '12',
    androidVersion: '16 (SDK 36)',
    deviceInformation: 'Example Phone',
    notificationPermission: NotificationPermissionState.granted,
  );

  test('diagnostic JSON includes all founder support fields', () {
    final json = jsonDecode(info.toPrettyJson()) as Map<String, dynamic>;

    expect(json['appVersion'], '0.12.0');
    expect(json['buildNumber'], '12');
    expect(json['androidVersion'], '16 (SDK 36)');
    expect(json['notificationPermission'], 'granted');
    expect(json['databaseVersion'], 1);
  });

  test('feedback email contains version build and device information', () {
    final uri = feedbackEmailUri(info);

    expect(uri.scheme, 'mailto');
    expect(uri.queryParameters['subject'], 'Project Clover Beta Feedback');
    final body = uri.queryParameters['body']!;
    expect(body, contains('App Version: 0.12.0'));
    expect(body, contains('Build Number: 12'));
    expect(body, contains('Android Version: 16 (SDK 36)'));
    expect(body, contains('Device Model: Example Phone'));
  });

  test('feedback and diagnostics never include coupon content', () {
    const privateCoupon = 'PRIVATE-COUPON-CONTENT';

    expect(info.toFeedbackBody(), isNot(contains(privateCoupon)));
    expect(info.toPrettyJson(), isNot(contains(privateCoupon)));
    expect(info.toJson().keys, isNot(contains('offers')));
    expect(info.toJson().keys, isNot(contains('coupons')));
  });
}
