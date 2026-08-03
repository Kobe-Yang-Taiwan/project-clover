import 'dart:convert';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/offer_storage.dart';
import 'offer_reminder_service.dart';

class DiagnosticInfo {
  const DiagnosticInfo({
    required this.appVersion,
    required this.buildNumber,
    required this.androidVersion,
    required this.deviceInformation,
    required this.notificationPermission,
    this.databaseVersion = SharedPreferencesOfferStorage.schemaVersion,
  });

  final String appVersion;
  final String buildNumber;
  final String androidVersion;
  final String deviceInformation;
  final NotificationPermissionState notificationPermission;
  final int databaseVersion;

  String get notificationPermissionLabel => switch (notificationPermission) {
        NotificationPermissionState.granted => 'granted',
        NotificationPermissionState.denied => 'denied',
        NotificationPermissionState.unknown => 'unknown',
      };

  Map<String, Object> toJson() => {
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'androidVersion': androidVersion,
        'deviceInformation': deviceInformation,
        'notificationPermission': notificationPermissionLabel,
        'databaseVersion': databaseVersion,
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  String toFeedbackBody() => '''
請描述發生的問題或建議：


---
Project Clover 測試資訊
App Version: $appVersion
Build Number: $buildNumber
Device: $deviceInformation
Android Version: $androidVersion
''';
}

abstract interface class DiagnosticInfoProvider {
  Future<DiagnosticInfo> collect(OfferReminderScheduler reminders);
}

class AndroidDiagnosticInfoProvider implements DiagnosticInfoProvider {
  AndroidDiagnosticInfoProvider({
    DeviceInfoPlugin? deviceInfo,
  }) : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;

  @override
  Future<DiagnosticInfo> collect(OfferReminderScheduler reminders) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final android = await _deviceInfo.androidInfo;
    NotificationPermissionState permission;
    try {
      permission = await reminders.permissionState();
    } catch (_) {
      permission = NotificationPermissionState.unknown;
    }
    final manufacturer = android.manufacturer.trim();
    final model = android.model.trim();
    return DiagnosticInfo(
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      androidVersion:
          '${android.version.release} (SDK ${android.version.sdkInt})',
      deviceInformation: [manufacturer, model]
          .where((value) => value.isNotEmpty)
          .join(' '),
      notificationPermission: permission,
    );
  }
}

abstract interface class DiagnosticExportService {
  Future<bool> export(DiagnosticInfo info);
}

class FilePickerDiagnosticExportService implements DiagnosticExportService {
  @override
  Future<bool> export(DiagnosticInfo info) async {
    final now = DateTime.now();
    final date = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '匯出診斷資訊',
      fileName: 'project-clover-diagnostic-$date.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(info.toPrettyJson())),
    );
    return path != null;
  }
}

abstract interface class FeedbackLauncher {
  Future<bool> open(DiagnosticInfo info);
}

class EmailFeedbackLauncher implements FeedbackLauncher {
  @override
  Future<bool> open(DiagnosticInfo info) {
    final uri = feedbackEmailUri(info);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Uri feedbackEmailUri(DiagnosticInfo info) {
  return Uri(
    scheme: 'mailto',
    queryParameters: {
      'subject': 'Project Clover Beta 回饋',
      'body': info.toFeedbackBody(),
    },
  );
}
