import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'offer.dart';

abstract interface class OfferStorage {
  Future<List<Offer>?> loadOffers();

  Future<void> saveOffers(List<Offer> offers);
}

abstract interface class OfferSettingsStorage {
  Future<String?> loadSortOption();

  Future<void> saveSortOption(String value);
}

class ReminderDefaults {
  const ReminderDefaults({
    this.enabled = true,
    this.daysBefore = 1,
    this.hour = 9,
    this.minute = 0,
  });

  final bool enabled;
  final int daysBefore;
  final int hour;
  final int minute;

  ReminderDefaults copyWith({
    bool? enabled,
    int? daysBefore,
    int? hour,
    int? minute,
  }) {
    return ReminderDefaults(
      enabled: enabled ?? this.enabled,
      daysBefore: normalizeReminderDays(daysBefore ?? this.daysBefore),
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }

  Map<String, Object> toJson() => {
        'enabled': enabled,
        'daysBefore': daysBefore,
        'hour': hour,
        'minute': minute,
      };

  factory ReminderDefaults.fromJson(Map<String, dynamic> json) {
    return ReminderDefaults(
      enabled: json['enabled'] as bool? ?? true,
      daysBefore: normalizeReminderDays(json['daysBefore'] as int? ?? 1),
      hour: (json['hour'] as int? ?? 9).clamp(0, 23).toInt(),
      minute: (json['minute'] as int? ?? 0).clamp(0, 59).toInt(),
    );
  }
}

abstract interface class ReminderDefaultsStorage {
  Future<ReminderDefaults?> loadReminderDefaults();

  Future<void> saveReminderDefaults(ReminderDefaults value);
}

class SharedPreferencesOfferSettingsStorage
    implements OfferSettingsStorage, ReminderDefaultsStorage {
  SharedPreferencesOfferSettingsStorage({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _sortKey = 'project_clover.sort_option.v1';
  static const _reminderDefaultsKey =
      'project_clover.reminder_defaults.v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> loadSortOption() => _preferences.getString(_sortKey);

  @override
  Future<void> saveSortOption(String value) =>
      _preferences.setString(_sortKey, value);

  @override
  Future<ReminderDefaults?> loadReminderDefaults() async {
    final raw = await _preferences.getString(_reminderDefaultsKey);
    if (raw == null) return null;
    try {
      return ReminderDefaults.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveReminderDefaults(ReminderDefaults value) =>
      _preferences.setString(_reminderDefaultsKey, jsonEncode(value.toJson()));
}

class SharedPreferencesOfferStorage implements OfferStorage {
  SharedPreferencesOfferStorage({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _storageKey = 'project_clover.offers.v1';
  static const schemaVersion = 1;

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
