import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/main.dart';
import 'package:project_clover/models/offer.dart';
import 'package:project_clover/models/offer_store.dart';

void main() {
  testWidgets('founder can open the add-offer flow', (tester) async {
    await tester.pumpWidget(CloverApp(store: OfferStore(initialOffers: [])));

    expect(find.text('今天值得使用'), findsOneWidget);
    expect(find.byKey(const Key('app-info-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-offer-button')));
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

  testWidgets('notification launch opens the matching offer details', (tester) async {
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

    await tester.tap(find.text('編輯前名稱'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-offer-button')));
    await tester.pumpAndSettle();

    expect(find.text('編輯優惠'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('offer-name-field')),
      '編輯後名稱',
    );
    await tester.tap(find.byKey(const Key('save-offer-button')));
    await tester.pumpAndSettle();

    expect(store.activeOffers.single.name, '編輯後名稱');
  });

  testWidgets('deleting an offer requires confirmation', (tester) async {
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'delete-offer',
          name: '刪除測試',
          expiresAt: DateTime.now().add(const Duration(days: 10)),
        ),
      ],
    );
    await tester.pumpWidget(CloverApp(store: store));

    await tester.tap(find.text('刪除測試'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-offer-button')));
    await tester.pumpAndSettle();

    expect(find.text('刪除這張優惠？'), findsOneWidget);
    expect(store.activeOffers, hasLength(1));

    await tester.tap(find.byKey(const Key('confirm-delete-offer-button')));
    await tester.pumpAndSettle();

    expect(store.activeOffers, isEmpty);
    expect(find.text('優惠已刪除'), findsOneWidget);
  });

  testWidgets('offer can be marked completed', (tester) async {
    final store = OfferStore();
    await tester.pumpWidget(CloverApp(store: store));

    await tester.tap(find.text('超商大杯拿鐵兌換券'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('complete-offer-button')));
    await tester.pumpAndSettle();

    expect(store.completedOffers.map((offer) => offer.id), contains('coffee'));
    expect(find.text('已標記完成，成功保住這份價值！'), findsOneWidget);
  });
}
