import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/beta_support.dart';
import 'package:project_clover/import/coupon_import_models.dart';
import 'package:project_clover/import/import_screens.dart';
import 'package:project_clover/import/local_import_service.dart';
import 'package:project_clover/main.dart';
import 'package:project_clover/models/offer.dart';
import 'package:project_clover/models/offer_backup.dart';
import 'package:project_clover/models/offer_store.dart';
import 'package:project_clover/offer_backup_file_service.dart';
import 'package:project_clover/offer_reminder_service.dart';

void main() {
  testWidgets('founder can open the add-offer flow', (tester) async {
    await tester.pumpWidget(CloverApp(store: OfferStore(initialOffers: [])));

    expect(find.text('今天值得使用'), findsOneWidget);
    expect(find.byKey(const Key('app-info-button')), findsOneWidget);
    expect(find.byKey(const Key('backup-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-offer-button')));
    await tester.pumpAndSettle();

    expect(find.text('手動輸入'), findsOneWidget);
    expect(find.text('匯入圖片'), findsOneWidget);
    expect(find.text('匯入 PDF'), findsOneWidget);
    await tester.tap(find.byKey(const Key('manual-entry-choice')));
    await tester.pumpAndSettle();

    expect(find.text('新增優惠'), findsWidgets);
    expect(find.byKey(const Key('offer-name-field')), findsOneWidget);
    expect(find.byKey(const Key('expiry-date-field')), findsOneWidget);
    expect(find.byKey(const Key('reminder-switch')), findsOneWidget);
    expect(find.byKey(const Key('reminder-days-field')), findsOneWidget);
    expect(find.byKey(const Key('reminder-time-field')), findsOneWidget);
    expect(find.text('到期提醒'), findsOneWidget);
    expect(find.text('1 天前'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
  });

  testWidgets('notification launch opens the matching offer details', (
    tester,
  ) async {
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'notification-offer',
          name: '通知點擊測試',
          expiresAt: DateTime(2026, 8, 10),
        ),
      ],
    );
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      CloverApp(
        store: store,
        navigatorKey: navigatorKey,
        initialOfferId: 'notification-offer',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('優惠詳情'), findsOneWidget);
    expect(find.text('通知點擊測試'), findsOneWidget);
  });

  testWidgets('canceling image picker leaves data unchanged', (tester) async {
    final store = OfferStore(initialOffers: []);
    await tester.pumpWidget(
      CloverApp(store: store, importService: CancelledImportService()),
    );

    await tester.tap(find.byKey(const Key('add-offer-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('image-import-choice')));
    await tester.pumpAndSettle();

    expect(store.allOffers, isEmpty);
    expect(find.text('今天值得使用'), findsOneWidget);
  });

  testWidgets('standard image import never asks for cloud processing', (
    tester,
  ) async {
    final service = ConsentImportService();
    await tester.pumpWidget(
      MaterialApp(
        home: ImageImportScreen(
          path: '/fixture/promo.png',
          service: service,
          store: OfferStore(initialOffers: []),
          reminders: RecordingReminderScheduler(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI 智慧辨識'), findsNothing);
    expect(service.analyzeCalls, 1);
    expect(service.lastAllowCloudProcessing, isFalse);
    expect(find.text('選擇要匯入的優惠'), findsOneWidget);
  });

  testWidgets('structured cloud products survive failed local OCR evidence', (
    tester,
  ) async {
    const cloudEvidence = FieldEvidence(
      sourceType: ImportSourceType.image,
      extractionMethod: ImportExtractionMethod.cloudVision,
      sourcePage: null,
      regionId: 'card-1',
      rawText: '全聯福利中心 測試牛乳 119元 2026/08/31',
      confidence: 0.98,
    );
    final service = ConsentImportService(
      localOcrSucceeded: false,
      products: [
        ReconstructedProduct(
          regionId: 'card-1',
          sourceType: ImportSourceType.image,
          sourcePage: null,
          merchant: const EvidencedValue(
            value: '全聯福利中心',
            evidence: cloudEvidence,
          ),
          productName: const EvidencedValue(
            value: '測試牛乳',
            evidence: cloudEvidence,
          ),
          promotionalPrice: const EvidencedValue(
            value: 119,
            evidence: cloudEvidence,
          ),
          validUntil: EvidencedValue(
            value: DateTime(2026, 8, 31),
            evidence: cloudEvidence,
          ),
          regionEvidence: cloudEvidence,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ImageImportScreen(
          path: '/fixture/promo.png',
          service: service,
          store: OfferStore(initialOffers: []),
          reminders: RecordingReminderScheduler(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('選擇要匯入的優惠'), findsOneWidget);
    expect(find.text('測試牛乳'), findsOneWidget);
    expect(service.lastAllowCloudProcessing, isFalse);
  });

  testWidgets('one tap recovers a missed product without text entry', (
    tester,
  ) async {
    const recoveredEvidence = FieldEvidence(
      sourceType: ImportSourceType.image,
      extractionMethod: ImportExtractionMethod.localOcr,
      sourcePage: null,
      regionId: 'recovery-card',
      rawText: '光泉鮮乳 39元',
      confidence: 0.9,
      bounds: OcrRegionBounds(left: 0, top: 0, right: 0.5, bottom: 0.5),
    );
    final service = ConsentImportService(
      recoveredProducts: [
        ReconstructedProduct(
          regionId: 'recovery-card',
          sourceType: ImportSourceType.image,
          sourcePage: null,
          merchant: const EvidencedValue(
            value: '全家便利商店',
            evidence: recoveredEvidence,
          ),
          productName: const EvidencedValue(
            value: '光泉鮮乳',
            evidence: recoveredEvidence,
          ),
          promotionalPrice: const EvidencedValue(
            value: 39,
            evidence: recoveredEvidence,
          ),
          validUntil: EvidencedValue(
            value: DateTime(2026, 8, 31),
            evidence: recoveredEvidence,
          ),
          regionEvidence: recoveredEvidence,
        ),
      ],
    );
    final image = File(
      '${Directory.systemTemp.path}/clover-widget-recovery.png',
    );
    image.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
    addTearDown(() async {
      if (await image.exists()) await image.delete();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ImageImportScreen(
          path: image.path,
          service: service,
          store: OfferStore(initialOffers: []),
          reminders: RecordingReminderScheduler(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recover-missing-product')));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('missing-product-image'))),
    );
    await tester.pumpAndSettle();

    expect(service.recoveryCalls, 1);
    expect(find.text('光泉鮮乳'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('scanned PDF asks consent before every cloud page request', (
    tester,
  ) async {
    const evidence = FieldEvidence(
      sourceType: ImportSourceType.pdf,
      extractionMethod: ImportExtractionMethod.cloudVision,
      sourcePage: 1,
      regionId: 'p1-card1',
      rawText: '測試鮮乳 89元',
      confidence: 0.98,
    );
    final service = ConsentImportService(
      products: const [
        ReconstructedProduct(
          regionId: 'p1-card1',
          sourceType: ImportSourceType.pdf,
          sourcePage: 1,
          productName: EvidencedValue(value: '測試鮮乳', evidence: evidence),
          promotionalPrice: EvidencedValue(value: 89, evidence: evidence),
          regionEvidence: evidence,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PdfImportScreen(
          path: '/fixture/scanned.pdf',
          service: service,
          store: OfferStore(initialOffers: []),
          reminders: RecordingReminderScheduler(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('第 1 頁'), findsOneWidget);
    await tester.tap(find.byKey(const Key('accept-cloud-processing')));
    await tester.pumpAndSettle();
    expect(find.textContaining('第 2 頁'), findsOneWidget);
    await tester.tap(find.byKey(const Key('decline-cloud-processing')));
    await tester.pumpAndSettle();

    expect(service.pdfPageConsents, [true, false]);
  });

  testWidgets('confirmed candidate creates exactly one coupon', (tester) async {
    final store = OfferStore(initialOffers: []);
    final reminders = RecordingReminderScheduler();
    final candidate = CouponCandidate(
      id: 'candidate',
      title: '匯入咖啡券',
      merchant: '測試咖啡',
      expirationDate: DateTime.now().add(const Duration(days: 30)),
      rawText: '匯入咖啡券',
      sourcePage: null,
      category: OfferCategory.coffee,
      confidence: ImportConfidence.high,
      promotionConditions: const ['買一送一'],
      attentionFields: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'TW'),
        home: Scaffold(
          body: CandidateEditor(
            candidate: candidate,
            store: store,
            reminders: reminders,
          ),
        ),
      ),
    );

    final button = find.byKey(const Key('confirm-import-coupon'));
    await tester.scrollUntilVisible(
      button,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(store.allOffers, hasLength(1));
    expect(store.allOffers.single.name, '匯入咖啡券');
    expect(reminders.syncCount, 1);
  });

  testWidgets('Needs Review candidates are first red and not preselected', (
    tester,
  ) async {
    final store = OfferStore(initialOffers: []);
    final reminders = RecordingReminderScheduler();
    final expiry = DateTime.now().add(const Duration(days: 30));
    final ready = CouponCandidate(
      id: 'ready',
      title: '資料完整商品',
      merchant: '測試商店',
      expirationDate: expiry,
      rawText: '資料完整商品',
      sourcePage: 1,
      category: OfferCategory.foodAndDrink,
      confidence: ImportConfidence.high,
      state: CandidateState.ready,
      attentionFields: const [],
    );
    final review = CouponCandidate(
      id: 'review',
      title: '名稱可能不完整',
      merchant: '測試商店',
      expirationDate: expiry,
      rawText: '名稱可能不完整',
      sourcePage: 1,
      category: OfferCategory.others,
      confidence: ImportConfidence.medium,
      state: CandidateState.needsReview,
      attentionFields: const ['商品名稱不完整'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BatchReviewScreen(
          candidates: [ready, review],
          failedPages: 0,
          store: store,
          reminders: reminders,
        ),
      ),
    );

    expect(find.text('已選擇 1 筆，其中 0 筆需要確認'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('名稱可能不完整')).dy,
      lessThan(tester.getTopLeft(find.text('資料完整商品')).dy),
    );
    final reviewText = tester.widget<Text>(find.text('商品名稱不完整'));
    expect(reviewText.style?.color, isNotNull);
    expect(store.allOffers, isEmpty);
    expect(reminders.syncCount, 0);
  });

  testWidgets('excluded fragments stay hidden but can be inspected', (
    tester,
  ) async {
    final store = OfferStore(initialOffers: []);
    final reminders = RecordingReminderScheduler();
    final ready = CouponCandidate(
      id: 'direct',
      title: '可直接匯入商品',
      merchant: 'Costco 好市多',
      promotionalPrice: 299,
      expirationDate: DateTime.now().add(const Duration(days: 30)),
      rawText: '可直接匯入商品',
      sourcePage: 1,
      category: OfferCategory.foodAndDrink,
      confidence: ImportConfidence.high,
      attentionFields: const [],
    );
    const excluded = CouponCandidate(
      id: 'excluded',
      title: '',
      merchant: '',
      rawText: '商品實際包裝以賣場陳列為準',
      sourcePage: 1,
      category: OfferCategory.others,
      confidence: ImportConfidence.high,
      state: CandidateState.rejected,
      selected: false,
      attentionFields: ['非商品內容'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BatchReviewScreen(
          candidates: [ready],
          excludedCandidates: const [excluded],
          failedPages: 0,
          store: store,
          reminders: reminders,
        ),
      ),
    );

    expect(find.text('商品實際包裝以賣場陳列為準'), findsNothing);
    await tester.tap(find.text('查看已排除 1 筆'));
    await tester.pumpAndSettle();
    expect(find.text('商品實際包裝以賣場陳列為準'), findsOneWidget);
    expect(store.allOffers, isEmpty);
  });

  testWidgets(
    'selected unresolved candidate opens focused review before save',
    (tester) async {
      final store = OfferStore(initialOffers: []);
      final reminders = RecordingReminderScheduler();
      const candidate = CouponCandidate(
        id: 'review-flow',
        title: '待確認商品',
        merchant: '',
        expirationDate: null,
        rawText: '待確認商品',
        sourcePage: 1,
        category: OfferCategory.others,
        confidence: ImportConfidence.low,
        state: CandidateState.needsReview,
        attentionFields: const ['缺少商家／來源', '缺少到期日'],
        selected: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BatchReviewScreen(
            candidates: [candidate],
            failedPages: 0,
            store: store,
            reminders: reminders,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('batch-import-button')));
      await tester.pumpAndSettle();

      expect(find.text('編輯候選優惠'), findsOneWidget);
      expect(find.byKey(const Key('import-merchant-field')), findsOneWidget);
      expect(find.byKey(const Key('import-expiry-field')), findsOneWidget);
      expect(store.allOffers, isEmpty);
      expect(reminders.syncCount, 0);
    },
  );

  testWidgets('active offer can be edited', (tester) async {
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'edit-offer',
          name: '編輯前名稱',
          expiresAt: DateTime.now().add(const Duration(days: 10)),
        ),
      ],
    );
    await tester.pumpWidget(CloverApp(store: store));

    await tester.tap(find.text('優惠清單'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編輯前名稱'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-offer-button')));
    await tester.pumpAndSettle();

    expect(find.text('編輯優惠'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('offer-name-field')), '編輯後名稱');
    final saveButton = find.byKey(const Key('save-offer-button'));
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(store.activeOffers.single.name, '編輯後名稱');
  });

  testWidgets('deleting an offer requires confirmation', (tester) async {
    final reminders = RecordingReminderScheduler();
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'delete-offer',
          name: '刪除測試',
          expiresAt: DateTime.now().add(const Duration(days: 10)),
        ),
      ],
    );
    await tester.pumpWidget(CloverApp(store: store, reminders: reminders));

    await tester.tap(find.text('優惠清單'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除測試'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-offer-button')));
    await tester.pumpAndSettle();

    expect(find.text('刪除這張優惠？'), findsOneWidget);
    expect(store.activeOffers, hasLength(1));

    await tester.tap(find.byKey(const Key('confirm-delete-offer-button')));
    await tester.pumpAndSettle();

    expect(store.activeOffers, isEmpty);
    expect(reminders.cancelledOfferIds, ['delete-offer']);
    expect(find.text('優惠已刪除'), findsOneWidget);
  });

  testWidgets('offer can be marked completed', (tester) async {
    final reminders = RecordingReminderScheduler();
    final store = OfferStore();
    await tester.pumpWidget(CloverApp(store: store, reminders: reminders));

    await tester.tap(find.text('優惠清單'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('超商大杯拿鐵兌換券'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('complete-offer-button')));
    await tester.pumpAndSettle();

    expect(store.completedOffers.map((offer) => offer.id), contains('coffee'));
    expect(store.completedOffers.first.completedAt, isNotNull);
    expect(reminders.cancelledOfferIds, ['coffee']);
    expect(find.text('已標記完成，成功保住這份價值！'), findsOneWidget);
  });

  testWidgets('completed offer can be restored to active', (tester) async {
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'restore-offer',
          name: '恢復測試',
          expiresAt: DateTime.now().add(const Duration(days: 10)),
          status: OfferStatus.completed,
          completedAt: DateTime.now(),
        ),
      ],
    );
    await tester.pumpWidget(CloverApp(store: store));

    await tester.tap(find.text('優惠清單'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢復測試'));
    await tester.pumpAndSettle();

    expect(find.text('完成時間'), findsOneWidget);
    expect(find.byKey(const Key('restore-offer-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('restore-offer-button')));
    await tester.pumpAndSettle();

    expect(store.completedOffers, isEmpty);
    expect(store.activeOffers.single.id, 'restore-offer');
    expect(find.text('已恢復為待使用優惠'), findsOneWidget);
  });

  testWidgets('founder can export a local backup', (tester) async {
    final backupFiles = FakeBackupFileService();
    final store = OfferStore(
      initialOffers: [
        Offer(id: 'exported', name: '要備份的優惠', expiresAt: DateTime(2026, 9, 1)),
      ],
    );
    await tester.pumpWidget(CloverApp(store: store, backupFiles: backupFiles));

    await tester.tap(find.byKey(const Key('backup-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-backup-button')));
    await tester.pumpAndSettle();

    final exported = OfferBackupCodec.decode(backupFiles.exportedContent!);
    expect(exported.offers.single.id, 'exported');
    expect(backupFiles.exportedName, startsWith('project-clover-backup-'));
    expect(find.text('已備份 1 筆優惠'), findsOneWidget);
  });

  testWidgets('restoring backup requires confirmation and replaces data', (
    tester,
  ) async {
    final backupFiles = FakeBackupFileService(
      importedFile: OfferBackupFile(
        name: 'project-clover-backup.json',
        content: OfferBackupCodec.encode([
          Offer(
            id: 'from-backup',
            name: '備份內優惠',
            expiresAt: DateTime(2026, 9, 1),
          ),
        ], exportedAt: DateTime(2026, 8, 1, 20, 30)),
      ),
    );
    final store = OfferStore(
      initialOffers: [
        Offer(id: 'on-phone', name: '手機原優惠', expiresAt: DateTime(2026, 8, 10)),
      ],
    );
    await tester.pumpWidget(CloverApp(store: store, backupFiles: backupFiles));

    await tester.tap(find.byKey(const Key('backup-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import-backup-button')));
    await tester.pumpAndSettle();

    expect(find.text('還原這份備份？'), findsOneWidget);
    expect(find.textContaining('待使用 1 筆、已完成 0 筆'), findsOneWidget);
    expect(store.allOffers.single.id, 'on-phone');

    await tester.tap(find.byKey(const Key('confirm-import-backup-button')));
    await tester.pumpAndSettle();

    expect(store.allOffers.single.id, 'from-backup');
    expect(find.text('已還原 1 筆優惠'), findsOneWidget);
  });

  testWidgets('coupon search updates results immediately and can be cleared', (
    tester,
  ) async {
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'coffee',
          name: 'Coffee Coupon',
          source: 'STARBUCKS',
          expiresAt: DateTime.now().add(const Duration(days: 10)),
        ),
        Offer(
          id: 'movie',
          name: '電影票',
          note: '週末約會',
          expiresAt: DateTime.now().add(const Duration(days: 20)),
        ),
      ],
    );
    await tester.pumpWidget(CloverApp(store: store));
    await tester.tap(find.text('優惠清單'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('offer-search-field')),
      'starbucks',
    );
    await tester.pump();

    expect(find.text('Coffee Coupon'), findsOneWidget);
    expect(find.text('電影票'), findsNothing);
    expect(find.text('找到 1 張優惠'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear-search-button')));
    await tester.pump();

    expect(find.text('Coffee Coupon'), findsOneWidget);
    expect(find.text('電影票'), findsOneWidget);
    expect(find.text('找到 2 張優惠'), findsOneWidget);
  });

  testWidgets('dashboard updates automatically after coupon status changes', (
    tester,
  ) async {
    final now = DateTime.now();
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'today',
          name: '今天使用',
          expiresAt: DateTime(now.year, now.month, now.day),
        ),
      ],
    );
    await tester.pumpWidget(CloverApp(store: store));

    expect(
      find.descendant(
        of: find.byKey(const Key('dashboard-today')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await store.markCompleted('today');
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('dashboard-today')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('dashboard-completed')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'beta support opens feedback and exports diagnostic information',
    (tester) async {
      final provider = FakeDiagnosticInfoProvider();
      final feedback = FakeFeedbackLauncher();
      final exporter = FakeDiagnosticExportService();
      await tester.pumpWidget(
        CloverApp(
          store: OfferStore(initialOffers: []),
          diagnosticInfoProvider: provider,
          feedbackLauncher: feedback,
          diagnosticExportService: exporter,
        ),
      );

      await tester.tap(find.byKey(const Key('settings-button')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -650));
      await tester.pumpAndSettle();
      final sendFeedback = find.byKey(const Key('send-feedback-button'));
      await tester.ensureVisible(sendFeedback);
      await tester.tap(sendFeedback);
      await tester.pumpAndSettle();

      expect(feedback.openedInfo, same(provider.info));
      expect(provider.collectCount, 1);

      final exportDiagnostic = find.byKey(
        const Key('export-diagnostic-button'),
      );
      await tester.ensureVisible(exportDiagnostic);
      await tester.tap(exportDiagnostic);
      await tester.pumpAndSettle();

      expect(exporter.exportedInfo, same(provider.info));
      expect(provider.collectCount, 2);
      expect(find.text('診斷資訊已匯出'), findsOneWidget);
    },
  );

  testWidgets('expired cleanup requires confirmation before deleting', (
    tester,
  ) async {
    final reminders = RecordingReminderScheduler();
    final now = DateTime.now();
    final oldOffer = Offer(
      id: 'old-expired',
      name: '很久以前的優惠',
      expiresAt: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 31)),
    );
    final store = OfferStore(initialOffers: [oldOffer]);
    await tester.pumpWidget(CloverApp(store: store, reminders: reminders));

    await tester.tap(find.byKey(const Key('settings-button')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    final cleanupButton = find.byKey(const Key('expired-cleanup-button'));
    await tester.ensureVisible(cleanupButton);
    await tester.tap(cleanupButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cleanup-olderThan30Days')));
    await tester.pumpAndSettle();

    expect(find.text('刪除 1 張過期優惠？'), findsOneWidget);
    expect(store.allOffers, hasLength(1));

    await tester.tap(find.byKey(const Key('confirm-expired-cleanup-button')));
    await tester.pumpAndSettle();

    expect(store.allOffers, isEmpty);
    expect(reminders.syncedOfferIds, isEmpty);
    expect(reminders.syncCount, 1);
    expect(find.text('已刪除 1 張過期優惠'), findsOneWidget);
  });
}

class RecordingReminderScheduler implements OfferReminderScheduler {
  final List<String> cancelledOfferIds = [];
  List<String> syncedOfferIds = [];
  int syncCount = 0;

  @override
  String? get initialOfferId => null;

  @override
  Future<void> cancel(String offerId) async {
    cancelledOfferIds.add(offerId);
  }

  @override
  Future<NotificationPermissionState> permissionState() async =>
      NotificationPermissionState.granted;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> sync(Iterable<Offer> activeOffers) async {
    syncCount++;
    syncedOfferIds = activeOffers.map((offer) => offer.id).toList();
  }
}

class FakeBackupFileService implements OfferBackupFileService {
  FakeBackupFileService({this.importedFile});

  final OfferBackupFile? importedFile;
  String? exportedName;
  String? exportedContent;

  @override
  Future<OfferBackupFile?> pickBackup() async => importedFile;

  @override
  Future<bool> saveBackup({
    required String fileName,
    required String content,
  }) async {
    exportedName = fileName;
    exportedContent = content;
    return true;
  }
}

class FakeDiagnosticInfoProvider implements DiagnosticInfoProvider {
  final DiagnosticInfo info = const DiagnosticInfo(
    appVersion: '0.12.0',
    buildNumber: '12',
    androidVersion: '16 (SDK 36)',
    deviceInformation: 'Test Phone',
    notificationPermission: NotificationPermissionState.granted,
  );
  int collectCount = 0;

  @override
  Future<DiagnosticInfo> collect(OfferReminderScheduler reminders) async {
    collectCount++;
    return info;
  }
}

class FakeFeedbackLauncher implements FeedbackLauncher {
  DiagnosticInfo? openedInfo;

  @override
  Future<bool> open(DiagnosticInfo info) async {
    openedInfo = info;
    return true;
  }
}

class FakeDiagnosticExportService implements DiagnosticExportService {
  DiagnosticInfo? exportedInfo;

  @override
  Future<bool> export(DiagnosticInfo info) async {
    exportedInfo = info;
    return true;
  }
}

class CancelledImportService implements CouponImportService {
  @override
  Future<String?> pickImage() async => null;

  @override
  Future<String?> pickPdf() async => null;

  @override
  Future<OcrPageResult> recognizeImage(String path) =>
      throw UnimplementedError();

  @override
  Future<List<OcrPageResult>> recognizePdf(
    String path, {
    required void Function(ImportProgress progress) onProgress,
    required bool Function() isCancelled,
  }) => throw UnimplementedError();
}

class ConsentImportService
    implements CouponImportService, SourceAdaptiveCouponImportService {
  ConsentImportService({
    this.products = const [],
    this.recoveredProducts = const [],
    this.localOcrSucceeded = true,
  });

  final List<ReconstructedProduct> products;
  final List<ReconstructedProduct> recoveredProducts;
  final bool localOcrSucceeded;
  int analyzeCalls = 0;
  int recoveryCalls = 0;
  bool? lastAllowCloudProcessing;
  final List<bool> pdfPageConsents = [];

  @override
  bool get cloudVisionAvailable => true;

  @override
  String get cloudVisionDisclosure => '測試供應商；資料不作訓練，最多保留 30 天後刪除。';

  @override
  Future<SourceAdaptiveImportResult> analyzeImage(
    String path, {
    required bool allowCloudProcessing,
  }) async {
    analyzeCalls++;
    lastAllowCloudProcessing = allowCloudProcessing;
    return SourceAdaptiveImportResult(
      route: ImportRoute.promotionalImage,
      pages: [
        OcrPageResult(
          sourceType: ImportSourceType.image,
          pageNumber: null,
          text: '',
          lines: [],
          succeeded: localOcrSucceeded,
          duration: Duration.zero,
        ),
      ],
      products: products,
      cloudUsage: allowCloudProcessing
          ? const CloudProcessingUsage(requestCount: 1)
          : const CloudProcessingUsage(),
      cloudWasDeclined: false,
      localFallbackUsed: false,
    );
  }

  @override
  Future<SourceAdaptiveImportResult> analyzePdf(
    String path, {
    required bool allowCloudProcessing,
    Future<bool> Function(int pageNumber)? requestCloudPageConsent,
    required void Function(ImportProgress progress) onProgress,
    required bool Function() isCancelled,
  }) async {
    for (final page in const [1, 2]) {
      pdfPageConsents.add(
        allowCloudProcessing &&
            (await requestCloudPageConsent?.call(page) ?? false),
      );
    }
    return SourceAdaptiveImportResult(
      route: ImportRoute.scannedPdf,
      pages: const [],
      products: products,
      cloudUsage: CloudProcessingUsage(
        requestCount: pdfPageConsents.where((value) => value).length,
      ),
      cloudWasDeclined: pdfPageConsents.any((value) => !value),
      localFallbackUsed: pdfPageConsents.any((value) => !value),
    );
  }

  @override
  Future<SourceAdaptiveImportResult> recoverImageRegion(
    String path, {
    required double normalizedX,
    required double normalizedY,
  }) async {
    recoveryCalls++;
    return SourceAdaptiveImportResult(
      route: ImportRoute.promotionalImage,
      pages: const [],
      products: recoveredProducts,
      localImageMetrics: const LocalImageProcessingMetrics(
        proposedRegionCount: 1,
        regionOcrCount: 1,
        recoveryActionCount: 1,
      ),
    );
  }

  @override
  Future<PdfSourcePlan> inspectPdf(String path) async => const PdfSourcePlan(
    pageCount: 2,
    nativeTextPages: [],
    visionPages: [1, 2],
  );

  @override
  Future<String?> pickImage() async => null;

  @override
  Future<String?> pickPdf() async => null;

  @override
  Future<OcrPageResult> recognizeImage(String path) =>
      throw UnimplementedError();

  @override
  Future<List<OcrPageResult>> recognizePdf(
    String path, {
    required void Function(ImportProgress progress) onProgress,
    required bool Function() isCancelled,
  }) => throw UnimplementedError();
}
