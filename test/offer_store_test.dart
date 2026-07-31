import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/models/offer.dart';
import 'package:project_clover/models/offer_store.dart';

void main() {
  test('active offers are sorted by expiry date', () {
    final store = OfferStore(
      initialOffers: [
        Offer(id: 'later', name: '較晚', expiresAt: DateTime(2026, 8, 10)),
        Offer(id: 'soon', name: '較早', expiresAt: DateTime(2026, 8, 1)),
      ],
    );

    expect(store.activeOffers.map((offer) => offer.id), ['soon', 'later']);
  });

  test('adding and completing an offer updates each list', () {
    final store = OfferStore(initialOffers: []);
    store.addOffer(name: '測試優惠', expiresAt: DateTime(2026, 8, 1));

    expect(store.activeOffers, hasLength(1));
    final id = store.activeOffers.single.id;

    store.markCompleted(id);

    expect(store.activeOffers, isEmpty);
    expect(store.completedOffers.single.name, '測試優惠');
  });
}
