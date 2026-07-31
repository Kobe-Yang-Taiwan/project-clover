import 'package:flutter/foundation.dart';

import 'offer.dart';

class OfferStore extends ChangeNotifier {
  OfferStore({List<Offer>? initialOffers})
      : _offers = List<Offer>.from(initialOffers ?? _demoOffers());

  final List<Offer> _offers;

  List<Offer> get activeOffers {
    final offers = _offers.where((offer) => !offer.isCompleted).toList();
    offers.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return List<Offer>.unmodifiable(offers);
  }

  List<Offer> get completedOffers => List<Offer>.unmodifiable(
        _offers.where((offer) => offer.isCompleted),
      );

  int expiringWithinDays(int days, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final end = today.add(Duration(days: days));
    return activeOffers.where((offer) {
      final expiry = _dateOnly(offer.expiresAt);
      return !expiry.isBefore(today) && !expiry.isAfter(end);
    }).length;
  }

  void addOffer({
    required String name,
    required DateTime expiresAt,
    String source = '',
    String note = '',
  }) {
    _offers.add(
      Offer(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim(),
        expiresAt: expiresAt,
        source: source.trim(),
        note: note.trim(),
      ),
    );
    notifyListeners();
  }

  void markCompleted(String id) {
    final index = _offers.indexWhere((offer) => offer.id == id);
    if (index == -1 || _offers[index].isCompleted) return;
    _offers[index] = _offers[index].copyWith(status: OfferStatus.completed);
    notifyListeners();
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
