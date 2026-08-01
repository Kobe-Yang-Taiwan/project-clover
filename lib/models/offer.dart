enum OfferStatus { active, completed }

class Offer {
  const Offer({
    required this.id,
    required this.name,
    required this.expiresAt,
    this.source = '',
    this.note = '',
    this.status = OfferStatus.active,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'] as String? ?? OfferStatus.active.name;
    return Offer(
      id: json['id'] as String,
      name: json['name'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      source: json['source'] as String? ?? '',
      note: json['note'] as String? ?? '',
      status: OfferStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => OfferStatus.active,
      ),
    );
  }

  final String id;
  final String name;
  final DateTime expiresAt;
  final String source;
  final String note;
  final OfferStatus status;

  bool get isCompleted => status == OfferStatus.completed;

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'expiresAt': expiresAt.toIso8601String(),
        'source': source,
        'note': note,
        'status': status.name,
      };

  Offer copyWith({OfferStatus? status}) {
    return Offer(
      id: id,
      name: name,
      expiresAt: expiresAt,
      source: source,
      note: note,
      status: status ?? this.status,
    );
  }
}
