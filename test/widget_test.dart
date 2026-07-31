import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/main.dart';
import 'package:project_clover/models/offer_store.dart';

void main() {
  testWidgets('founder can open the add-offer flow', (tester) async {
    await tester.pumpWidget(CloverApp(store: OfferStore(initialOffers: [])));

    expect(find.text('今天值得使用'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-offer-button')));
    await tester.pumpAndSettle();

    expect(find.text('新增優惠'), findsWidgets);
    expect(find.byKey(const Key('offer-name-field')), findsOneWidget);
    expect(find.byKey(const Key('expiry-date-field')), findsOneWidget);
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
