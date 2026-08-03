import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/beta_support.dart';
import 'package:project_clover/offer_reminder_service.dart';

void main() {
  const info = DiagnosticInfo(
    appVersion: '0.11.0',
    buildNumber: '11',
    androidVersion: '16 (SDK 36)',
    deviceInformation: 'Example Phone',
    notificationPermission: NotificationPermissionState.granted,
  );

  test('diagnostic JSON includes all founder support fields', () {
    final json = jsonDecode(info.toPrettyJson()) as Map<String, dynamic>;

    expect(json['appVersion'], '0.11.0');
    expect(json['buildNumber'], '11');
    expect(json['androidVersion'], '16 (SDK 36)');
    expect(json['notificationPermission'], 'granted');
    expect(json['databaseVersion'], 1);
  });

  test('feedback email contains version build and device information', () {
    final uri = feedbackEmailUri(info);

    expect(uri.scheme, 'mailto');
    expect(uri.queryParameters['subject'], 'Project Clover Beta 回饋');
    final body = uri.queryParameters['body']!;
    expect(body, contains('App Version: 0.11.0'));
    expect(body, contains('Build Number: 11'));
    expect(body, contains('Device: Example Phone'));
    expect(body, contains('Android Version: 16 (SDK 36)'));
  });
}
