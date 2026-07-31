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

  final String id;
  final String name;
  final DateTime expiresAt;
  final String source;
  final String note;
  final OfferStatus status;

  bool get isCompleted => status == OfferStatus.completed;

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
