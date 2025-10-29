import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

import '../../models/measurement_entry.dart';
import '../../providers/database_providers.dart';
import '../../providers/entry_providers.dart';
import '../../providers/items_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(measurementsRepositoryProvider);
    final items = await repository.loadItems();
    if (items.isEmpty) {
      _showSnackBar(context, '尚未建立任何項目，無法匯出');
      return;
    }
    final entries = await repository.fetchEntries();
    final rows = <List<dynamic>>[];
    rows.add(['date', ...items.map((item) => item.name)]);
    for (final entry in entries) {
      final row = <dynamic>[entry.date];
      for (final item in items) {
        final value = entry.values[item.id];
        row.add(value?.toStringAsFixed(4) ?? '');
      }
      rows.add(row);
    }
    final csv = const ListToCsvConverter().convert(rows);
    final directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath == null) {
      _showSnackBar(context, '已取消匯出');
      return;
    }
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final fileName =
        'BMI_Record_${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}.csv';
    final filePath = path.join(directory.path, fileName);
    final file = File(filePath);
    await file.writeAsString(csv);
    _showSnackBar(context, '匯出完成：$filePath');
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.single.path == null) {
      return;
    }
    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final rows = const CsvToListConverter().convert(content);
    if (rows.isEmpty) {
      _showSnackBar(context, 'CSV 檔案沒有資料');
      return;
    }
    final header = rows.first.map((value) => value.toString()).toList();
    if (header.isEmpty || header.first.toLowerCase() != 'date') {
      _showSnackBar(context, 'CSV 第一欄必須為 date');
      return;
    }
    final itemNames = header.sublist(1).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (itemNames.isEmpty) {
      _showSnackBar(context, 'CSV 未提供任何項目欄位');
      return;
    }
    final repository = ref.read(measurementsRepositoryProvider);
    await repository.ensureItems(itemNames);
    final items = await repository.loadItems();
    final itemByName = {for (final item in items) item.name: item};

    int importedCount = 0;
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) {
        continue;
      }
      final dateValue = row.first.toString();
      if (dateValue.length != 8 || int.tryParse(dateValue) == null) {
        continue;
      }
      final values = <int, double>{};
      for (var j = 0; j < itemNames.length; j++) {
        final itemName = itemNames[j];
        final item = itemByName[itemName];
        if (item == null) {
          continue;
        }
        if (j + 1 >= row.length) {
          values.clear();
          break;
        }
        final cell = row[j + 1];
        if (cell == null || cell.toString().trim().isEmpty) {
          values.clear();
          break;
        }
        final parsed = switch (cell) {
          num value => value.toDouble(),
          _ => double.tryParse(cell.toString()),
        };
        if (parsed == null) {
          values.clear();
          break;
        }
        values[item.id] = parsed;
      }
      if (values.length != itemNames.length) {
        continue;
      }
      await repository.upsertEntry(
        MeasurementEntry(date: dateValue, values: values),
      );
      importedCount += 1;
    }
    if (importedCount == 0) {
      _showSnackBar(context, '沒有任何資料被匯入，請檢查 CSV 格式');
    } else {
      _showSnackBar(context, '已成功匯入 $importedCount 筆資料');
      ref.invalidate(itemsProvider);
      final selectedDate = ref.read(selectedDateProvider);
      final formatter = ref.read(dateFormatterProvider);
      ref.invalidate(entryByDateProvider(formatDateKey(formatter, selectedDate)));
      ref.read(measurementsRevisionProvider.notifier).state++;
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.download),
              title: const Text('匯出 CSV'),
              subtitle: const Text('選擇一個外部資料夾來匯出所有紀錄'),
              onTap: () => _exportData(context, ref),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('匯入 CSV'),
              subtitle: const Text('選擇先前匯出的檔案即可重新載入資料'),
              onTap: () => _importData(context, ref),
            ),
          ),
        ],
      ),
    );
  }
}
