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

  test('replacing all offers persists restored backup data', () async {
    final storage = MemoryOfferStorage();
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'old',
          name: '手機原資料',
          expiresAt: DateTime(2026, 8, 10),
        ),
      ],
      storage: storage,
    );
    final restoredOffers = [
      Offer(
        id: 'restored',
        name: '備份資料',
        expiresAt: DateTime(2026, 9, 1),
      ),
    ];

    await store.replaceAll(restoredOffers);
    final reopened = await OfferStore.load(storage: storage);

    expect(reopened.allOffers, hasLength(1));
    expect(reopened.allOffers.single.id, 'restored');
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

  test('search matches title, merchant and note without case sensitivity', () {
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'title',
          name: 'Coffee Coupon',
          expiresAt: DateTime(2026, 8, 10),
        ),
        Offer(
          id: 'merchant',
          name: '午餐券',
          source: 'STARBUCKS',
          expiresAt: DateTime(2026, 8, 11),
        ),
        Offer(
          id: 'note',
          name: '電影券',
          note: '週末 coffee date',
          expiresAt: DateTime(2026, 8, 12),
        ),
      ],
    );

    expect(
      store.queryOffers(query: 'CoFfEe').map((offer) => offer.id),
      ['title', 'note'],
    );
    expect(store.queryOffers(query: 'starbucks').single.id, 'merchant');
    expect(store.queryOffers(query: ''), hasLength(3));
  });

  test('filter combines with search and excludes completed time matches', () {
    final now = DateTime(2026, 8, 3, 15);
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'today',
          name: '咖啡今天',
          expiresAt: DateTime(2026, 8, 3),
        ),
        Offer(
          id: 'week',
          name: '咖啡本週',
          expiresAt: DateTime(2026, 8, 9),
          reminderEnabled: false,
        ),
        Offer(
          id: 'expired',
          name: '過期咖啡',
          expiresAt: DateTime(2026, 8, 2),
        ),
        Offer(
          id: 'completed',
          name: '咖啡已完成',
          expiresAt: DateTime(2026, 8, 3),
          status: OfferStatus.completed,
        ),
      ],
    );

    expect(
      store
          .queryOffers(
            query: '咖啡',
            filter: OfferFilter.expiringToday,
            now: now,
          )
          .map((offer) => offer.id),
      ['today'],
    );
    expect(
      store
          .queryOffers(filter: OfferFilter.expiringWithinSevenDays, now: now)
          .map((offer) => offer.id),
      ['today', 'week'],
    );
    expect(
      store
          .queryOffers(filter: OfferFilter.reminderDisabled, now: now)
          .map((offer) => offer.id),
      ['week'],
    );
    expect(
      store.queryOffers(filter: OfferFilter.completed, now: now).single.id,
      'completed',
    );
  });

  test('all five sort options produce deterministic order', () {
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'a',
          name: 'A',
          expiresAt: DateTime(2026, 8, 20),
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 2),
        ),
        Offer(
          id: 'b',
          name: 'B',
          expiresAt: DateTime(2026, 8, 10),
          createdAt: DateTime(2026, 8, 2),
          updatedAt: DateTime(2026, 8, 3),
        ),
      ],
    );

    expect(
      store
          .queryOffers(sort: OfferSortOption.expirationAscending)
          .map((offer) => offer.id),
      ['b', 'a'],
    );
    expect(
      store
          .queryOffers(sort: OfferSortOption.expirationDescending)
          .map((offer) => offer.id),
      ['a', 'b'],
    );
    expect(
      store
          .queryOffers(sort: OfferSortOption.createdNewest)
          .map((offer) => offer.id),
      ['b', 'a'],
    );
    expect(
      store
          .queryOffers(sort: OfferSortOption.createdOldest)
          .map((offer) => offer.id),
      ['a', 'b'],
    );
    expect(
      store
          .queryOffers(sort: OfferSortOption.recentlyModified)
          .map((offer) => offer.id),
      ['b', 'a'],
    );
  });

  test('selected sort option persists across store reloads', () async {
    final offerStorage = MemoryOfferStorage();
    final settings = MemoryOfferSettingsStorage();
    final store = OfferStore(
      initialOffers: [],
      storage: offerStorage,
      settingsStorage: settings,
    );

    await store.setSortOption(OfferSortOption.recentlyModified);
    final reopened = await OfferStore.load(
      storage: offerStorage,
      settingsStorage: settings,
    );

    expect(reopened.sortOption, OfferSortOption.recentlyModified);
  });

  test('dashboard counts live data and selects next non-expired offer', () {
    final store = OfferStore(
      initialOffers: [
        Offer(id: 'old', name: '過期', expiresAt: DateTime(2026, 8, 2)),
        Offer(id: 'today', name: '今天', expiresAt: DateTime(2026, 8, 3)),
        Offer(id: 'three', name: '三天', expiresAt: DateTime(2026, 8, 6)),
        Offer(id: 'seven', name: '七天', expiresAt: DateTime(2026, 8, 10)),
        Offer(
          id: 'done',
          name: '完成',
          expiresAt: DateTime(2026, 8, 3),
          status: OfferStatus.completed,
        ),
      ],
    );

    final dashboard = store.dashboard(now: DateTime(2026, 8, 3, 23));

    expect(dashboard.expiringToday, 1);
    expect(dashboard.expiringWithinThreeDays, 2);
    expect(dashboard.expiringWithinSevenDays, 3);
    expect(dashboard.completed, 1);
    expect(dashboard.total, 5);
    expect(dashboard.nextExpiring?.id, 'today');
  });

  test('visual status follows date priority', () {
    final now = DateTime(2026, 8, 3, 12);
    Offer on(int day) => Offer(
          id: '$day',
          name: '$day',
          expiresAt: DateTime(2026, 8, day),
        );

    expect(on(2).visualStatus(now: now), OfferVisualStatus.expired);
    expect(on(3).visualStatus(now: now), OfferVisualStatus.expiringToday);
    expect(on(4).visualStatus(now: now), OfferVisualStatus.expiringTomorrow);
    expect(
      on(6).visualStatus(now: now),
      OfferVisualStatus.expiringWithinThreeDays,
    );
    expect(on(7).visualStatus(now: now), OfferVisualStatus.available);
  });

  test('favorite state persists and favorites filter combines with category', () async {
    final storage = MemoryOfferStorage();
    final store = OfferStore(
      initialOffers: [
        Offer(
          id: 'coffee',
          name: '咖啡券',
          expiresAt: DateTime(2026, 8, 10),
          category: OfferCategory.coffee,
        ),
        Offer(
          id: 'food',
          name: '餐券',
          expiresAt: DateTime(2026, 8, 11),
          category: OfferCategory.food,
          isFavorite: true,
        ),
      ],
      storage: storage,
    );

    await store.toggleFavorite('coffee');
    final reopened = await OfferStore.load(storage: storage);

    expect(reopened.allOffers.firstWhere((offer) => offer.id == 'coffee').isFavorite, isTrue);
    expect(
      reopened
          .queryOffers(
            filter: OfferFilter.favorites,
            category: OfferCategory.coffee,
          )
          .single
          .id,
      'coffee',
    );
  });

  test('legacy JSON defaults to others category and not favorite', () {
    final offer = Offer.fromJson({
      'id': 'legacy-v09',
      'name': '舊資料',
      'expiresAt': '2026-08-10T00:00:00.000',
    });

    expect(offer.category, OfferCategory.others);
    expect(offer.isFavorite, isFalse);
  });

  test('My Day groups dates and prioritizes favorite recommendation', () {
    final store = OfferStore(
      initialOffers: [
        Offer(id: 'today', name: '今天', expiresAt: DateTime(2026, 8, 3)),
        Offer(id: 'tomorrow', name: '明天', expiresAt: DateTime(2026, 8, 4)),
        Offer(id: 'week', name: '本週', expiresAt: DateTime(2026, 8, 8)),
        Offer(
          id: 'favorite',
          name: '收藏優先',
          expiresAt: DateTime(2026, 8, 10),
          isFavorite: true,
        ),
        Offer(
          id: 'done',
          name: '已完成',
          expiresAt: DateTime(2026, 8, 3),
          status: OfferStatus.completed,
        ),
      ],
    );

    final result = store.myDay(now: DateTime(2026, 8, 3, 23));

    expect(result.recommendedToday?.id, 'favorite');
    expect(result.expiringToday.map((offer) => offer.id), ['today']);
    expect(result.expiringTomorrow.map((offer) => offer.id), ['tomorrow']);
    expect(result.mustUseThisWeek.map((offer) => offer.id), ['week']);
  });

  test('batch operations persist completion restore and deletion atomically', () async {
    final storage = MemoryOfferStorage();
    final store = OfferStore(
      initialOffers: [
        Offer(id: 'a', name: 'A', expiresAt: DateTime(2026, 8, 10)),
        Offer(id: 'b', name: 'B', expiresAt: DateTime(2026, 8, 11)),
        Offer(id: 'c', name: 'C', expiresAt: DateTime(2026, 8, 12)),
      ],
      storage: storage,
    );

    await store.markOffersCompleted({'a', 'b'}, completedAt: DateTime(2026, 8, 3));
    expect(store.completedOffers.map((offer) => offer.id).toSet(), {'a', 'b'});

    await store.restoreOffers({'a'});
    expect(store.activeOffers.map((offer) => offer.id).toSet(), {'a', 'c'});
    expect(store.allOffers.firstWhere((offer) => offer.id == 'a').completedAt, isNull);

    await store.deleteOffers({'b', 'c'});
    final reopened = await OfferStore.load(storage: storage);
    expect(reopened.allOffers.single.id, 'a');
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

class MemoryOfferSettingsStorage implements OfferSettingsStorage {
  String? value;

  @override
  Future<String?> loadSortOption() async => value;

  @override
  Future<void> saveSortOption(String value) async {
    this.value = value;
  }
}
