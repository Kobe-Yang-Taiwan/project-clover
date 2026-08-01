import 'package:flutter/foundation.dart';

import 'offer.dart';
import 'offer_storage.dart';

class OfferStore extends ChangeNotifier {
  OfferStore({
    List<Offer>? initialOffers,
    OfferStorage? storage,
  })  : _offers = List<Offer>.from(initialOffers ?? _demoOffers()),
        _storage = storage;

  final List<Offer> _offers;
  final OfferStorage? _storage;

  static Future<OfferStore> load({OfferStorage? storage}) async {
    final persistence = storage ?? SharedPreferencesOfferStorage();
    final savedOffers = await persistence.loadOffers();
    return OfferStore(initialOffers: savedOffers, storage: persistence);
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
    );
    try {
      await _persist();
    } catch (_) {
      _offers[index] = previous;
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
