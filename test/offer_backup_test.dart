import 'package:flutter_test/flutter_test.dart';
import 'package:project_clover/models/offer.dart';
import 'package:project_clover/models/offer_backup.dart';

void main() {
  test('backup round trip keeps active and completed offer data', () {
    final exportedAt = DateTime(2026, 8, 1, 20, 30);
    final offers = [
      Offer(
        id: 'active',
        name: '待使用優惠',
        expiresAt: DateTime(2026, 9, 1),
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
    expect(decoded.offers.last.completedAt, DateTime(2026, 7, 31, 12));
  });

  test('backup rejects unrelated JSON', () {
    expect(
      () => OfferBackupCodec.decode('{"schema":"other","version":1,"offers":[]}'),
      throwsFormatException,
    );
  });

  test('backup rejects duplicate offer identifiers', () {
    final offer = Offer(
      id: 'duplicate',
      name: '重複優惠',
      expiresAt: DateTime(2026, 8, 10),
    );
    final encoded = OfferBackupCodec.encode(
      [offer, offer],
      exportedAt: DateTime(2026, 8, 1),
    );

    expect(() => OfferBackupCodec.decode(encoded), throwsFormatException);
  });
}
