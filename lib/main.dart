import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'models/offer.dart';
import 'models/offer_backup.dart';
import 'models/offer_store.dart';
import 'offer_backup_file_service.dart';
import 'offer_reminder_service.dart';
import 'theme.dart';
import 'widgets/offer_card.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await OfferStore.load();
  final navigatorKey = GlobalKey<NavigatorState>();
  OfferReminderScheduler reminders = const NoopOfferReminderScheduler();

  void openOfferFromNotification(String offerId) {
    navigatorKey.currentState?.push<void>(
      MaterialPageRoute(
        builder: (_) => OfferDetailsScreen(
          store: store,
          reminders: reminders,
          offerId: offerId,
        ),
      ),
    );
  }

  try {
    reminders = await AndroidOfferReminderScheduler.create(
      onOfferSelected: openOfferFromNotification,
    );
    await reminders.sync(store.activeOffers);
  } catch (_) {
    // Notifications are optional; storage and the core app must still start.
  }
  runApp(
    CloverApp(
      store: store,
      reminders: reminders,
      navigatorKey: navigatorKey,
      initialOfferId: reminders.initialOfferId,
    ),
  );
}

class CloverApp extends StatefulWidget {
  const CloverApp({
    super.key,
    this.store,
    this.reminders = const NoopOfferReminderScheduler(),
    this.navigatorKey,
    this.initialOfferId,
    this.backupFiles,
  });

  final OfferStore? store;
  final OfferReminderScheduler reminders;
  final GlobalKey<NavigatorState>? navigatorKey;
  final String? initialOfferId;
  final OfferBackupFileService? backupFiles;

  @override
  State<CloverApp> createState() => _CloverAppState();
}

class _CloverAppState extends State<CloverApp> {
  late final OfferStore store = widget.store ?? OfferStore();
  late final OfferBackupFileService backupFiles =
      widget.backupFiles ?? FilePickerOfferBackupFileService();

  @override
  void initState() {
    super.initState();
    final offerId = widget.initialOfferId;
    if (offerId != null && offerId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.navigatorKey?.currentState?.push<void>(
          MaterialPageRoute(
            builder: (_) => OfferDetailsScreen(
              store: store,
              reminders: widget.reminders,
              offerId: offerId,
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    if (widget.store == null) store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: widget.navigatorKey,
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
      home: CloverHome(
        store: store,
        reminders: widget.reminders,
        backupFiles: backupFiles,
      ),
    );
  }
}

class CloverHome extends StatefulWidget {
  const CloverHome({
    required this.store,
    required this.reminders,
    required this.backupFiles,
    super.key,
  });

  final OfferStore store;
  final OfferReminderScheduler reminders;
  final OfferBackupFileService backupFiles;

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
            actions: [
              IconButton(
                key: const Key('backup-button'),
                tooltip: '資料備份與還原',
                onPressed: _showBackupOptions,
                icon: const Icon(Icons.save_alt),
              ),
              IconButton(
                key: const Key('app-info-button'),
                tooltip: '軟體資訊',
                onPressed: () => _showAppInfo(context),
                icon: const Icon(Icons.info_outline),
              ),
            ],
          ),
          body: currentIndex == 0
              ? TodayScreen(
                  store: widget.store,
                  reminders: widget.reminders,
                  onAddOffer: () => _openAddOffer(context),
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

  Future<void> _showAppInfo(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!context.mounted) return;
      showAboutDialog(
        context: context,
        applicationName: 'Project Clover',
        applicationVersion:
            '版本 ${packageInfo.version}（Build ${packageInfo.buildNumber}）',
        applicationIcon: Icon(
          Icons.eco,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        children: const [
          Text('協助你在到期前使用優惠，別讓已擁有的價值悄悄溜走。'),
          SizedBox(height: 8),
          Text('Prototype 測試版本'),
        ],
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目前無法讀取軟體版本')),
      );
    }
  }

  Future<void> _showBackupOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('資料備份與還原', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('備份檔只會存到你選擇的位置，不會上傳 Project Clover 伺服器。'),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('export-backup-button'),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _exportBackup();
                },
                icon: const Icon(Icons.download_outlined),
                label: const Text('匯出備份'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('import-backup-button'),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _importBackup();
                },
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('從備份還原'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    final now = DateTime.now();
    final date = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final content = OfferBackupCodec.encode(widget.store.allOffers, exportedAt: now);
    try {
      final saved = await widget.backupFiles.saveBackup(
        fileName: 'project-clover-backup-$date.json',
        content: content,
      );
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已備份 ${widget.store.allOffers.length} 筆優惠')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('備份失敗，請稍後再試')),
      );
    }
  }

  Future<void> _importBackup() async {
    try {
      final file = await widget.backupFiles.pickBackup();
      if (!mounted || file == null) return;
      final backup = OfferBackupCodec.decode(file.content);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('還原這份備份？'),
          content: Text(
            '備份時間：${formatTaiwanDateTime(backup.exportedAt)}\n'
            '待使用 ${backup.activeCount} 筆、已完成 ${backup.completedCount} 筆。\n\n'
            '還原後會取代手機目前的 ${widget.store.allOffers.length} 筆資料。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('confirm-import-backup-button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('確認還原'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;

      await widget.store.replaceAll(backup.offers);
      var remindersSynced = true;
      try {
        await widget.reminders.sync(widget.store.activeOffers);
      } catch (_) {
        remindersSynced = false;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remindersSynced
                ? '已還原 ${backup.offers.length} 筆優惠'
                : '資料已還原，但提醒同步失敗',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message.toString())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('還原失敗，請確認備份檔是否正確')),
      );
    }
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
    required this.onAddOffer,
    super.key,
  });

  final OfferStore store;
  final OfferReminderScheduler reminders;
  final VoidCallback onAddOffer;

  @override
  Widget build(BuildContext context) {
    final summary = store.dashboard();
    final myDay = store.myDay();
    final favorites = store.allOffers
        .where((offer) => offer.isFavorite && !offer.isCompleted)
        .toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    if (store.allOffers.isEmpty) {
      return _FirstExperience(onAddOffer: onAddOffer);
    }
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
              Text('My Day｜我的今天', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                myDay.recommendedToday == null
                    ? '今天沒有急著要用的優惠'
                    : '5 秒找到今天最值得先用的優惠',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _OfferSection(
          title: '今日推薦',
          emptyMessage: '今天沒有推薦項目',
          offers: myDay.recommendedToday == null
              ? const []
              : [myDay.recommendedToday!],
          store: store,
          reminders: reminders,
          cardKey: const Key('next-expiring-offer'),
        ),
        _OfferSection(
          title: '今天到期',
          emptyMessage: '今天沒有到期優惠',
          offers: myDay.expiringToday,
          store: store,
          reminders: reminders,
        ),
        _OfferSection(
          title: '明天到期',
          emptyMessage: '明天沒有到期優惠',
          offers: myDay.expiringTomorrow,
          store: store,
          reminders: reminders,
        ),
        _OfferSection(
          title: '本週必用',
          emptyMessage: '未來 2～7 天沒有到期優惠',
          offers: myDay.mustUseThisWeek,
          store: store,
          reminders: reminders,
        ),
        _OfferSection(
          title: '我的收藏',
          emptyMessage: '尚未收藏優惠',
          offers: favorites,
          store: store,
          reminders: reminders,
        ),
        const SizedBox(height: 8),
        Text('優惠總覽', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        GridView.count(
          key: const Key('dashboard-metrics'),
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.25,
          children: [
            _DashboardMetric(
              key: const Key('dashboard-today'),
              label: '今天到期',
              value: summary.expiringToday,
            ),
            _DashboardMetric(
              key: const Key('dashboard-three-days'),
              label: '3 天內到期',
              value: summary.expiringWithinThreeDays,
            ),
            _DashboardMetric(
              key: const Key('dashboard-seven-days'),
              label: '7 天內到期',
              value: summary.expiringWithinSevenDays,
            ),
            _DashboardMetric(
              key: const Key('dashboard-completed'),
              label: '已完成',
              value: summary.completed,
            ),
            _DashboardMetric(
              key: const Key('dashboard-total'),
              label: '全部優惠',
              value: summary.total,
            ),
          ],
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

class _OfferSection extends StatelessWidget {
  const _OfferSection({
    required this.title,
    required this.emptyMessage,
    required this.offers,
    required this.store,
    required this.reminders,
    this.cardKey,
  });

  final String title;
  final String emptyMessage;
  final List<Offer> offers;
  final OfferStore store;
  final OfferReminderScheduler reminders;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (offers.isEmpty)
            Text(emptyMessage, style: Theme.of(context).textTheme.bodySmall)
          else
            ...offers.take(5).map(
                  (offer) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OfferCard(
                      key: offer == offers.first ? cardKey : null,
                      offer: offer,
                      onFavorite: () => store.toggleFavorite(offer.id),
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
        ],
      ),
    );
  }
}

class _FirstExperience extends StatelessWidget {
  const _FirstExperience({required this.onAddOffer});

  final VoidCallback onAddOffer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.eco_outlined,
              size: 88,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text('別讓優惠悄悄過期', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text(
              '加入第一張優惠，Project Clover 會每天告訴你該先用哪一張。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('add-first-offer-button'),
              onPressed: onAddOffer,
              icon: const Icon(Icons.add),
              label: const Text('新增第一張優惠'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class OfferListScreen extends StatefulWidget {
  const OfferListScreen({
    required this.store,
    required this.reminders,
    super.key,
  });

  final OfferStore store;
  final OfferReminderScheduler reminders;

  @override
  State<OfferListScreen> createState() => _OfferListScreenState();
}

class _OfferListScreenState extends State<OfferListScreen> {
  final searchController = TextEditingController();
  OfferFilter filter = OfferFilter.all;
  OfferCategory? category;
  final Set<String> selectedIds = {};
  bool selectionMode = false;

  bool get isSelecting => selectionMode;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offers = widget.store.queryOffers(
      query: searchController.text,
      filter: filter,
      category: category,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
      children: [
        TextField(
          key: const Key('offer-search-field'),
          controller: searchController,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: '搜尋優惠',
            hintText: '名稱、來源或備註',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    key: const Key('clear-search-button'),
                    tooltip: '清除搜尋',
                    onPressed: () {
                      searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<OfferFilter>(
                key: const Key('offer-filter-field'),
                initialValue: filter,
                decoration: const InputDecoration(
                  labelText: '篩選',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                items: OfferFilter.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_filterLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => filter = value);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<OfferSortOption>(
                key: const Key('offer-sort-field'),
                initialValue: widget.store.sortOption,
                decoration: const InputDecoration(
                  labelText: '排序',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                items: OfferSortOption.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_sortLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  try {
                    await widget.store.setSortOption(value);
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('無法儲存排序設定')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<OfferCategory?>(
                key: const Key('offer-category-filter-field'),
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: '分類',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('全部分類')),
                  ...OfferCategory.values.map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(offerCategoryLabel(value)),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => category = value),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              key: const Key('batch-select-button'),
              onPressed: () => setState(() {
                selectionMode = !selectionMode;
                if (!selectionMode) selectedIds.clear();
              }),
              icon: Icon(isSelecting ? Icons.close : Icons.checklist),
              label: Text(isSelecting ? '取消選取' : '批次操作'),
            ),
          ],
        ),
        if (isSelecting) ...[
          const SizedBox(height: 10),
          _BatchToolbar(
            count: selectedIds.length,
            onDelete: () => _runBatch(_BatchAction.delete),
            onComplete: () => _runBatch(_BatchAction.complete),
            onRestore: () => _runBatch(_BatchAction.restore),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          '找到 ${offers.length} 張優惠',
          key: const Key('offer-result-count'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (offers.isEmpty)
          const _EmptyState(message: '沒有符合搜尋或篩選條件的優惠')
        else
          ...offers.map(
            (offer) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OfferCard(
                offer: offer,
                selectionMode: isSelecting,
                isSelected: selectedIds.contains(offer.id),
                onFavorite: () => widget.store.toggleFavorite(offer.id),
                onLongPress: () => _toggleSelected(offer.id),
                onTap: () {
                  if (isSelecting) {
                    _toggleSelected(offer.id);
                    return;
                  }
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => OfferDetailsScreen(
                        store: widget.store,
                        reminders: widget.reminders,
                        offerId: offer.id,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  String _filterLabel(OfferFilter value) => switch (value) {
        OfferFilter.all => '全部',
        OfferFilter.expiringToday => '今天到期',
        OfferFilter.expiringWithinSevenDays => '7 天內到期',
        OfferFilter.expired => '已過期',
        OfferFilter.completed => '已完成',
        OfferFilter.reminderEnabled => '提醒開啟',
        OfferFilter.reminderDisabled => '提醒關閉',
        OfferFilter.favorites => '我的收藏',
      };

  String _sortLabel(OfferSortOption value) => switch (value) {
        OfferSortOption.expirationAscending => '到期日近→遠',
        OfferSortOption.expirationDescending => '到期日遠→近',
        OfferSortOption.createdNewest => '最新建立',
        OfferSortOption.createdOldest => '最早建立',
        OfferSortOption.recentlyModified => '最近修改',
      };

  void _toggleSelected(String id) {
    setState(() {
      selectionMode = true;
      if (!selectedIds.add(id)) selectedIds.remove(id);
    });
  }

  Future<void> _runBatch(_BatchAction action) async {
    final ids = Set<String>.from(selectedIds);
    if (ids.isEmpty) return;
    if (action == _BatchAction.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('刪除 ${ids.length} 張優惠？'),
          content: const Text('刪除後無法復原。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('confirm-batch-delete-button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('確認刪除'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      switch (action) {
        case _BatchAction.delete:
          await widget.store.deleteOffers(ids);
          break;
        case _BatchAction.complete:
          await widget.store.markOffersCompleted(ids);
          break;
        case _BatchAction.restore:
          await widget.store.restoreOffers(ids);
          break;
      }
      try {
        await widget.reminders.sync(widget.store.activeOffers);
      } catch (_) {
        // Data changes remain valid even if Android reminder sync fails.
      }
      if (!mounted) return;
      setState(() {
        selectedIds.clear();
        selectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已完成 ${ids.length} 張優惠的批次操作')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('批次操作失敗，資料未變更')),
      );
    }
  }
}

enum _BatchAction { delete, complete, restore }

class _BatchToolbar extends StatelessWidget {
  const _BatchToolbar({
    required this.count,
    required this.onDelete,
    required this.onComplete,
    required this.onRestore,
  });

  final int count;
  final VoidCallback onDelete;
  final VoidCallback onComplete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('已選 $count 張'),
            TextButton.icon(
              key: const Key('batch-complete-button'),
              onPressed: onComplete,
              icon: const Icon(Icons.check),
              label: const Text('完成'),
            ),
            TextButton.icon(
              key: const Key('batch-restore-button'),
              onPressed: onRestore,
              icon: const Icon(Icons.undo),
              label: const Text('恢復'),
            ),
            TextButton.icon(
              key: const Key('batch-delete-button'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('刪除'),
            ),
          ],
        ),
      ),
    );
  }
}

class AddOfferScreen extends StatefulWidget {
  const AddOfferScreen({
    required this.store,
    required this.reminders,
    this.offer,
    super.key,
  });

  final OfferStore store;
  final OfferReminderScheduler reminders;
  final Offer? offer;

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
  int reminderDaysBefore = 1;
  TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0);
  String? reminderError;
  bool isFavorite = false;
  OfferCategory category = OfferCategory.others;

  bool get isEditing => widget.offer != null;

  @override
  void initState() {
    super.initState();
    final offer = widget.offer;
    if (offer == null) return;

    nameController.text = offer.name;
    sourceController.text = offer.source;
    noteController.text = offer.note;
    expiresAt = offer.expiresAt;
    reminderEnabled = offer.reminderEnabled;
    reminderDaysBefore = offer.reminderDaysBefore;
    reminderTime = TimeOfDay(
      hour: offer.reminderHour,
      minute: offer.reminderMinute,
    );
    isFavorite = offer.isFavorite;
    category = offer.category;
  }

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
      appBar: AppBar(title: Text(isEditing ? '編輯優惠' : '新增優惠')),
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
            const SizedBox(height: 16),
            DropdownButtonFormField<OfferCategory>(
              key: const Key('offer-category-field'),
              initialValue: category,
              decoration: const InputDecoration(labelText: '分類'),
              items: OfferCategory.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(offerCategoryLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => category = value);
              },
            ),
            SwitchListTile.adaptive(
              key: const Key('favorite-switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('加入收藏'),
              subtitle: const Text('收藏優惠會優先出現在 My Day'),
              value: isFavorite,
              onChanged: (value) => setState(() => isFavorite = value),
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
                });
              },
            ),
            if (reminderEnabled) ...[
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                key: const Key('reminder-days-field'),
                initialValue: reminderDaysBefore,
                decoration: const InputDecoration(labelText: '提前提醒'),
                items: Offer.supportedReminderDays
                    .map(
                      (days) => DropdownMenuItem(
                        value: days,
                        child: Text('$days 天前'),
                      ),
                    )
                    .toList(),
                onChanged: (days) {
                  if (days == null) return;
                  setState(() {
                    reminderDaysBefore = days;
                    reminderError = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                key: const Key('reminder-time-field'),
                onTap: _selectReminderTime,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '提醒時間',
                    errorText: reminderError,
                  ),
                  child: Text(formatTaiwanTime(reminderTime)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '切換提前天數時，提醒時間會維持不變',
                style: Theme.of(context).textTheme.bodySmall,
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
              label: Text(
                isSaving
                    ? '儲存中…'
                    : isEditing
                        ? '儲存變更'
                        : '儲存優惠',
              ),
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
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('zh', 'TW'),
    );
    if (selected != null) {
      setState(() {
        expiresAt = selected;
        reminderError = null;
      });
    }
  }

  Future<void> _selectReminderTime() async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: reminderTime,
      helpText: '選擇提醒時間',
    );
    if (selectedTime == null) return;

    setState(() {
      reminderTime = selectedTime;
      reminderError = null;
    });
  }

  DateTime _selectedReminderAt() {
    final expiry = expiresAt!;
    return DateTime(
      expiry.year,
      expiry.month,
      expiry.day,
      reminderTime.hour,
      reminderTime.minute,
    ).subtract(Duration(days: reminderDaysBefore));
  }

  Future<void> _save() async {
    setState(() => attemptedSubmit = true);
    if (!(formKey.currentState?.validate() ?? false) || expiresAt == null) return;

    if (reminderEnabled && !_selectedReminderAt().isAfter(DateTime.now())) {
      setState(
        () => reminderError =
            '提前 $reminderDaysBefore 天的 ${formatTaiwanTime(reminderTime)} 已經過了',
      );
      return;
    }

    setState(() {
      isSaving = true;
      reminderError = null;
    });
    try {
      final offer = widget.offer;
      if (offer == null) {
        await widget.store.addOffer(
          name: nameController.text,
          expiresAt: expiresAt!,
          source: sourceController.text,
          note: noteController.text,
          reminderEnabled: reminderEnabled,
          reminderDaysBefore: reminderDaysBefore,
          reminderHour: reminderTime.hour,
          reminderMinute: reminderTime.minute,
          isFavorite: isFavorite,
          category: category,
        );
      } else {
        await widget.store.updateOffer(
          id: offer.id,
          name: nameController.text,
          expiresAt: expiresAt!,
          source: sourceController.text,
          note: noteController.text,
          reminderEnabled: reminderEnabled,
          reminderDaysBefore: reminderDaysBefore,
          reminderHour: reminderTime.hour,
          reminderMinute: reminderTime.minute,
          isFavorite: isFavorite,
          category: category,
        );
      }

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
      } else if (isEditing) {
        messenger.showSnackBar(
          const SnackBar(content: Text('優惠已更新')),
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
              _DetailRow(label: '分類', value: offerCategoryLabel(offer.category)),
              _DetailRow(label: '收藏', value: offer.isFavorite ? '已收藏' : '未收藏'),
              _DetailRow(
                label: '提醒',
                value: offer.reminderEnabled
                    ? '提前 ${offer.reminderDaysBefore} 天・'
                        '${formatTaiwanTime(TimeOfDay(
                          hour: offer.reminderHour,
                          minute: offer.reminderMinute,
                        ))}'
                    : '已關閉',
              ),
              if (offer.source.isNotEmpty) _DetailRow(label: '來源', value: offer.source),
              if (offer.note.isNotEmpty) _DetailRow(label: '備註', value: offer.note),
              if (offer.isCompleted)
                _DetailRow(
                  label: '完成時間',
                  value: offer.completedAt == null
                      ? '未記錄（舊版資料）'
                      : formatTaiwanDateTime(offer.completedAt!),
                ),
              const SizedBox(height: 28),
              if (!offer.isCompleted) ...[
                OutlinedButton.icon(
                  key: const Key('edit-offer-button'),
                  onPressed: () => _editOffer(context, offer),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('編輯優惠'),
                ),
                const SizedBox(height: 12),
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
                ),
              ] else ...[
                const Chip(
                  avatar: Icon(Icons.check_circle),
                  label: Text('已完成'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('restore-offer-button'),
                  onPressed: () => _restoreOffer(context, offer),
                  icon: const Icon(Icons.undo),
                  label: const Text('恢復為待使用'),
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('delete-offer-button'),
                onPressed: () => _deleteOffer(context, offer),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('刪除優惠'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editOffer(BuildContext context, Offer offer) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AddOfferScreen(
          store: store,
          reminders: reminders,
          offer: offer,
        ),
      ),
    );
  }

  Future<void> _deleteOffer(BuildContext context, Offer offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除這張優惠？'),
        content: Text('「${offer.name}」刪除後無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-delete-offer-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('確認刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await store.deleteOffer(offer.id);
      try {
        await reminders.cancel(offer.id);
      } catch (_) {
        // Deletion is saved even if reminder cancellation fails.
      }
      if (!context.mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('優惠已刪除')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('刪除失敗，請稍後再試')),
      );
    }
  }

  Future<void> _restoreOffer(BuildContext context, Offer offer) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await store.restoreOffer(offer.id);
      try {
        await reminders.sync(store.activeOffers);
      } catch (_) {
        // Restoration is saved even if notification synchronization fails.
      }
      if (!context.mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('已恢復為待使用優惠')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('恢復失敗，請稍後再試')),
      );
    }
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
  return '${formatTaiwanDate(value)} '
      '${formatTaiwanTime(TimeOfDay.fromDateTime(value))}';
}

String formatTaiwanTime(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String offerCategoryLabel(OfferCategory value) => switch (value) {
      OfferCategory.food => '餐飲',
      OfferCategory.coffee => '咖啡',
      OfferCategory.convenienceStore => '便利商店',
      OfferCategory.departmentStore => '百貨公司',
      OfferCategory.onlineShopping => '線上購物',
      OfferCategory.entertainment => '娛樂',
      OfferCategory.travel => '旅遊',
      OfferCategory.transportation => '交通',
      OfferCategory.others => '其他',
    };

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
