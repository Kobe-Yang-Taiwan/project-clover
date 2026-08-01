import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'offer.dart';

abstract interface class OfferStorage {
  Future<List<Offer>?> loadOffers();

  Future<void> saveOffers(List<Offer> offers);
}

class SharedPreferencesOfferStorage implements OfferStorage {
  SharedPreferencesOfferStorage({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey = 'project_clover.offers.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<List<Offer>?> loadOffers() async {
    final raw = await _preferences.getString(_storageKey);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .map(
            (item) => Offer.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveOffers(List<Offer> offers) {
    final encoded = jsonEncode(
      offers.map((offer) => offer.toJson()).toList(),
    );
    return _preferences.setString(_storageKey, encoded);
  }
}
