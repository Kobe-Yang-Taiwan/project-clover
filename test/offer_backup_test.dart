import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/models/offer.dart';
import 'package:project_clover/models/offer_backup.dart';
import 'package:project_clover/models/offer_storage.dart';
import 'package:project_clover/models/offer_store.dart';

void main() {
  test('backup round trip keeps active and completed offer data', () {
    final exportedAt = DateTime(2026, 8, 1, 20, 30);
    final offers = [
      Offer(
        id: 'active',
        name: '待使用優惠',
        expiresAt: DateTime(2026, 9, 1),
        isFavorite: true,
        category: OfferCategory.coffee,
        reminderDaysBefore: 3,
        reminderHour: 18,
        reminderMinute: 45,
      ),
      Offer(
        id: 'completed',
        name: '已完成優惠',
        expiresAt: DateTime(2026, 8, 1),
        status: OfferStatus.completed,
        completedAt: DateTime(2026, 7, 31, 12),
      ),
    ];

    final decoded = OfferBackupCodec.decode(
      OfferBackupCodec.encode(offers, exportedAt: exportedAt),
    );

    expect(decoded.exportedAt, exportedAt);
    expect(decoded.activeCount, 1);
    expect(decoded.completedCount, 1);
    expect(decoded.offers.first.reminderDaysBefore, 3);
    expect(decoded.offers.first.reminderHour, 18);
    expect(decoded.offers.first.isFavorite, isTrue);
    expect(decoded.offers.first.category, OfferCategory.coffee);
    expect(decoded.offers.last.completedAt, DateTime(2026, 7, 31, 12));
  });

  test('backup rejects unrelated JSON', () {
    expect(
      () =>
          OfferBackupCodec.decode('{"schema":"other","version":1,"offers":[]}'),
      throwsFormatException,
    );
  });

  test('backup rejects duplicate offer identifiers', () {
    final offer = Offer(
      id: 'duplicate',
      name: '重複優惠',
      expiresAt: DateTime(2026, 8, 10),
    );
    final encoded = OfferBackupCodec.encode([
      offer,
      offer,
    ], exportedAt: DateTime(2026, 8, 1));

    expect(() => OfferBackupCodec.decode(encoded), throwsFormatException);
  });

  test('V0.8 backup remains compatible', () {
    final offer = OfferBackupCodec.decode(_backupFor('0.8')).offers.single;

    expect(offer.name, 'V0.8 優惠');
    expect(offer.reminderDaysBefore, 3);
    expect(offer.reminderHour, 18);
    expect(offer.isFavorite, isFalse);
    expect(offer.category, OfferCategory.others);
  });

  test('V0.9 backup remains compatible', () {
    final offer = OfferBackupCodec.decode(_backupFor('0.9')).offers.single;

    expect(offer.name, 'V0.9 優惠');
    expect(offer.reminderDaysBefore, 7);
    expect(offer.isFavorite, isFalse);
    expect(offer.category, OfferCategory.others);
  });

  test('V0.10 backup remains compatible', () {
    final offer = OfferBackupCodec.decode(_backupFor('0.10')).offers.single;

    expect(offer.name, 'V0.10 優惠');
    expect(offer.isFavorite, isTrue);
    expect(offer.category, OfferCategory.coffee);
  });

  test('V0.11 backup remains compatible', () {
    final offer = OfferBackupCodec.decode(_backupFor('0.11')).offers.single;

    expect(offer.name, 'V0.11 優惠');
    expect(offer.isFavorite, isTrue);
    expect(offer.category, OfferCategory.food);
  });

  test(
    'V0.8 through V0.11 backups can replace and persist current data',
    () async {
      for (final version in ['0.8', '0.9', '0.10', '0.11']) {
        final storage = _MemoryStorage();
        final store = OfferStore(
          initialOffers: [
            Offer(id: 'phone', name: '手機資料', expiresAt: DateTime(2026, 8, 31)),
          ],
          storage: storage,
        );
        final backup = OfferBackupCodec.decode(_backupFor(version));

        await store.replaceAll(backup.offers);
        final reopened = await OfferStore.load(storage: storage);

        expect(reopened.allOffers.single.id, 'v$version');
        expect(reopened.allOffers.single.name, 'V$version 優惠');
      }
    },
  );
}

String _backupFor(String appVersion) {
  final offer = <String, Object?>{
    'id': 'v$appVersion',
    'name': 'V$appVersion 優惠',
    'expiresAt': '2026-09-30T00:00:00.000',
    'source': '相容性測試',
    'note': '',
    'reminderEnabled': true,
    'status': 'active',
  };
  switch (appVersion) {
    case '0.8':
      offer['reminderAt'] = '2026-09-27T18:30:00.000';
      break;
    case '0.9':
      offer
        ..['reminderDaysBefore'] = 7
        ..['reminderHour'] = 9
        ..['reminderMinute'] = 15;
      break;
    case '0.10':
      offer
        ..['reminderDaysBefore'] = 3
        ..['reminderHour'] = 12
        ..['reminderMinute'] = 0
        ..['isFavorite'] = true
        ..['category'] = 'coffee';
      break;
    case '0.11':
      offer
        ..['reminderDaysBefore'] = 1
        ..['reminderHour'] = 20
        ..['reminderMinute'] = 0
        ..['isFavorite'] = true
        ..['category'] = 'food';
      break;
    default:
      throw ArgumentError.value(appVersion);
  }
  return jsonEncode({
    'schema': OfferBackupCodec.schema,
    'version': OfferBackupCodec.version,
    'exportedAt': '2026-08-04T09:00:00.000',
    'offers': [offer],
  });
}

class _MemoryStorage implements OfferStorage {
  List<Offer>? offers;

  @override
  Future<List<Offer>?> loadOffers() async =>
      offers == null ? null : List<Offer>.from(offers!);

  @override
  Future<void> saveOffers(List<Offer> offers) async {
    this.offers = List<Offer>.from(offers);
  }
}
