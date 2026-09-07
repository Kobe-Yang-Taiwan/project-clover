import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/offer.dart';
import '../models/offer_store.dart';
import '../offer_reminder_service.dart';
import 'critical_draft.dart';
import 'local_import_service.dart';

/// Bounded, local-only Founder records. Accuracy is human-scored, never inferred
/// from an unchanged field. No image, OCR fragments, path or network destination.
class CaptureRecords {
  static const key = 'project_clover.capture_records.v1';
  static Future<List<Map<String, dynamic>>> read() async {
    final raw = await SharedPreferencesAsync().getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  static Future<void> append(Map<String, dynamic> record) async {
    final records = await read();
    records.add(record);
    await SharedPreferencesAsync().setString(
      key,
      jsonEncode(records.reversed.take(50).toList().reversed.toList()),
    );
  }
}

class CriticalDraftScreen extends StatefulWidget {
  const CriticalDraftScreen({
    super.key,
    required this.path,
    required this.service,
    required this.store,
    required this.reminders,
    this.recordAttempt = CaptureRecords.append,
  });
  final String path;
  final CouponImportService service;
  final OfferStore store;
  final OfferReminderScheduler reminders;
  final Future<void> Function(Map<String, dynamic>) recordAttempt;

  @override
  State<CriticalDraftScreen> createState() => _CriticalDraftScreenState();
}

class _CriticalDraftScreenState extends State<CriticalDraftScreen> {
  final _name = TextEditingController();
  final _value = TextEditingController();
  final _clock = Stopwatch()..start();
  CriticalDraft? _draft;
  DateTime? _expiration;
  Offer? _saved;
  bool _busy = false;
  bool _typed = false;
  bool _recorded = false;
  final _typedFields = <String>{};
  int _actions = 0;
  String? _message;
  String _reminderState = 'not_checked';

  @override
  void initState() {
    super.initState();
    _extract();
  }

  Future<void> _extract() async {
    CriticalDraft draft;
    try {
      draft = CriticalDraft.fromPage(
        await widget.service.recognizeImage(widget.path),
      );
    } catch (_) {
      draft = const CriticalDraft(
        name: DraftField(null, [], FieldConfidence.low),
        expiration: DraftField(null, [], FieldConfidence.low),
        value: DraftField(null, [], FieldConfidence.low),
      );
    }
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _name.text = draft.name.value ?? '';
      _value.text = draft.value.value ?? '';
      _expiration = draft.expiration.value;
    });
  }

  void _typing(String field) {
    _typed = true;
    if (_typedFields.add(field)) _actions++;
  }

  Map<String, String?> get _initial => {
    'name': _draft?.name.value,
    'expiration': _draft?.expiration.value == null
        ? null
        : draftDate(_draft!.expiration.value!),
    'value': _draft?.value.value,
  };

  Future<void> _record(bool success) async {
    if (_recorded) return;
    _recorded = true;
    try {
      await widget.recordAttempt({
        'at': DateTime.now().toIso8601String(),
        'success': success,
        'offerId': _saved?.id,
        'actions': _actions,
        'elapsedMs': _clock.elapsedMilliseconds,
        'freeFormTyping': _typed,
        'initial': _initial,
        'final': {
          'name': _name.text.trim(),
          'expiration': _expiration == null ? null : draftDate(_expiration!),
          'value': _value.text.trim(),
        },
        'draftAccuracy': {'name': null, 'expiration': null, 'value': null},
        'reminder': _reminderState,
      });
    } catch (_) {
      if (mounted)
        setState(() => _message = '${_message ?? ''}\n測試紀錄未寫入；優惠儲存狀態不受影響。');
    }
  }

  Future<void> _schedule() async {
    try {
      var permission = await widget.reminders.permissionState();
      if (permission != NotificationPermissionState.granted) {
        final allowed = await widget.reminders.requestPermission();
        permission = allowed
            ? NotificationPermissionState.granted
            : NotificationPermissionState.denied;
      }
      if (permission != NotificationPermissionState.granted) {
        _reminderState = 'permission_denied';
        _message = '優惠已儲存；請允許通知，才能收到提醒。';
        return;
      }
      await widget.reminders.sync(widget.store.activeOffers);
      final reminders = widget.reminders;
      final pending = reminders is OfferReminderInspector
          ? await (reminders as OfferReminderInspector).hasPendingReminder(
              _saved!.id,
            )
          : null;
      _reminderState = pending == true ? 'pending_verified' : 'unverified';
      _message = pending == true ? '優惠已儲存，系統待發提醒已確認。' : '優惠已儲存；尚未確認系統提醒，請重試。';
    } catch (_) {
      _reminderState = 'schedule_failed';
      _message = '優惠已儲存；提醒建立失敗，請重試。';
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    _actions++;
    final date = _expiration;
    final now = DateTime.now();
    if (_name.text.trim().isEmpty ||
        _value.text.trim().isEmpty ||
        date == null) {
      setState(() => _message = '請確認名稱、到期日與優惠內容。');
      return;
    }
    if (DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
    ).isBefore(now.add(const Duration(minutes: 2)))) {
      setState(() => _message = '這個日期已過期或即將結束，請確認到期日。');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final reminder = criticalDraftReminderTime(date, now);
      _saved = await widget.store.addOffer(
        name: _name.text,
        expiresAt: date,
        note: _value.text,
        reminderEnabled: true,
        reminderDaysBefore: DateUtils.dateOnly(
          date,
        ).difference(DateUtils.dateOnly(reminder)).inDays,
        reminderHour: reminder.hour,
        reminderMinute: reminder.minute,
      );
      _clock.stop();
      await _schedule();
      await _record(true);
    } catch (_) {
      _message = '儲存失敗，資料尚未寫入。請重試。';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _chooseDate() async {
    _actions++;
    final today = DateUtils.dateOnly(DateTime.now());
    final last = DateTime(today.year + 10, 12, 31);
    final initial =
        _expiration == null ||
            _expiration!.isBefore(today) ||
            _expiration!.isAfter(last)
        ? today
        : _expiration!;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: last,
    );
    // Calendar selection and confirmation are separate meaningful actions.
    if (selected != null && mounted) {
      _actions += 2;
      setState(() => _expiration = selected);
    }
  }

  String _confidence(FieldConfidence confidence) => switch (confidence) {
    FieldConfidence.high => 'High · 高信心',
    FieldConfidence.medium => 'Medium · 請確認',
    FieldConfidence.low => 'Low · 請選擇或修正',
  };

  @override
  void dispose() {
    // Snapshot synchronously before controllers are disposed.
    if (!_recorded) _record(false);
    _name.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('儲存一個優惠')),
        body: draft == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_saved == null) ...[
                    const Text('請選擇想保留的一個優惠，確認三項資訊後儲存。圖片只在本機處理。'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: Image.file(
                        File(widget.path),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    Text('優惠名稱 · ${_confidence(draft.name.confidence)}'),
                    TextField(
                      key: const Key('draft-name'),
                      controller: _name,
                      onChanged: (_) => _typing('name'),
                      decoration: const InputDecoration(hintText: '優惠名稱'),
                    ),
                    Wrap(
                      spacing: 8,
                      children: draft.name.candidates
                          .map(
                            (name) => ActionChip(
                              label: Text(name),
                              onPressed: () {
                                _actions++;
                                setState(() => _name.text = name);
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('到期日 · ${_confidence(draft.expiration.confidence)}'),
                    OutlinedButton(
                      key: const Key('draft-date'),
                      onPressed: _chooseDate,
                      child: Text(
                        _expiration == null ? '選擇到期日' : draftDate(_expiration!),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: draft.expiration.candidates
                          .map(
                            (date) => ActionChip(
                              label: Text(draftDate(date)),
                              onPressed: () {
                                _actions++;
                                setState(() => _expiration = date);
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('價值／折扣 · ${_confidence(draft.value.confidence)}'),
                    TextField(
                      key: const Key('draft-value'),
                      controller: _value,
                      onChanged: (_) => _typing('value'),
                      decoration: const InputDecoration(
                        hintText: '例如 NT\$100 折扣、買一送一',
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: draft.value.candidates
                          .map(
                            (value) => ActionChip(
                              label: Text(value),
                              onPressed: () {
                                _actions++;
                                setState(() => _value.text = value);
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    const Text('按儲存即確認以上三欄。預設於到期前提醒；若預設時間已過，將儘快提醒。'),
                    FilledButton(
                      key: const Key('save-critical-draft'),
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? '儲存中…' : '確認並儲存'),
                    ),
                  ] else ...[
                    Text(
                      _saved!.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text('${draftDate(_saved!.expiresAt)} · ${_saved!.note}'),
                    Text(
                      '$_actions 個操作 · ${(_clock.elapsedMilliseconds / 1000).toStringAsFixed(1)} 秒 · ${_typed ? '曾輸入文字' : '無文字輸入'}',
                    ),
                    if (_reminderState != 'pending_verified')
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                await _schedule();
                                if (mounted) setState(() => _busy = false);
                              },
                        child: const Text('重新確認提醒'),
                      ),
                    FilledButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('完成'),
                    ),
                  ],
                  if (_message != null)
                    Text(_message!, key: const Key('draft-result')),
                ],
              ),
      ),
    );
  }
}

class CaptureRecordsScreen extends StatelessWidget {
  const CaptureRecordsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('本機匯入測試紀錄')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: CaptureRecords.read(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('無法讀取測試紀錄'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '最近 50 次；僅存本機。正確率需對照原圖評分，未修改不代表正確。操作數為選擇／儲存／文字編輯次數；日期選擇至少計 3 次，翻月與系統權限操作請由測試者另記。',
              ),
            ),
            ...snapshot.data!.reversed.map(
              (record) => ExpansionTile(
                title: Text(
                  '${record['success'] == true ? '已儲存' : '未完成'} · ${record['actions']} 操作 · ${((record['elapsedMs'] as num) / 1000).toStringAsFixed(1)} 秒',
                ),
                subtitle: Text(
                  '${record['at']} · 輸入文字：${record['freeFormTyping']}',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(record),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
