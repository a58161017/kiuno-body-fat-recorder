import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../models/measurement_entry.dart';
import '../models/measurement_item.dart';
import 'database_helper.dart';

class MeasurementsRepository {
  MeasurementsRepository(this._database);

  final AppDatabase _database;

  Future<Database> get _db async => _database.database;

  Future<List<MeasurementItem>> loadItems() async {
    final db = await _db;
    final maps = await db.query(
      'measurement_items',
      orderBy: 'position ASC',
    );
    return maps.map(MeasurementItem.fromMap).toList();
  }

  Future<int> addItem(String name) async {
    final db = await _db;
    final items = await loadItems();
    final position = items.isEmpty ? 0 : items.last.position + 1;
    return db.insert('measurement_items', {
      'name': name,
      'position': position,
    });
  }

  Future<void> renameItem(int id, String name) async {
    final db = await _db;
    await db.update(
      'measurement_items',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteItem(int id) async {
    final db = await _db;
    await db.delete(
      'measurement_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> reorderItems(List<int> orderedIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update(
          'measurement_items',
          {'position': i},
          where: 'id = ?',
          whereArgs: [orderedIds[i]],
        );
      }
    });
  }

  Future<bool> entryExists(String date) async {
    final db = await _db;
    final result = await db.query(
      'measurement_entries',
      where: 'date = ?',
      whereArgs: [date],
      columns: ['date'],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<MeasurementEntry?> fetchEntry(String date) async {
    final db = await _db;
    final entry = await db.query(
      'measurement_entries',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (entry.isEmpty) {
      return null;
    }
    final values = await db.query(
      'measurement_values',
      where: 'date = ?',
      whereArgs: [date],
    );
    final map = <int, double>{};
    for (final row in values) {
      map[row['item_id'] as int] = (row['value'] as num).toDouble();
    }
    return MeasurementEntry(date: date, values: map);
  }

  Future<void> upsertEntry(MeasurementEntry entry) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(
        'measurement_entries',
        {'date': entry.date},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      for (final value in entry.values.entries) {
        await txn.insert(
          'measurement_values',
          {
            'date': entry.date,
            'item_id': value.key,
            'value': value.value,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      // Remove values that are no longer present to keep table consistent.
      final existing = await txn.query(
        'measurement_values',
        where: 'date = ?',
        whereArgs: [entry.date],
      );
      for (final row in existing) {
        final itemId = row['item_id'] as int;
        if (!entry.values.containsKey(itemId)) {
          await txn.delete(
            'measurement_values',
            where: 'date = ? AND item_id = ?',
            whereArgs: [entry.date, itemId],
          );
        }
      }
      final count = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM measurement_values WHERE date = ?',
            [entry.date],
          )) ??
          0;
      if (count == 0) {
        await txn.delete(
          'measurement_entries',
          where: 'date = ?',
          whereArgs: [entry.date],
        );
      }
    });
  }

  Future<void> deleteEntry(String date) async {
    final db = await _db;
    await db.delete(
      'measurement_entries',
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  Future<List<MeasurementEntry>> fetchEntries() async {
    final db = await _db;
    final entries = await db.query(
      'measurement_entries',
      orderBy: 'date ASC',
    );
    final result = <MeasurementEntry>[];
    for (final entry in entries) {
      final date = entry['date'] as String;
      final values = await db.query(
        'measurement_values',
        where: 'date = ?',
        whereArgs: [date],
      );
      final map = <int, double>{};
      for (final row in values) {
        map[row['item_id'] as int] = (row['value'] as num).toDouble();
      }
      result.add(MeasurementEntry(date: date, values: map));
    }
    return result;
  }

  Future<List<MeasurementDataPoint>> fetchDataPoints(
    int itemId,
    DateTime start,
    DateTime end,
  ) async {
    final db = await _db;
    final formatter = DateFormat('yyyyMMdd');
    final startKey = formatter.format(start);
    final endKey = formatter.format(end);
    final rows = await db.rawQuery(
      '''
      SELECT mv.date, mv.value FROM measurement_values mv
      INNER JOIN measurement_entries me ON me.date = mv.date
      WHERE mv.item_id = ? AND mv.date BETWEEN ? AND ?
      ORDER BY mv.date ASC
      ''',
      [itemId, startKey, endKey],
    );
    return rows
        .map(
          (row) => MeasurementDataPoint(
            date: formatter.parse(row['date'] as String),
            value: (row['value'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<void> ensureItems(List<String> itemNames) async {
    final db = await _db;
    await db.transaction((txn) async {
      final existingItems = await txn.query('measurement_items');
      final existingByName = <String, Map<String, Object?>>{};
      var maxPosition = -1;
      for (final item in existingItems) {
        existingByName[item['name'] as String] = item;
        maxPosition = math.max(maxPosition, item['position'] as int);
      }
      for (final name in itemNames) {
        if (!existingByName.containsKey(name)) {
          maxPosition += 1;
          await txn.insert('measurement_items', {
            'name': name,
            'position': maxPosition,
          });
        }
      }
      final refreshed = await txn.query('measurement_items');
      final byName = {for (final item in refreshed) item['name'] as String: item};
      var position = 0;
      for (final name in itemNames) {
        final item = byName[name];
        if (item != null) {
          await txn.update(
            'measurement_items',
            {'position': position},
            where: 'id = ?',
            whereArgs: [item['id']],
          );
          position += 1;
        }
      }
      for (final item in refreshed) {
        final name = item['name'] as String;
        if (!itemNames.contains(name)) {
          await txn.update(
            'measurement_items',
            {'position': position},
            where: 'id = ?',
            whereArgs: [item['id']],
          );
          position += 1;
        }
      }
    });
  }
}
