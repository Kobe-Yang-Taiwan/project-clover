import 'dart:io';

import 'package:flutter/material.dart';

import '../models/offer.dart';
import '../models/offer_store.dart';
import '../offer_reminder_service.dart';
import 'coupon_import_models.dart';
import 'coupon_parser.dart';
import 'local_import_service.dart';

class ImportChoiceSheet extends StatelessWidget {
  const ImportChoiceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('manual-entry-choice'),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('手動輸入'),
              subtitle: const Text('使用原本的新增優惠表單'),
              onTap: () => Navigator.of(context).pop(ImportChoice.manual),
            ),
            ListTile(
              key: const Key('image-import-choice'),
              leading: const Icon(Icons.image_outlined),
              title: const Text('匯入圖片'),
              subtitle: const Text('在手機內辨識截圖，不上傳檔案'),
              onTap: () => Navigator.of(context).pop(ImportChoice.image),
            ),
            ListTile(
              key: const Key('pdf-import-choice'),
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('匯入 PDF'),
              subtitle: const Text('逐頁辨識後，由你挑選要建立的優惠'),
              onTap: () => Navigator.of(context).pop(ImportChoice.pdf),
            ),
          ],
        ),
      ),
    );
  }
}

enum ImportChoice { manual, image, pdf }

class ImageImportScreen extends StatefulWidget {
  const ImageImportScreen({
    required this.path,
    required this.service,
    required this.store,
    required this.reminders,
    this.parser = const CouponParser(),
    super.key,
  });

  final String path;
  final CouponImportService service;
  final OfferStore store;
  final OfferReminderScheduler reminders;
  final CouponParser parser;

  @override
  State<ImageImportScreen> createState() => _ImageImportScreenState();
}

class _ImageImportScreenState extends State<ImageImportScreen> {
  String? error;

  @override
  void initState() {
    super.initState();
    _process();
  }

  Future<void> _process() async {
    final result = await widget.service.recognizeImage(widget.path);
    if (!mounted) return;
    if (!result.succeeded) {
      setState(() => error = '無法辨識這張圖片，請換一張較清楚的圖片。');
      return;
    }
    final parsed = widget.parser.parsePagesDetailed([result]);
    if (parsed.candidates.isEmpty) {
      setState(() => error = '圖片中沒有可供檢查的商品優惠。');
      return;
    }
    final candidates = _markDuplicates(
      parsed.candidates,
      widget.store.allOffers,
    );
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => BatchReviewScreen(
          candidates: candidates,
          failedPages: 0,
          qualityReport: parsed.report,
          imagePath: widget.path,
          store: widget.store,
          reminders: widget.reminders,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('檢查匯入內容')),
      body: error != null
          ? _ImportError(message: error!, onRetry: () => Navigator.pop(context))
          : const _ImportLoading(label: '正在本機辨識圖片…'),
    );
  }
}

class PdfImportScreen extends StatefulWidget {
  const PdfImportScreen({
    required this.path,
    required this.service,
    required this.store,
    required this.reminders,
    this.parser = const CouponParser(),
    super.key,
  });

  final String path;
  final CouponImportService service;
  final OfferStore store;
  final OfferReminderScheduler reminders;
  final CouponParser parser;

  @override
  State<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends State<PdfImportScreen> {
  ImportProgress progress = const ImportProgress(completed: 0, total: 1);
  bool cancelled = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _process();
  }

  Future<void> _process() async {
    try {
      final pages = await widget.service.recognizePdf(
        widget.path,
        onProgress: (value) {
          if (mounted) setState(() => progress = value);
        },
        isCancelled: () => cancelled,
      );
      if (!mounted || cancelled) return;
      final parsed = widget.parser.parsePagesDetailed(pages);
      final candidates = _markDuplicates(
        parsed.candidates,
        widget.store.allOffers,
      );
      if (candidates.isEmpty) {
        setState(() => error = 'PDF 中沒有可供檢查的優惠內容。');
        return;
      }
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => BatchReviewScreen(
            candidates: candidates,
            failedPages: pages.where((page) => !page.succeeded).length,
            qualityReport: parsed.report,
            store: widget.store,
            reminders: widget.reminders,
          ),
        ),
      );
    } on ImportCancelledException {
      if (mounted) Navigator.of(context).pop();
    } on ImportLimitException catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } on FormatException catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } catch (_) {
      if (mounted) setState(() => error = 'PDF 處理失敗，既有優惠沒有變更。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = progress.total == 0 ? 1 : progress.total;
    return Scaffold(
      appBar: AppBar(title: const Text('處理 PDF')),
      body: error != null
          ? _ImportError(message: error!, onRetry: () => Navigator.pop(context))
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: progress.completed / total,
                    ),
                    const SizedBox(height: 20),
                    Text('正在本機處理第 ${progress.completed}／${progress.total} 頁'),
                    const SizedBox(height: 8),
                    const Text('圖片、PDF 與辨識文字都不會上傳。'),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      key: const Key('cancel-pdf-processing'),
                      onPressed: () => setState(() => cancelled = true),
                      child: const Text('取消處理'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class CandidateEditor extends StatefulWidget {
  const CandidateEditor({
    required this.candidate,
    required this.store,
    required this.reminders,
    this.imagePath,
    this.onUpdated,
    super.key,
  });

  final CouponCandidate candidate;
  final String? imagePath;
  final OfferStore store;
  final OfferReminderScheduler reminders;
  final ValueChanged<CouponCandidate>? onUpdated;

  @override
  State<CandidateEditor> createState() => _CandidateEditorState();
}

class _CandidateEditorState extends State<CandidateEditor> {
  final formKey = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.candidate.title);
  late final merchant = TextEditingController(text: widget.candidate.merchant);
  late final brand = TextEditingController(text: widget.candidate.brand);
  late final description = TextEditingController(
    text: widget.candidate.offerDescription,
  );
  late final originalPrice = TextEditingController(
    text: widget.candidate.originalPrice?.toString() ?? '',
  );
  late final promotionalPrice = TextEditingController(
    text: widget.candidate.promotionalPrice?.toString() ?? '',
  );
  late final conditions = TextEditingController(
    text: widget.candidate.promotionConditions.join('、'),
  );
  late DateTime? expiration = widget.candidate.expirationDate;
  late OfferCategory category = widget.candidate.category;
  late bool reminderEnabled = widget.store.reminderDefaults.enabled;
  bool attempted = false;
  bool saving = false;

  @override
  void dispose() {
    title.dispose();
    merchant.dispose();
    brand.dispose();
    description.dispose();
    originalPrice.dispose();
    promotionalPrice.dispose();
    conditions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.imagePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(widget.imagePath!),
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.privacy_tip_outlined),
              title: Text('全程在這支手機處理'),
              subtitle: Text('儲存前請務必核對辨識結果，原始圖片不會存入優惠。'),
            ),
          ),
          if (widget.candidate.needsReview)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: const Text('需要你確認'),
                subtitle: Text(widget.candidate.attentionFields.join('、')),
              ),
            ),
          TextFormField(
            key: const Key('import-title-field'),
            controller: title,
            decoration: _fieldDecoration('優惠名稱 *', '商品名稱'),
            validator: (text) =>
                text == null || text.trim().isEmpty ? '請輸入優惠名稱' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: merchant,
            key: const Key('import-merchant-field'),
            decoration: _fieldDecoration('商家／來源 *', '商家'),
            validator: (text) =>
                text == null || text.trim().isEmpty ? '請確認商家／來源' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: brand,
            decoration: const InputDecoration(labelText: '品牌'),
          ),
          const SizedBox(height: 12),
          InkWell(
            key: const Key('import-expiry-field'),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '到期日 *',
                labelStyle: _isProblem('到期日')
                    ? TextStyle(color: Theme.of(context).colorScheme.error)
                    : null,
                border: _isProblem('到期日')
                    ? OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : null,
                errorText: attempted && expiration == null ? '請確認到期日' : null,
              ),
              child: Text(expiration == null ? '尚未辨識，請選擇' : _date(expiration!)),
            ),
          ),
          if (widget.candidate.alternativeDates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '其他可能日期：${widget.candidate.alternativeDates.map(_date).join('、')}',
              ),
            ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('import-original-price-field'),
            controller: originalPrice,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '原價（未提供可留空）'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('import-promotional-price-field'),
            controller: promotionalPrice,
            keyboardType: TextInputType.number,
            decoration: _fieldDecoration('優惠價', '優惠價'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: conditions,
            decoration: const InputDecoration(labelText: '優惠條件'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<OfferCategory>(
            initialValue: category,
            decoration: const InputDecoration(labelText: '分類'),
            items: <OfferCategory>{category, ...controlledOfferCategories}
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(_category(item)),
                  ),
                )
                .toList(),
            onChanged: (item) {
              if (item != null) setState(() => category = item);
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('到期提醒'),
            subtitle: const Text('使用目前的全域提醒預設'),
            value: reminderEnabled,
            onChanged: (enabled) => setState(() => reminderEnabled = enabled),
          ),
          TextFormField(
            controller: description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '優惠說明／備註'),
          ),
          ExpansionTile(
            title: const Text('查看辨識原文'),
            children: [
              SelectableText(
                widget.candidate.rawText.isEmpty
                    ? '沒有辨識文字'
                    : widget.candidate.rawText,
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('confirm-import-coupon'),
            onPressed: saving ? null : _submit,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(widget.onUpdated == null ? '確認並建立優惠' : '套用修改'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: expiration ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('zh', 'TW'),
    );
    if (result != null) setState(() => expiration = result);
  }

  Future<void> _submit() async {
    setState(() => attempted = true);
    if (!(formKey.currentState?.validate() ?? false) || expiration == null)
      return;
    final parsedOriginal = int.tryParse(originalPrice.text.replaceAll(',', ''));
    final parsedPromotional = int.tryParse(
      promotionalPrice.text.replaceAll(',', ''),
    );
    final updated = widget.candidate.copyWith(
      title: title.text.trim(),
      merchant: merchant.text.trim(),
      brand: brand.text.trim(),
      expirationDate: expiration,
      offerDescription: description.text.trim(),
      originalPrice: parsedOriginal,
      promotionalPrice: parsedPromotional,
      clearOriginalPrice: originalPrice.text.trim().isEmpty,
      clearPromotionalPrice: promotionalPrice.text.trim().isEmpty,
      savings: parsedOriginal != null && parsedPromotional != null
          ? parsedOriginal - parsedPromotional
          : widget.candidate.savings,
      clearSavings: parsedOriginal == null || parsedPromotional == null,
      promotionConditions: conditions.text
          .split(RegExp(r'[、\n]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      category: category,
      attentionFields: const [],
      state: CandidateState.ready,
      selected: true,
    );
    if (widget.onUpdated != null) {
      widget.onUpdated!(updated);
      Navigator.of(context).pop();
      return;
    }
    setState(() => saving = true);
    try {
      final offer = await widget.store.addOffer(
        name: updated.title,
        expiresAt: expiration!,
        source: updated.merchant,
        note: _note(updated),
        reminderEnabled: reminderEnabled,
        category: updated.category,
      );
      if (reminderEnabled) {
        final granted = await widget.reminders.requestPermission();
        if (granted) await widget.reminders.sync(widget.store.activeOffers);
      }
      if (!mounted) return;
      Navigator.of(context).pop(offer);
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('匯入失敗，既有優惠沒有變更。')));
    }
  }

  bool _isProblem(String field) =>
      widget.candidate.attentionFields.any((reason) => reason.contains(field));

  InputDecoration _fieldDecoration(String label, String field) =>
      InputDecoration(
        labelText: label,
        labelStyle: _isProblem(field)
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
        enabledBorder: _isProblem(field)
            ? OutlineInputBorder(
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            : null,
      );
}

class BatchReviewScreen extends StatefulWidget {
  const BatchReviewScreen({
    required this.candidates,
    required this.failedPages,
    required this.store,
    required this.reminders,
    this.qualityReport,
    this.imagePath,
    super.key,
  });

  final List<CouponCandidate> candidates;
  final int failedPages;
  final OfferStore store;
  final OfferReminderScheduler reminders;
  final ImportQualityReport? qualityReport;
  final String? imagePath;

  @override
  State<BatchReviewScreen> createState() => _BatchReviewScreenState();
}

class _BatchReviewScreenState extends State<BatchReviewScreen> {
  late List<CouponCandidate> candidates = List.from(widget.candidates)
    ..sort((a, b) {
      if (a.needsReview != b.needsReview) return a.needsReview ? -1 : 1;
      return a.id.compareTo(b.id);
    });
  bool needsReviewOnly = false;
  bool saving = false;

  List<CouponCandidate> get visible => needsReviewOnly
      ? candidates.where((candidate) => candidate.needsReview).toList()
      : candidates;

  @override
  Widget build(BuildContext context) {
    final selected = candidates.where((candidate) => candidate.selected).length;
    final selectedNeedsReview = candidates
        .where((candidate) => candidate.selected && candidate.needsReview)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('選擇要匯入的優惠')),
      body: Column(
        children: [
          if (widget.failedPages > 0)
            MaterialBanner(
              content: Text('${widget.failedPages} 頁辨識失敗，其餘頁面仍可繼續檢查。'),
              actions: [TextButton(onPressed: () {}, child: const Text('知道了'))],
            ),
          if (widget.qualityReport != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '可直接匯入 ${widget.qualityReport!.readyCount} 筆・'
                  '需要確認 ${widget.qualityReport!.needsReviewCount} 筆・'
                  '已排除 ${widget.qualityReport!.rejectedCount} 筆',
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => _selectAll(true),
                  child: const Text('全選'),
                ),
                TextButton(
                  onPressed: () => _selectAll(false),
                  child: const Text('全部取消'),
                ),
                FilterChip(
                  label: const Text('只看需要確認'),
                  selected: needsReviewOnly,
                  onSelected: (value) =>
                      setState(() => needsReviewOnly = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final candidate = visible[index];
                return CheckboxListTile(
                  key: Key('candidate-${candidate.id}'),
                  value: candidate.selected,
                  onChanged: (value) =>
                      _replace(candidate.copyWith(selected: value ?? false)),
                  title: Text(
                    candidate.title.isEmpty ? '未辨識名稱' : candidate.title,
                    style: candidate.needsReview
                        ? TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700,
                          )
                        : null,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          if (candidate.merchant.isNotEmpty) candidate.merchant,
                          if (candidate.expirationDate != null)
                            '到期 ${_date(candidate.expirationDate!)}',
                          if (candidate.sourcePage != null)
                            '第 ${candidate.sourcePage} 頁',
                          if (candidate.isBatchDuplicate ||
                              candidate.isExistingDuplicate)
                            '疑似重複',
                        ].join('・'),
                      ),
                      if (candidate.needsReview)
                        Text(
                          candidate.attentionFields.join('、'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                  secondary: IconButton(
                    tooltip: '編輯',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(candidate),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('已選擇 $selected 筆，其中 $selectedNeedsReview 筆需要確認'),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('batch-import-button'),
                        onPressed: selected == 0 || saving
                            ? null
                            : _confirmImport,
                        child: Text(
                          selectedNeedsReview == 0
                              ? '匯入 $selected 筆優惠'
                              : '確認 $selectedNeedsReview 筆後匯入',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectAll(bool value) => setState(() {
    candidates = candidates
        .map((candidate) => candidate.copyWith(selected: value))
        .toList();
  });

  void _replace(CouponCandidate value) => setState(() {
    final index = candidates.indexWhere(
      (candidate) => candidate.id == value.id,
    );
    candidates[index] = value;
  });

  Future<void> _edit(CouponCandidate candidate) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('編輯候選優惠')),
          body: CandidateEditor(
            candidate: candidate,
            imagePath: widget.imagePath,
            store: widget.store,
            reminders: widget.reminders,
            onUpdated: _replace,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmImport() async {
    var selected = candidates.where((candidate) => candidate.selected).toList();
    final unresolved = selected
        .where((candidate) => candidate.needsReview)
        .toList();
    for (var index = 0; index < unresolved.length; index++) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('還有 ${unresolved.length - index} 筆需要確認')),
      );
      await _edit(unresolved[index]);
    }
    selected = candidates.where((candidate) => candidate.selected).toList();
    final invalid = selected
        .where((candidate) => !candidate.passesFinalValidation)
        .length;
    if (invalid > 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('仍有 $invalid 筆關鍵資料未確認，尚未寫入或建立提醒。')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('匯入 ${selected.length} 張優惠？'),
        content: const Text('確認後才會寫入手機，並依目前的提醒預設建立通知。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('返回檢查'),
          ),
          FilledButton(
            key: const Key('confirm-batch-import'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認匯入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => saving = true);
    try {
      await widget.store.addOffers(
        selected
            .map(
              (candidate) => NewOfferData(
                name: candidate.title,
                expiresAt: candidate.expirationDate!,
                source: candidate.merchant,
                note: _note(candidate),
                category: candidate.category,
                requiresValidatedImport: true,
              ),
            )
            .toList(),
      );
      final granted = await widget.reminders.requestPermission();
      if (granted) await widget.reminders.sync(widget.store.activeOffers);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已匯入 ${selected.length} 張優惠')));
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('批次匯入失敗，既有資料沒有變更。')));
    }
  }
}

class _ImportLoading extends StatelessWidget {
  const _ImportLoading({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(label),
      ],
    ),
  );
}

class _ImportError extends StatelessWidget {
  const _ImportError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(onPressed: onRetry, child: const Text('重新選擇')),
        ],
      ),
    ),
  );
}

List<CouponCandidate> _markDuplicates(
  List<CouponCandidate> values,
  List<Offer> existing,
) {
  String fingerprint(
    String title,
    String merchant,
    DateTime? date,
    String value,
  ) =>
      '${title.trim().toLowerCase()}|${merchant.trim().toLowerCase()}|${date?.toIso8601String().split('T').first}|${value.trim().toLowerCase()}';
  final seen = <String>{};
  return values.map((candidate) {
    final key = fingerprint(
      candidate.title,
      candidate.merchant,
      candidate.expirationDate,
      candidate.valueText,
    );
    final batchDuplicate =
        key.replaceAll('|null|', '||').isNotEmpty && !seen.add(key);
    final existingDuplicate = existing.any(
      (
        offer,
      ) => fingerprint(offer.name, offer.source, offer.expiresAt, '').startsWith(
        '${candidate.title.trim().toLowerCase()}|${candidate.merchant.trim().toLowerCase()}|${candidate.expirationDate?.toIso8601String().split('T').first}|',
      ),
    );
    return candidate.copyWith(
      selected: !(batchDuplicate || existingDuplicate),
      isBatchDuplicate: batchDuplicate,
      isExistingDuplicate: existingDuplicate,
      state: batchDuplicate || existingDuplicate
          ? CandidateState.needsReview
          : candidate.state,
      attentionFields: batchDuplicate || existingDuplicate
          ? {...candidate.attentionFields, '疑似重複商品'}.toList()
          : candidate.attentionFields,
    );
  }).toList();
}

String _note(CouponCandidate candidate) => [
  if (candidate.originalPrice != null)
    '原價：${candidate.originalPrice} 元'
  else
    '原價：未提供',
  if (candidate.promotionalPrice != null) '優惠價：${candidate.promotionalPrice} 元',
  if (candidate.savings != null) '共省：${candidate.savings} 元',
  if (candidate.promotionConditions.isNotEmpty)
    '優惠條件：${candidate.promotionConditions.join('、')}',
  if (candidate.specification.isNotEmpty) '商品規格：${candidate.specification}',
  if (candidate.brand.isNotEmpty) '品牌：${candidate.brand}',
  if (candidate.itemNumber.isNotEmpty) 'ITEM：${candidate.itemNumber}',
  if (candidate.offerDescription.isNotEmpty) candidate.offerDescription,
].join('\n');

String _date(DateTime value) =>
    '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';

String _category(OfferCategory value) => switch (value) {
  OfferCategory.foodAndDrink => '食品飲料',
  OfferCategory.freshAndChilled => '生鮮冷藏',
  OfferCategory.dailyNecessities => '日用品',
  OfferCategory.cleaningAndLaundry => '清潔洗衣',
  OfferCategory.beautyAndCare => '美妝保養',
  OfferCategory.health => '健康保健',
  OfferCategory.appliances => '家電',
  OfferCategory.electronics => '3C 通訊',
  OfferCategory.homeLiving => '家居生活',
  OfferCategory.fashion => '服飾鞋包',
  OfferCategory.baby => '母嬰用品',
  OfferCategory.pets => '寵物用品',
  OfferCategory.automotiveAndOutdoor => '汽車戶外',
  OfferCategory.diningVoucher => '餐飲票券',
  OfferCategory.travelAndEntertainment => '旅遊娛樂',
  OfferCategory.food => '餐飲',
  OfferCategory.coffee => '咖啡',
  OfferCategory.convenienceStore => '便利商店',
  OfferCategory.departmentStore => '百貨',
  OfferCategory.onlineShopping => '網路購物',
  OfferCategory.entertainment => '娛樂',
  OfferCategory.travel => '旅遊',
  OfferCategory.transportation => '交通',
  OfferCategory.others => '其他',
};
