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
    final days = _daysUntil(offer.expiresAt);
    final color = days <= 0
        ? Theme.of(context).colorScheme.error
        : days <= 3
            ? const Color(0xFFB05A00)
            : Theme.of(context).colorScheme.primary;

    return Card(
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
                    Text(
                      '${_urgencyLabel(days)} · ${formatTaiwanDate(offer.expiresAt)}',
                      style: TextStyle(color: color, fontWeight: FontWeight.w600),
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

  int _daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(date.year, date.month, date.day);
    return expiry.difference(today).inDays;
  }

  String _urgencyLabel(int days) {
    if (days < 0) return '已過期';
    if (days == 0) return '今天到期';
    if (days == 1) return '明天到期';
    return '剩下 $days 天';
  }
}

String formatTaiwanDate(DateTime date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
