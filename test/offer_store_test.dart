import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/models/offer.dart';
import 'package:project_clover/models/offer_storage.dart';
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

  test('adding and completing an offer updates each list', () async {
    final store = OfferStore(initialOffers: []);
    await store.addOffer(name: '測試優惠', expiresAt: DateTime(2026, 8, 1));

    expect(store.activeOffers, hasLength(1));
    final id = store.activeOffers.single.id;

    await store.markCompleted(id);

    expect(store.activeOffers, isEmpty);
    expect(store.completedOffers.single.name, '測試優惠');
  });

  test('saved offers survive a new store instance', () async {
    final storage = MemoryOfferStorage();
    final firstStore = OfferStore(initialOffers: [], storage: storage);

    await firstStore.addOffer(
      name: '會保留的優惠',
      expiresAt: DateTime(2026, 12, 31),
      source: '測試來源',
    );
    final savedId = firstStore.activeOffers.single.id;

    final reopenedStore = await OfferStore.load(storage: storage);

    expect(reopenedStore.activeOffers.single.id, savedId);
    expect(reopenedStore.activeOffers.single.name, '會保留的優惠');

    await reopenedStore.markCompleted(savedId);
    final reopenedAgain = await OfferStore.load(storage: storage);

    expect(reopenedAgain.activeOffers, isEmpty);
    expect(reopenedAgain.completedOffers.single.id, savedId);
  });

  test('offer JSON keeps optional fields and completion status', () {
    final original = Offer(
      id: 'json-test',
      name: '序列化測試',
      expiresAt: DateTime(2026, 8, 1),
      source: '來源',
      note: '備註',
      status: OfferStatus.completed,
    );

    final restored = Offer.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.expiresAt, original.expiresAt);
    expect(restored.source, original.source);
    expect(restored.note, original.note);
    expect(restored.status, OfferStatus.completed);
  });
}

class MemoryOfferStorage implements OfferStorage {
  List<Offer>? savedOffers;

  @override
  Future<List<Offer>?> loadOffers() async {
    final saved = savedOffers;
    return saved == null ? null : List<Offer>.from(saved);
  }

  @override
  Future<void> saveOffers(List<Offer> offers) async {
    savedOffers = List<Offer>.from(offers);
  }
}
