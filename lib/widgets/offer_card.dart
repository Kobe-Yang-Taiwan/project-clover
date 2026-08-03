import 'package:flutter/material.dart';

import '../models/offer.dart';

class OfferCard extends StatelessWidget {
  const OfferCard({
    required this.offer,
    required this.onTap,
    super.key,
  });

  final Offer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = offer.visualStatus();
    final color = offer.isCompleted
        ? const Color(0xFF4F6F64)
        : _statusColor(context, status);
    final label = offer.isCompleted ? '已完成' : _statusLabel(status);

    return Card(
      color: color.withAlpha(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withAlpha(70)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.confirmation_number_outlined, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (offer.source.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(offer.source),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withAlpha(30),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          formatTaiwanDate(offer.expiresAt),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, OfferVisualStatus status) {
    return switch (status) {
      OfferVisualStatus.available => Theme.of(context).colorScheme.primary,
      OfferVisualStatus.expiringWithinThreeDays => const Color(0xFF9A6700),
      OfferVisualStatus.expiringTomorrow => const Color(0xFFC25400),
      OfferVisualStatus.expiringToday => Theme.of(context).colorScheme.error,
      OfferVisualStatus.expired => const Color(0xFF6B6B6B),
    };
  }

  String _statusLabel(OfferVisualStatus status) {
    return switch (status) {
      OfferVisualStatus.available => '可使用',
      OfferVisualStatus.expiringWithinThreeDays => '3 天內到期',
      OfferVisualStatus.expiringTomorrow => '明天到期',
      OfferVisualStatus.expiringToday => '今天到期',
      OfferVisualStatus.expired => '已過期',
    };
  }
}

String formatTaiwanDate(DateTime date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

String formatTaiwanDateTime(DateTime date) =>
    '${formatTaiwanDate(date)} '
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';
