import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:project_clover/import/critical_draft_screen.dart';
import 'package:project_clover/import/local_import_service.dart';
import 'package:project_clover/main.dart';
import 'package:project_clover/models/offer_store.dart';
import 'package:project_clover/offer_reminder_service.dart';

// Synthetic coupon raster, real Android ML Kit, real SharedPreferences and
// notification plugin. This is not Founder accuracy or delivery evidence.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android capture save reload and pending notification', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    final paragraph = (ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 72))
          ..pushStyle(ui.TextStyle(color: Colors.black, fontSize: 72))
          ..addText('Coffee Coupon\nValid until 2035/09/30\n20% OFF'))
        .build()
      ..layout(const ui.ParagraphConstraints(width: 1300));
    canvas.drawParagraph(paragraph, const Offset(40, 40));
    final picture = recorder.endRecording();
    final image = await picture.toImage(1400, 600);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final fixture = File('${Directory.systemTemp.path}/clover-smoke.png');
    await fixture.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();

    final store = await OfferStore.load();
    final before = store.allOffers.length;
    final reminders = await AndroidOfferReminderScheduler.create(
      onOfferSelected: (_) {},
    );
    await tester.pumpWidget(
      CloverApp(
        store: store,
        reminders: reminders,
        importService: DeviceCaptureService(fixture.path),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-offer-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('image-import-choice')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final name = tester.widget<TextField>(find.byKey(const Key('draft-name')));
    final value = tester.widget<TextField>(find.byKey(const Key('draft-value')));
    expect(name.controller!.text, 'Coffee Coupon');
    expect(value.controller!.text, '20% OFF');
    expect(find.text('2035-09-30'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('save-critical-draft')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('save-critical-draft')));
    for (var count = 0; count < 100; count++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.textContaining('系統待發提醒已確認').evaluate().isNotEmpty) break;
    }
    expect(find.textContaining('系統待發提醒已確認'), findsOneWidget);
    final reopened = await OfferStore.load();
    expect(reopened.allOffers.length, before + 1);
    final offer = reopened.allOffers.singleWhere(
      (offer) => offer.name == 'Coffee Coupon',
    );
    expect(offer.note, '20% OFF');
    expect(offer.expiresAt, DateTime(2035, 9, 30));
    await reminders.sync(reopened.activeOffers);
    expect(await reminders.hasPendingReminder(offer.id), isTrue);
    final records = await CaptureRecords.read();
    expect(records.last['success'], isTrue);
    expect(records.last['reminder'], 'pending_verified');
    debugPrint('CLOVER_DEVICE_EVIDENCE ${jsonEncode({
      'fixture': 'synthetic raster; no real-user data',
      'ocr': 'Android ML Kit local',
      'saved': offer.toJson(),
      'reloadedCount': reopened.allOffers.length,
      'pendingAfterReloadSync': true,
      'captureRecord': records.last,
      'notificationDelivery': 'Founder device confirmation pending',
    })}');
  });
}

class DeviceCaptureService extends LocalCouponImportService {
  DeviceCaptureService(this.path);
  final String path;
  @override
  Future<String?> pickImage() async => path;
}
