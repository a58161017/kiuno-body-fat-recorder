import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/measurement_entry.dart';
import '../../models/measurement_item.dart';
import '../../providers/database_providers.dart';
import '../../providers/entry_providers.dart';
import '../../providers/items_provider.dart';
import '../home/home_page.dart';

class RecordPage extends ConsumerStatefulWidget {
  const RecordPage({super.key});

  @override
  ConsumerState<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends ConsumerState<RecordPage> {
  final Map<int, TextEditingController> _controllers = {};
  String? _lastSyncedDate;
  bool _forceSync = true;
  bool _isSaving = false;
  ProviderSubscription<DateTime>? _dateSubscription;

  @override
  void initState() {
    super.initState();
    _dateSubscription = ref.listenManual<DateTime>(
      selectedDateProvider,
      (previous, next) {
        if (previous != next) {
          setState(() {
            _lastSyncedDate = null;
            _forceSync = true;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _dateSubscription?.close();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _dateKey(DateTime date) {
    final formatter = ref.read(dateFormatterProvider);
    return formatDateKey(formatter, date);
  }

  Future<void> _selectDate(BuildContext context) async {
    final current = ref.read(selectedDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final normalized = DateTime(picked.year, picked.month, picked.day);
      ref.read(selectedDateProvider.notifier).state = normalized;
      final dateKey = _dateKey(normalized);
      final repository = ref.read(measurementsRepositoryProvider);
      final exists = await repository.entryExists(dateKey);
      if (exists && mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('提醒'),
              content: Text('選擇的 ${DateFormat('yyyy/MM/dd').format(normalized)} 已經有資料。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('知道了'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  void _syncControllers(
    List<MeasurementItem> items,
    MeasurementEntry? entry,
    String dateKey,
  ) {
    if (!_forceSync && _lastSyncedDate == dateKey) {
      return;
    }
    final entryValues = entry?.values ?? {};
    final existingKeys = _controllers.keys.toList();
    for (final key in existingKeys) {
      if (!items.any((item) => item.id == key)) {
        _controllers.remove(key)?.dispose();
      }
    }
    for (final item in items) {
      final value = entryValues[item.id];
      final formatted = value == null ? '' : value.toString();
      final controller = _controllers[item.id];
      if (controller == null) {
        _controllers[item.id] = TextEditingController(text: formatted);
      } else if (controller.text != formatted) {
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
    _lastSyncedDate = dateKey;
    _forceSync = false;
  }

  Future<void> _saveEntry(
    BuildContext context,
    List<MeasurementItem> items,
    String dateKey,
  ) async {
    if (_isSaving) {
      return;
    }
    final repository = ref.read(measurementsRepositoryProvider);
    final values = <int, double>{};
    for (final item in items) {
      final text = _controllers[item.id]?.text.trim() ?? '';
      if (text.isEmpty) {
        _showSnackBar(context, '請完整填寫 ${item.name} 的數值');
        return;
      }
      final parsed = double.tryParse(text);
      if (parsed == null) {
        _showSnackBar(context, '${item.name} 必須是數字');
        return;
      }
      values[item.id] = parsed;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await repository.upsertEntry(
        MeasurementEntry(date: dateKey, values: values),
      );
      if (!mounted) {
        return;
      }
      _forceSync = true;
      _showSnackBar(context, '已儲存 ${DateFormat('yyyy/MM/dd').format(ref.read(selectedDateProvider))} 的資料');
      ref.invalidate(entryByDateProvider(dateKey));
      ref.invalidate(chartDataProvider);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteEntry(BuildContext context, String dateKey) async {
    final repository = ref.read(measurementsRepositoryProvider);
    final exists = await repository.entryExists(dateKey);
    if (!exists) {
      _showSnackBar(context, '目前日期沒有可刪除的資料');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('刪除資料'),
          content: const Text('確定要刪除這個日期的所有紀錄嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
    if (confirm != true) {
      return;
    }
    await repository.deleteEntry(dateKey);
    if (!mounted) {
      return;
    }
    for (final controller in _controllers.values) {
      controller.clear();
    }
    _lastSyncedDate = null;
    _forceSync = true;
    ref.invalidate(entryByDateProvider(dateKey));
    ref.invalidate(chartDataProvider);
    _showSnackBar(context, '已刪除資料');
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final dateKey = _dateKey(selectedDate);
    final itemsAsync = ref.watch(itemsProvider);
    final entryAsync = ref.watch(entryByDateProvider(dateKey));

    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('讀取項目失敗：$error')),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('目前尚未建立任何紀錄項目，請先到「項目管理」新增。'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      ref.read(navigationIndexProvider.notifier).state = 1;
                    },
                    child: const Text('前往項目管理'),
                  ),
                ],
              ),
            ),
          );
        }
        final entry = entryAsync.valueOrNull;
        if (entryAsync.isLoading && _lastSyncedDate == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (entryAsync.hasError && _lastSyncedDate == null) {
          return Center(child: Text('讀取資料失敗：${entryAsync.error}'));
        }
        _syncControllers(items, entry, dateKey);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '選擇日期：${DateFormat('yyyy/MM/dd').format(selectedDate)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_month),
                    tooltip: '選擇日期',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return TextField(
                      controller: _controllers[item.id],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*[.]?[0-9]*')),
                      ],
                      decoration: InputDecoration(
                        labelText: item.name,
                        border: const OutlineInputBorder(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _saveEntry(context, items, dateKey),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('儲存'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteEntry(context, dateKey),
                      icon: const Icon(Icons.delete),
                      label: const Text('刪除'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
