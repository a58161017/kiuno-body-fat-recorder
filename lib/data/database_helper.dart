import 'dart:async';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final filePath = path.join(dbPath, 'body_fat_recorder.db');
    return openDatabase(
      filePath,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE measurement_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            position INTEGER NOT NULL
          );
        ''');
        await db.execute('''
          CREATE TABLE measurement_entries(
            date TEXT PRIMARY KEY
          );
        ''');
        await db.execute('''
          CREATE TABLE measurement_values(
            date TEXT NOT NULL,
            item_id INTEGER NOT NULL,
            value REAL NOT NULL,
            PRIMARY KEY(date, item_id),
            FOREIGN KEY(date) REFERENCES measurement_entries(date) ON DELETE CASCADE,
            FOREIGN KEY(item_id) REFERENCES measurement_items(id) ON DELETE CASCADE
          );
        ''');
      },
    );
  }
}
