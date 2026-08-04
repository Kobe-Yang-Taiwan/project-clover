import 'dart:convert';

import 'offer.dart';

class OfferBackup {
  const OfferBackup({required this.exportedAt, required this.offers});

  final DateTime exportedAt;
  final List<Offer> offers;

  int get activeCount => offers.where((offer) => !offer.isCompleted).length;
  int get completedCount => offers.where((offer) => offer.isCompleted).length;
}

class OfferBackupCodec {
  static const schema = 'project-clover-backup';
  static const version = 1;
  static const maximumOffers = 5000;

  static String encode(Iterable<Offer> offers, {DateTime? exportedAt}) {
    final payload = {
      'schema': schema,
      'version': version,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'offers': offers.map((offer) => offer.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static OfferBackup decode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) throw const FormatException('備份格式不正確');
      final payload = Map<String, dynamic>.from(decoded);
      if (payload['schema'] != schema) {
        throw const FormatException('這不是 Project Clover 備份檔');
      }
      if (payload['version'] != version) {
        throw const FormatException('此備份版本目前不支援');
      }
      final exportedAt = DateTime.tryParse(
        payload['exportedAt'] as String? ?? '',
      );
      if (exportedAt == null) throw const FormatException('缺少備份時間');
      final rawOffers = payload['offers'];
      if (rawOffers is! List) throw const FormatException('缺少優惠資料');
      if (rawOffers.length > maximumOffers) {
        throw const FormatException('備份筆數超過安全上限');
      }

      final offers = rawOffers
          .map((item) => Offer.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      if (offers.any(
        (offer) => offer.id.isEmpty || offer.name.trim().isEmpty,
      )) {
        throw const FormatException('備份包含不完整優惠');
      }
      if (offers.map((offer) => offer.id).toSet().length != offers.length) {
        throw const FormatException('備份包含重複優惠');
      }
      return OfferBackup(exportedAt: exportedAt, offers: offers);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('備份檔已損壞或內容不完整');
    }
  }
}
