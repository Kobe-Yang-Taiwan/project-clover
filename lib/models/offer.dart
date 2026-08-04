enum OfferStatus { active, completed }

enum OfferCategory {
  food,
  coffee,
  convenienceStore,
  departmentStore,
  onlineShopping,
  entertainment,
  travel,
  transportation,
  others,
}

enum OfferVisualStatus {
  available,
  expiringWithinThreeDays,
  expiringTomorrow,
  expiringToday,
  expired,
}

class Offer {
  const Offer({
    required this.id,
    required this.name,
    required this.expiresAt,
    this.source = '',
    this.note = '',
    this.reminderEnabled = true,
    this.reminderDaysBefore = 1,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.status = OfferStatus.active,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.isFavorite = false,
    this.category = OfferCategory.others,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    final expiresAt = DateTime.parse(json['expiresAt'] as String);
    final legacyReminderAt = json['reminderAt'] == null
        ? null
        : DateTime.parse(json['reminderAt'] as String);
    final storedDays = json['reminderDaysBefore'] as int?;
    final migratedDays = legacyReminderAt == null
        ? 1
        : DateTime(expiresAt.year, expiresAt.month, expiresAt.day)
              .difference(
                DateTime(
                  legacyReminderAt.year,
                  legacyReminderAt.month,
                  legacyReminderAt.day,
                ),
              )
              .inDays;
    final statusName = json['status'] as String? ?? OfferStatus.active.name;

    return Offer(
      id: json['id'] as String,
      name: json['name'] as String,
      expiresAt: expiresAt,
      source: json['source'] as String? ?? '',
      note: json['note'] as String? ?? '',
      reminderEnabled: json['reminderEnabled'] as bool? ?? true,
      reminderDaysBefore: normalizeReminderDays(storedDays ?? migratedDays),
      reminderHour: json['reminderHour'] as int? ?? legacyReminderAt?.hour ?? 9,
      reminderMinute:
          json['reminderMinute'] as int? ?? legacyReminderAt?.minute ?? 0,
      status: OfferStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => OfferStatus.active,
      ),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
      category: OfferCategory.values.firstWhere(
        (category) => category.name == json['category'],
        orElse: () => OfferCategory.others,
      ),
    );
  }

  static const supportedReminderDays = [1, 3, 7];

  final String id;
  final String name;
  final DateTime expiresAt;
  final String source;
  final String note;
  final bool reminderEnabled;
  final int reminderDaysBefore;
  final int reminderHour;
  final int reminderMinute;
  final OfferStatus status;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isFavorite;
  final OfferCategory category;

  DateTime get effectiveReminderAt => DateTime(
    expiresAt.year,
    expiresAt.month,
    expiresAt.day,
    reminderHour,
    reminderMinute,
  ).subtract(Duration(days: reminderDaysBefore));

  bool get isCompleted => status == OfferStatus.completed;

  OfferVisualStatus visualStatus({DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final expiry = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    final days = expiry.difference(today).inDays;
    if (days < 0) return OfferVisualStatus.expired;
    if (days == 0) return OfferVisualStatus.expiringToday;
    if (days == 1) return OfferVisualStatus.expiringTomorrow;
    if (days <= 3) return OfferVisualStatus.expiringWithinThreeDays;
    return OfferVisualStatus.available;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'expiresAt': expiresAt.toIso8601String(),
    'source': source,
    'note': note,
    'reminderEnabled': reminderEnabled,
    'reminderDaysBefore': reminderDaysBefore,
    'reminderHour': reminderHour,
    'reminderMinute': reminderMinute,
    'status': status.name,
    'completedAt': completedAt?.toIso8601String(),
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    'isFavorite': isFavorite,
    'category': category.name,
  };

  Offer copyWith({
    String? name,
    DateTime? expiresAt,
    String? source,
    String? note,
    bool? reminderEnabled,
    int? reminderDaysBefore,
    int? reminderHour,
    int? reminderMinute,
    OfferStatus? status,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
    OfferCategory? category,
    bool clearCompletedAt = false,
  }) {
    return Offer(
      id: id,
      name: name ?? this.name,
      expiresAt: expiresAt ?? this.expiresAt,
      source: source ?? this.source,
      note: note ?? this.note,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      status: status ?? this.status,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      category: category ?? this.category,
    );
  }
}

int normalizeReminderDays(int value) {
  return Offer.supportedReminderDays.reduce(
    (closest, candidate) => (candidate - value).abs() < (closest - value).abs()
        ? candidate
        : closest,
  );
}
