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
    expect(store.completedOffers.single.completedAt, isNotNull);
  });

  test('completed offers are sorted by most recent completion time', () {
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'older',
          name: '較早完成',
          expiresAt: DateTime(2026, 8, 10),
          status: OfferStatus.completed,
          completedAt: DateTime(2026, 8, 1, 9),
        ),
        Offer(
          id: 'newer',
          name: '最近完成',
          expiresAt: DateTime(2026, 8, 1),
          status: OfferStatus.completed,
          completedAt: DateTime(2026, 8, 2, 9),
        ),
      ],
    );

    expect(store.completedOffers.map((offer) => offer.id), ['newer', 'older']);
  });

  test('restoring a completed offer persists and clears completion time', () async {
    final storage = MemoryOfferStorage();
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'restore-me',
          name: '誤標完成',
          expiresAt: DateTime(2026, 8, 10),
          status: OfferStatus.completed,
          completedAt: DateTime(2026, 8, 1, 12),
        ),
      ],
      storage: storage,
    );

    await store.restoreOffer('restore-me');
    final reopened = await OfferStore.load(storage: storage);

    expect(reopened.completedOffers, isEmpty);
    expect(reopened.activeOffers.single.id, 'restore-me');
    expect(reopened.activeOffers.single.completedAt, isNull);
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

  test('editing an offer persists all changed fields', () async {
    final storage = MemoryOfferStorage();
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'edit-me',
          name: '原名稱',
          expiresAt: DateTime(2026, 8, 10),
        ),
      ],
      storage: storage,
    );

    await store.updateOffer(
      id: 'edit-me',
      name: '新名稱',
      expiresAt: DateTime(2026, 8, 20),
      source: '新來源',
      note: '新備註',
      reminderDaysBefore: 7,
      reminderHour: 18,
      reminderMinute: 30,
    );
    final reopened = await OfferStore.load(storage: storage);
    final edited = reopened.activeOffers.single;

    expect(edited.name, '新名稱');
    expect(edited.expiresAt, DateTime(2026, 8, 20));
    expect(edited.source, '新來源');
    expect(edited.note, '新備註');
    expect(edited.reminderDaysBefore, 7);
    expect(edited.reminderHour, 18);
    expect(edited.reminderMinute, 30);
  });

  test('deleting an offer persists its removal', () async {
    final storage = MemoryOfferStorage();
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'delete-me',
          name: '要刪除',
          expiresAt: DateTime(2026, 8, 10),
        ),
      ],
      storage: storage,
    );

    await store.deleteOffer('delete-me');
    final reopened = await OfferStore.load(storage: storage);

    expect(store.activeOffers, isEmpty);
    expect(reopened.activeOffers, isEmpty);
  });

  test('legacy custom reminder migrates to nearest preset and keeps time', () {
    final restored = Offer.fromJson({
      'id': 'legacy',
      'name': '舊版優惠',
      'expiresAt': '2026-08-10T00:00:00.000',
      'reminderAt': '2026-08-07T18:30:00.000',
    });

    expect(restored.reminderDaysBefore, 3);
    expect(restored.reminderHour, 18);
    expect(restored.reminderMinute, 30);
    expect(restored.effectiveReminderAt, DateTime(2026, 8, 7, 18, 30));
  });

  test('offer JSON keeps optional fields and completion status', () {
    final original = Offer(
      id: 'json-test',
      name: '序列化測試',
      expiresAt: DateTime(2026, 8, 1),
      source: '來源',
      note: '備註',
      reminderEnabled: true,
      reminderDaysBefore: 3,
      reminderHour: 18,
      reminderMinute: 30,
      status: OfferStatus.completed,
      completedAt: DateTime(2026, 8, 1, 18, 45),
    );

    final restored = Offer.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.expiresAt, original.expiresAt);
    expect(restored.source, original.source);
    expect(restored.note, original.note);
    expect(restored.reminderEnabled, isTrue);
    expect(restored.reminderDaysBefore, 3);
    expect(restored.reminderHour, 18);
    expect(restored.reminderMinute, 30);
    expect(restored.status, OfferStatus.completed);
    expect(restored.completedAt, DateTime(2026, 8, 1, 18, 45));
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
