import 'package:flutter/foundation.dart';

import 'offer.dart';
import 'offer_storage.dart';

enum OfferFilter {
  all,
  expiringToday,
  expiringWithinSevenDays,
  expired,
  completed,
  reminderEnabled,
  reminderDisabled,
}

enum OfferSortOption {
  expirationAscending,
  expirationDescending,
  createdNewest,
  createdOldest,
  recentlyModified,
}

class OfferDashboard {
  const OfferDashboard({
    required this.expiringToday,
    required this.expiringWithinThreeDays,
    required this.expiringWithinSevenDays,
    required this.completed,
    required this.total,
    required this.nextExpiring,
  });

  final int expiringToday;
  final int expiringWithinThreeDays;
  final int expiringWithinSevenDays;
  final int completed;
  final int total;
  final Offer? nextExpiring;
}

class OfferStore extends ChangeNotifier {
  OfferStore({
    List<Offer>? initialOffers,
    OfferStorage? storage,
    OfferSettingsStorage? settingsStorage,
    OfferSortOption initialSortOption = OfferSortOption.expirationAscending,
  })  : _offers = List<Offer>.from(initialOffers ?? _demoOffers()),
        _storage = storage,
        _settingsStorage = settingsStorage,
        _sortOption = initialSortOption;

  final List<Offer> _offers;
  final OfferStorage? _storage;
  final OfferSettingsStorage? _settingsStorage;
  OfferSortOption _sortOption;

  List<Offer> get allOffers => List<Offer>.unmodifiable(_offers);
  OfferSortOption get sortOption => _sortOption;

  static Future<OfferStore> load({
    OfferStorage? storage,
    OfferSettingsStorage? settingsStorage,
  }) async {
    final persistence = storage ?? SharedPreferencesOfferStorage();
    final settings = settingsStorage ??
        (storage == null ? SharedPreferencesOfferSettingsStorage() : null);
    final savedOffers = await persistence.loadOffers();
    final storedSort = await settings?.loadSortOption();
    final sortOption = OfferSortOption.values.firstWhere(
      (option) => option.name == storedSort,
      orElse: () => OfferSortOption.expirationAscending,
    );
    return OfferStore(
      initialOffers: savedOffers,
      storage: persistence,
      settingsStorage: settings,
      initialSortOption: sortOption,
    );
  }

  Future<void> setSortOption(OfferSortOption value) async {
    if (_sortOption == value) return;
    final previous = _sortOption;
    _sortOption = value;
    notifyListeners();
    try {
      await _settingsStorage?.saveSortOption(value.name);
    } catch (_) {
      _sortOption = previous;
      notifyListeners();
      rethrow;
    }
  }

  List<Offer> queryOffers({
    String query = '',
    OfferFilter filter = OfferFilter.all,
    OfferSortOption? sort,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final keyword = query.trim().toLowerCase();
    final results = _offers.where((offer) {
      final matchesSearch = keyword.isEmpty ||
          offer.name.toLowerCase().contains(keyword) ||
          offer.source.toLowerCase().contains(keyword) ||
          offer.note.toLowerCase().contains(keyword);
      if (!matchesSearch) return false;

      final expiry = _dateOnly(offer.expiresAt);
      final days = expiry.difference(today).inDays;
      return switch (filter) {
        OfferFilter.all => true,
        OfferFilter.expiringToday => !offer.isCompleted && days == 0,
        OfferFilter.expiringWithinSevenDays =>
          !offer.isCompleted && days >= 0 && days <= 7,
        OfferFilter.expired => !offer.isCompleted && days < 0,
        OfferFilter.completed => offer.isCompleted,
        OfferFilter.reminderEnabled =>
          !offer.isCompleted && offer.reminderEnabled,
        OfferFilter.reminderDisabled =>
          !offer.isCompleted && !offer.reminderEnabled,
      };
    }).toList();
    _sortOffers(results, sort ?? _sortOption);
    return List<Offer>.unmodifiable(results);
  }

  OfferDashboard dashboard({DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final active = _offers.where((offer) => !offer.isCompleted).toList();
    int within(int days) => active.where((offer) {
      final difference = _dateOnly(offer.expiresAt).difference(today).inDays;
      return difference >= 0 && difference <= days;
    }).length;
    final upcoming = active
        .where((offer) => !_dateOnly(offer.expiresAt).isBefore(today))
        .toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return OfferDashboard(
      expiringToday: within(0),
      expiringWithinThreeDays: within(3),
      expiringWithinSevenDays: within(7),
      completed: _offers.where((offer) => offer.isCompleted).length,
      total: _offers.length,
      nextExpiring: upcoming.firstOrNull,
    );
  }

  void _sortOffers(List<Offer> offers, OfferSortOption option) {
    int stable(Offer a, Offer b) => a.id.compareTo(b.id);
    offers.sort((a, b) {
      final comparison = switch (option) {
        OfferSortOption.expirationAscending =>
          a.expiresAt.compareTo(b.expiresAt),
        OfferSortOption.expirationDescending =>
          b.expiresAt.compareTo(a.expiresAt),
        OfferSortOption.createdNewest => _activityDate(b, created: true)
            .compareTo(_activityDate(a, created: true)),
        OfferSortOption.createdOldest => _activityDate(a, created: true)
            .compareTo(_activityDate(b, created: true)),
        OfferSortOption.recentlyModified =>
          _activityDate(b).compareTo(_activityDate(a)),
      };
      return comparison == 0 ? stable(a, b) : comparison;
    });
  }

  DateTime _activityDate(Offer offer, {bool created = false}) {
    if (created) return offer.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return offer.updatedAt ?? offer.createdAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Offer> get activeOffers {
    final offers = _offers.where((offer) => !offer.isCompleted).toList();
    offers.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return List<Offer>.unmodifiable(offers);
  }

  List<Offer> get completedOffers {
    final offers = _offers.where((offer) => offer.isCompleted).toList();
    offers.sort((a, b) {
      final aCompleted = a.completedAt;
      final bCompleted = b.completedAt;
      if (aCompleted != null && bCompleted != null) {
        return bCompleted.compareTo(aCompleted);
      }
      if (aCompleted != null) return -1;
      if (bCompleted != null) return 1;
      return b.expiresAt.compareTo(a.expiresAt);
    });
    return List<Offer>.unmodifiable(offers);
  }

  int expiringWithinDays(int days, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final end = today.add(Duration(days: days));
    return activeOffers.where((offer) {
      final expiry = _dateOnly(offer.expiresAt);
      return !expiry.isBefore(today) && !expiry.isAfter(end);
    }).length;
  }

  Future<Offer> addOffer({
    required String name,
    required DateTime expiresAt,
    String source = '',
    String note = '',
    bool reminderEnabled = true,
    int reminderDaysBefore = 1,
    int reminderHour = 9,
    int reminderMinute = 0,
  }) async {
    final now = DateTime.now();
    final offer = Offer(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      expiresAt: expiresAt,
      source: source.trim(),
      note: note.trim(),
      reminderEnabled: reminderEnabled,
      reminderDaysBefore: normalizeReminderDays(reminderDaysBefore),
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      createdAt: now,
      updatedAt: now,
    );
    _offers.add(offer);
    try {
      await _persist();
    } catch (_) {
      _offers.remove(offer);
      rethrow;
    }
    notifyListeners();
    return offer;
  }

  Future<void> updateOffer({
    required String id,
    required String name,
    required DateTime expiresAt,
    String source = '',
    String note = '',
    bool reminderEnabled = true,
    int reminderDaysBefore = 1,
    int reminderHour = 9,
    int reminderMinute = 0,
  }) async {
    final index = _offers.indexWhere((offer) => offer.id == id);
    if (index == -1) throw StateError('Offer not found');

    final previous = _offers[index];
    _offers[index] = previous.copyWith(
      name: name.trim(),
      expiresAt: expiresAt,
      source: source.trim(),
      note: note.trim(),
      reminderEnabled: reminderEnabled,
      reminderDaysBefore: normalizeReminderDays(reminderDaysBefore),
      reminderHour: reminderHour,
      reminderMinute: reminderMinute,
      updatedAt: DateTime.now(),
    );
    try {
      await _persist();
    } catch (_) {
      _offers[index] = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> deleteOffer(String id) async {
    final index = _offers.indexWhere((offer) => offer.id == id);
    if (index == -1) return;

    final removed = _offers.removeAt(index);
    try {
      await _persist();
    } catch (_) {
      _offers.insert(index, removed);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> markCompleted(String id, {DateTime? completedAt}) async {
    final index = _offers.indexWhere((offer) => offer.id == id);
    if (index == -1 || _offers[index].isCompleted) return;

    final previous = _offers[index];
    _offers[index] = previous.copyWith(
      status: OfferStatus.completed,
      completedAt: completedAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    try {
      await _persist();
    } catch (_) {
      _offers[index] = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> restoreOffer(String id) async {
    final index = _offers.indexWhere((offer) => offer.id == id);
    if (index == -1 || !_offers[index].isCompleted) return;

    final previous = _offers[index];
    _offers[index] = previous.copyWith(
      status: OfferStatus.active,
      clearCompletedAt: true,
      updatedAt: DateTime.now(),
    );
    try {
      await _persist();
    } catch (_) {
      _offers[index] = previous;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> replaceAll(Iterable<Offer> offers) async {
    final previous = List<Offer>.from(_offers);
    _offers
      ..clear()
      ..addAll(offers);
    try {
      await _persist();
    } catch (_) {
      _offers
        ..clear()
        ..addAll(previous);
      rethrow;
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await _storage?.saveOffers(List<Offer>.unmodifiable(_offers));
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static List<Offer> _demoOffers() {
    final today = _dateOnly(DateTime.now());
    return [
      Offer(
        id: 'coffee',
        name: '超商大杯拿鐵兌換券',
        source: '便利商店 App',
        note: '上班前順路使用',
        expiresAt: today,
      ),
      Offer(
        id: 'movie',
        name: '電影票買一送一',
        source: '信用卡優惠',
        expiresAt: today.add(const Duration(days: 2)),
      ),
      Offer(
        id: 'shopping',
        name: '百貨公司 200 元折價券',
        source: '會員 App',
        expiresAt: today.add(const Duration(days: 6)),
      ),
    ];
  }
}
