import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/offer.dart';
import 'models/offer_store.dart';
import 'offer_reminder_service.dart';
import 'theme.dart';
import 'widgets/offer_card.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await OfferStore.load();
  OfferReminderScheduler reminders = const NoopOfferReminderScheduler();
  try {
    reminders = await AndroidOfferReminderScheduler.create();
    await reminders.sync(store.activeOffers);
  } catch (_) {
    // Notifications are optional; storage and the core app must still start.
  }
  runApp(CloverApp(store: store, reminders: reminders));
}

class CloverApp extends StatefulWidget {
  const CloverApp({
    super.key,
    this.store,
    this.reminders = const NoopOfferReminderScheduler(),
  });

  final OfferStore? store;
  final OfferReminderScheduler reminders;

  @override
  State<CloverApp> createState() => _CloverAppState();
}

class _CloverAppState extends State<CloverApp> {
  late final OfferStore store = widget.store ?? OfferStore();

  @override
  void dispose() {
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project Clover',
      debugShowCheckedModeBanner: false,
      theme: buildCloverTheme(),
      locale: const Locale('zh', 'TW'),
      supportedLocales: const [Locale('zh', 'TW')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: CloverHome(store: store, reminders: widget.reminders),
    );
  }
}

class CloverHome extends StatefulWidget {
  const CloverHome({
    required this.store,
    required this.reminders,
    super.key,
  });

  final OfferStore store;
  final OfferReminderScheduler reminders;

  @override
  State<CloverHome> createState() => _CloverHomeState();
}

class _CloverHomeState extends State<CloverHome> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(currentIndex == 0 ? '今天值得使用' : '我的優惠'),
          ),
          body: currentIndex == 0
              ? TodayScreen(
                  store: widget.store,
                  reminders: widget.reminders,
                )
              : OfferListScreen(
                  store: widget.store,
                  reminders: widget.reminders,
                ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add-offer-button'),
            onPressed: () => _openAddOffer(context),
            icon: const Icon(Icons.add),
            label: const Text('新增優惠'),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => setState(() => currentIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today),
                label: '今日',
              ),
              NavigationDestination(
                icon: Icon(Icons.confirmation_number_outlined),
                selectedIcon: Icon(Icons.confirmation_number),
                label: '優惠清單',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAddOffer(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AddOfferScreen(
          store: widget.store,
          reminders: widget.reminders,
        ),
      ),
    );
  }
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    required this.store,
    required this.reminders,
    super.key,
  });

  final OfferStore store;
  final OfferReminderScheduler reminders;

  @override
  Widget build(BuildContext context) {
    final offers = store.activeOffers;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('先用快到期的', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '未來 7 天有 ${store.expiringWithinDays(7)} 張優惠即將到期',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('依到期日排序', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (offers.isEmpty)
          const _EmptyState(message: '目前沒有待使用的優惠')
        else
          ...offers.map(
            (offer) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OfferCard(
                offer: offer,
                onTap: () => _openDetails(context, offer),
              ),
            ),
          ),
      ],
    );
  }

  void _openDetails(BuildContext context, Offer offer) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OfferDetailsScreen(
          store: store,
          reminders: reminders,
          offerId: offer.id,
        ),
      ),
    );
  }
}

class OfferListScreen extends StatelessWidget {
  const OfferListScreen({
    required this.store,
    required this.reminders,
    super.key,
  });

  final OfferStore store;
  final OfferReminderScheduler reminders;

  @override
  Widget build(BuildContext context) {
    final active = store.activeOffers;
    final completed = store.completedOffers;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
      children: [
        Text('待使用（${active.length}）', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...active.map(
          (offer) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OfferCard(
              offer: offer,
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => OfferDetailsScreen(
                    store: store,
                    reminders: reminders,
                    offerId: offer.id,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('已完成（${completed.length}）', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (completed.isEmpty)
          const _EmptyState(message: '完成優惠後會顯示在這裡')
        else
          ...completed.map(
            (offer) => ListTile(
              leading: const Icon(Icons.check_circle, color: Color(0xFF2E7D5B)),
              title: Text(offer.name),
              subtitle: Text('到期日 ${formatTaiwanDate(offer.expiresAt)}'),
            ),
          ),
      ],
    );
  }
}

class AddOfferScreen extends StatefulWidget {
  const AddOfferScreen({
    required this.store,
    required this.reminders,
    super.key,
  });

  final OfferStore store;
  final OfferReminderScheduler reminders;

  @override
  State<AddOfferScreen> createState() => _AddOfferScreenState();
}

class _AddOfferScreenState extends State<AddOfferScreen> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final sourceController = TextEditingController();
  final noteController = TextEditingController();
  DateTime? expiresAt;
  bool reminderEnabled = true;
  DateTime? reminderAt;
  String? reminderError;

  @override
  void dispose() {
    nameController.dispose();
    sourceController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新增優惠')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('offer-name-field'),
              controller: nameController,
              decoration: const InputDecoration(labelText: '優惠名稱 *'),
              validator: (value) => value == null || value.trim().isEmpty ? '請輸入優惠名稱' : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              key: const Key('expiry-date-field'),
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '到期日 *',
                  errorText: expiresAt == null && attemptedSubmit ? '請選擇到期日' : null,
                ),
                child: Text(expiresAt == null ? '選擇日期' : formatTaiwanDate(expiresAt!)),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              key: const Key('reminder-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('到期提醒'),
              subtitle: Text(
                reminderEnabled
                    ? '在指定時間發送手機通知'
                    : '不發送這張優惠的通知',
              ),
              value: reminderEnabled,
              onChanged: (value) {
                setState(() {
                  reminderEnabled = value;
                  reminderError = null;
                  if (value && reminderAt == null && expiresAt != null) {
                    reminderAt = _defaultReminderAtFor(expiresAt!);
                  }
                });
              },
            ),
            if (reminderEnabled) ...[
              const SizedBox(height: 4),
              InkWell(
                key: const Key('reminder-date-time-field'),
                onTap: expiresAt == null ? null : _selectReminderDateTime,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '提醒日期與時間',
                    helperText: expiresAt == null ? '請先選擇到期日' : null,
                    errorText: reminderError,
                  ),
                  child: Text(
                    reminderAt == null
                        ? '選擇提醒日期與時間'
                        : formatTaiwanDateTime(reminderAt!),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: sourceController,
              decoration: const InputDecoration(labelText: '來源／品牌（選填）'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '備註（選填）'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('save-offer-button'),
              onPressed: isSaving ? null : _save,
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(isSaving ? '儲存中…' : '儲存優惠'),
            ),
          ],
        ),
      ),
    );
  }

  bool attemptedSubmit = false;
  bool isSaving = false;

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: expiresAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('zh', 'TW'),
    );
    if (selected != null) {
      setState(() {
        expiresAt = selected;
        reminderAt = _defaultReminderAtFor(selected);
        reminderError = null;
      });
    }
  }

  DateTime _defaultReminderAtFor(DateTime expiry) {
    final now = DateTime.now();
    final preferred = DateTime(expiry.year, expiry.month, expiry.day, 9)
        .subtract(const Duration(days: 1));
    if (preferred.isAfter(now)) return preferred;

    final soon = now.add(const Duration(minutes: 5));
    return DateTime(soon.year, soon.month, soon.day, soon.hour, soon.minute);
  }

  Future<void> _selectReminderDateTime() async {
    final expiry = expiresAt;
    if (expiry == null) return;

    final now = DateTime.now();
    final initial = reminderAt ?? _defaultReminderAtFor(expiry);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(expiry.year, expiry.month, expiry.day),
      locale: const Locale('zh', 'TW'),
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: '選擇提醒時間',
    );
    if (selectedTime == null) return;

    setState(() {
      reminderAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      reminderError = null;
    });
  }

  Future<void> _save() async {
    setState(() => attemptedSubmit = true);
    if (!(formKey.currentState?.validate() ?? false) || expiresAt == null) return;

    if (reminderEnabled) {
      final selectedReminder = reminderAt;
      final expiryEnd = DateTime(
        expiresAt!.year,
        expiresAt!.month,
        expiresAt!.day,
        23,
        59,
        59,
      );
      if (selectedReminder == null || !selectedReminder.isAfter(DateTime.now())) {
        setState(() => reminderError = '提醒時間必須晚於現在');
        return;
      }
      if (selectedReminder.isAfter(expiryEnd)) {
        setState(() => reminderError = '提醒時間不能晚於到期日');
        return;
      }
    }

    setState(() {
      isSaving = true;
      reminderError = null;
    });
    try {
      await widget.store.addOffer(
        name: nameController.text,
        expiresAt: expiresAt!,
        source: sourceController.text,
        note: noteController.text,
        reminderEnabled: reminderEnabled,
        reminderAt: reminderEnabled ? reminderAt : null,
      );

      var reminderFailed = false;
      var reminderPermissionDenied = false;
      try {
        if (reminderEnabled) {
          final granted = await widget.reminders.requestPermission();
          if (granted) {
            await widget.reminders.sync(widget.store.activeOffers);
          } else {
            reminderPermissionDenied = true;
          }
        } else {
          await widget.reminders.sync(widget.store.activeOffers);
        }
      } catch (_) {
        reminderFailed = true;
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      if (reminderFailed) {
        messenger.showSnackBar(
          const SnackBar(content: Text('優惠已儲存，但提醒設定失敗')),
        );
      } else if (reminderPermissionDenied) {
        messenger.showSnackBar(
          const SnackBar(content: Text('優惠已儲存；允許通知後才會收到提醒')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('儲存失敗，請稍後再試')),
      );
    }
  }
}

class OfferDetailsScreen extends StatelessWidget {
  const OfferDetailsScreen({
    required this.store,
    required this.reminders,
    required this.offerId,
    super.key,
  });

  final OfferStore store;
  final OfferReminderScheduler reminders;
  final String offerId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final allOffers = [...store.activeOffers, ...store.completedOffers];
        final offer = allOffers.where((item) => item.id == offerId).firstOrNull;
        if (offer == null) {
          return const Scaffold(body: Center(child: Text('找不到這筆優惠')));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('優惠詳情')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Icon(
                Icons.confirmation_number,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(offer.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              _DetailRow(label: '到期日', value: formatTaiwanDate(offer.expiresAt)),
              _DetailRow(
                label: '提醒',
                value: offer.reminderEnabled
                    ? formatTaiwanDateTime(offer.effectiveReminderAt)
                    : '已關閉',
              ),
              if (offer.source.isNotEmpty) _DetailRow(label: '來源', value: offer.source),
              if (offer.note.isNotEmpty) _DetailRow(label: '備註', value: offer.note),
              const SizedBox(height: 28),
              if (!offer.isCompleted)
                FilledButton.icon(
                  key: const Key('complete-offer-button'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await store.markCompleted(offer.id);
                      try {
                        await reminders.cancel(offer.id);
                      } catch (_) {
                        // Completion is saved even if reminder cancellation fails.
                      }
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('已標記完成，成功保住這份價值！')),
                      );
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('更新失敗，請稍後再試')),
                      );
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('標記為已使用'),
                )
              else
                const Chip(
                  avatar: Icon(Icons.check_circle),
                  label: Text('已完成'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.eco_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}

String formatTaiwanDateTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${formatTaiwanDate(value)} $hour:$minute';
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
