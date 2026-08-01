enum OfferStatus { active, completed }

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
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    final expiresAt = DateTime.parse(json['expiresAt'] as String);
    final legacyReminderAt = json['reminderAt'] == null
        ? null
        : DateTime.parse(json['reminderAt'] as String);
    final storedDays = json['reminderDaysBefore'] as int?;
    final migratedDays = legacyReminderAt == null
        ? 1
        : DateTime(
            expiresAt.year,
            expiresAt.month,
            expiresAt.day,
          ).difference(
            DateTime(
              legacyReminderAt.year,
              legacyReminderAt.month,
              legacyReminderAt.day,
            ),
          ).inDays;
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

  DateTime get effectiveReminderAt => DateTime(
        expiresAt.year,
        expiresAt.month,
        expiresAt.day,
        reminderHour,
        reminderMinute,
      ).subtract(Duration(days: reminderDaysBefore));

  bool get isCompleted => status == OfferStatus.completed;

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
    bool clearCompletedAt = false,
  }) {
    return Offer(
      id: id,
      name: name ?? this.name,
      expiresAt: expiresAt ?? this.expiresAt,
      source: source ?? this.source,
      note: note ?? this.note,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDaysBefore:
          reminderDaysBefore ?? this.reminderDaysBefore,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      status: status ?? this.status,
      completedAt:
          clearCompletedAt ? null : completedAt ?? this.completedAt,
    );
  }
}

int normalizeReminderDays(int value) {
  return Offer.supportedReminderDays.reduce(
    (closest, candidate) =>
        (candidate - value).abs() < (closest - value).abs()
            ? candidate
            : closest,
  );
}
