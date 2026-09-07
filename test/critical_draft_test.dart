import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/import/coupon_import_models.dart';
import 'package:project_clover/import/critical_draft.dart';
import 'package:project_clover/import/critical_draft_screen.dart';
import 'package:project_clover/import/local_import_service.dart';
import 'package:project_clover/models/offer.dart';
import 'package:project_clover/models/offer_storage.dart';
import 'package:project_clover/models/offer_store.dart';
import 'package:project_clover/offer_reminder_service.dart';

OcrPageResult page(List<String> lines) => OcrPageResult(
  sourceType: ImportSourceType.image,
  pageNumber: null,
  text: lines.join('\n'),
  lines: lines,
  succeeded: true,
  duration: Duration.zero,
);

void main() {
  test('single benefit drafts only supported critical fields', () {
    final draft = CriticalDraft.fromPage(
      page(['外送優惠券', '有效期限 2035-09-30', '折抵100元']),
    );
    expect(draft.name.value, '外送優惠券');
    expect(draft.expiration.value, DateTime(2035, 9, 30));
    expect(draft.expiration.confidence, FieldConfidence.high);
    expect(draft.value.value, '折抵100元');
  });

  test(
    'unknown years prices item labels and legal text do not become facts',
    () {
      final draft = CriticalDraft.fromPage(
        page([
          'ITEM 12345',
          '340gx3入/組',
          '商品實際品號以賣場陳列或官網為準。',
          '有效期限 9/30',
          r'$299',
        ]),
      );
      expect(draft.name.value, isNull);
      expect(draft.name.candidates, isEmpty);
      expect(draft.value.value, isNull);
      expect(draft.expiration.value, isNull);
    },
  );

  test(
    'multiple benefits require selection rather than cross-product auto merge',
    () {
      final draft = CriticalDraft.fromPage(
        page([
          '咖啡優惠券',
          '飲料優惠券',
          '有效期限2035/9/30',
          '有效期限2035/10/31',
          '買一送一',
          '20% OFF',
        ]),
      );
      expect(draft.name.value, isNull);
      expect(draft.value.value, isNull);
      expect(draft.expiration.value, isNull);
      expect(draft.name.candidates, hasLength(2));
      expect(draft.value.candidates, hasLength(2));
    },
  );

  test('manufacture dates are not expiration dates', () {
    final draft = CriticalDraft.fromPage(
      page(['咖啡優惠券', '製造日期2035/9/1', '有效期限2035/9/30', '買一送一']),
    );
    expect(draft.expiration.value, DateTime(2035, 9, 30));
  });

  test('same-day reminder persists without moving on later app launches', () {
    final now = DateTime(2035, 9, 30, 15, 30);
    final time = criticalDraftReminderTime(now, now);
    final offer = Offer(
      id: 'today',
      name: '當日優惠',
      expiresAt: now,
      reminderDaysBefore: 0,
      reminderHour: time.hour,
      reminderMinute: time.minute,
    );
    final reopened = Offer.fromJson(
      jsonDecode(jsonEncode(offer.toJson())) as Map<String, dynamic>,
    );
    expect(reopened.effectiveReminderAt, DateTime(2035, 9, 30, 15, 32));
    expect(
      shouldScheduleOfferReminder(
        reopened,
        scheduledDate: reopened.effectiveReminderAt,
        now: now.add(const Duration(minutes: 3)),
      ),
      isFalse,
    );
    expect(
      criticalDraftReminderTime(DateTime(2035, 10, 2), now),
      DateTime(2035, 10, 1, 9),
    );
  });

  Future<void> open(
    WidgetTester tester,
    OfferStore store,
    TestReminders reminders,
    List<Map<String, dynamic>> records, {
    bool failure = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CriticalDraftScreen(
          path: '/fixture/coupon.png',
          service: DraftImportService(failure: failure),
          store: store,
          reminders: reminders,
          recordAttempt: (record) async {
            records.add(record);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('save-critical-draft')));
    await tester.tap(find.byKey(const Key('save-critical-draft')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'draft save persists serialized offer and verifies scheduler state',
    (tester) async {
      final storage = SerializedStorage();
      final store = OfferStore(initialOffers: [], storage: storage);
      final reminders = TestReminders();
      final records = <Map<String, dynamic>>[];
      await open(tester, store, reminders, records);
      expect(find.textContaining('High'), findsOneWidget);
      expect(find.textContaining('Needs Confirmation'), findsNothing);
      await save(tester);
      final reopened = await OfferStore.load(storage: storage);
      expect(reopened.allOffers.single.name, '外送優惠券');
      expect(reopened.allOffers.single.note, '折抵100元');
      expect(reopened.allOffers.single.source, isEmpty);
      expect(reminders.pending, contains(reopened.allOffers.single.id));
      expect(find.textContaining('系統待發提醒已確認'), findsOneWidget);
      expect(records.single['actions'], 1);
      expect(records.single['freeFormTyping'], false);
      expect(records.single['draftAccuracy'], {
        'name': null,
        'expiration': null,
        'value': null,
      });
    },
  );

  testWidgets('denied notifications preserve benefit; retry never duplicates', (
    tester,
  ) async {
    final store = OfferStore(initialOffers: [], storage: SerializedStorage());
    final reminders = TestReminders()..allowed = false;
    final records = <Map<String, dynamic>>[];
    await open(tester, store, reminders, records);
    await save(tester);
    expect(store.allOffers, hasLength(1));
    expect(reminders.pending, isEmpty);
    expect(find.textContaining('請允許通知'), findsOneWidget);
    reminders.allowed = true;
    await tester.tap(find.text('重新確認提醒'));
    await tester.pumpAndSettle();
    expect(store.allOffers, hasLength(1));
    expect(reminders.pending, hasLength(1));
  });

  testWidgets('failed storage does not schedule or report capture success', (
    tester,
  ) async {
    final store = OfferStore(
      initialOffers: [],
      storage: SerializedStorage()..fail = true,
    );
    final reminders = TestReminders();
    final records = <Map<String, dynamic>>[];
    await open(tester, store, reminders, records);
    await save(tester);
    expect(store.allOffers, isEmpty);
    expect(reminders.pending, isEmpty);
    expect(records, isEmpty);
    expect(find.textContaining('儲存失敗'), findsOneWidget);
  });

  testWidgets('OCR failure offers correction without fabricated defaults', (
    tester,
  ) async {
    final store = OfferStore(initialOffers: []);
    await open(tester, store, TestReminders(), [], failure: true);
    expect(find.text('選擇到期日'), findsOneWidget);
    await save(tester);
    expect(store.allOffers, isEmpty);
    expect(find.text('請確認名稱、到期日與優惠內容。'), findsOneWidget);
  });
}

class SerializedStorage implements OfferStorage {
  String? raw;
  bool fail = false;
  @override
  Future<List<Offer>?> loadOffers() async => raw == null
      ? null
      : (jsonDecode(raw!) as List)
            .map((value) => Offer.fromJson(value as Map<String, dynamic>))
            .toList();
  @override
  Future<void> saveOffers(List<Offer> offers) async {
    if (fail) throw StateError('simulated disk failure');
    raw = jsonEncode(offers.map((offer) => offer.toJson()).toList());
  }
}

class TestReminders implements OfferReminderScheduler, OfferReminderInspector {
  final pending = <String>{};
  bool allowed = true;
  @override
  String? get initialOfferId => null;
  @override
  Future<bool> requestPermission() async => allowed;
  @override
  Future<NotificationPermissionState> permissionState() async => allowed
      ? NotificationPermissionState.granted
      : NotificationPermissionState.denied;
  @override
  Future<void> sync(Iterable<Offer> offers) async {
    pending.addAll(offers.map((offer) => offer.id));
  }

  @override
  Future<void> cancel(String offerId) async {
    pending.remove(offerId);
  }

  @override
  Future<bool> hasPendingReminder(String offerId) async =>
      pending.contains(offerId);
}

class DraftImportService implements CouponImportService {
  DraftImportService({this.failure = false});
  final bool failure;
  @override
  Future<String?> pickImage() async => '/fixture/coupon.png';
  @override
  Future<String?> pickPdf() async => null;
  @override
  Future<OcrPageResult> recognizeImage(String path) async {
    if (failure) throw StateError('OCR unavailable');
    return page(['外送優惠券', '有效期限2035/09/30', '折抵100元']);
  }

  @override
  Future<List<OcrPageResult>> recognizePdf(
    String path, {
    required void Function(ImportProgress progress) onProgress,
    required bool Function() isCancelled,
  }) => throw UnimplementedError();
}
