// lib/services/db_service.dart
// SQLite helper for local authentication data.
// On web (kIsWeb == true) all methods are silent no-ops — the app uses
// SharedPreferences + the FastAPI/Supabase backend instead.

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBService {
  static Database? _db;

  static Future<void> init() async {
    if (kIsWeb) return; // sqflite not supported on web
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'eye_screening.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            token TEXT,
            role TEXT,
            name TEXT
          );
        ''');
      },
    );
  }

  static Future<void> upsertUser({
    required String username,
    required String password,
    String? token,
    String? role,
    String? name,
  }) async {
    if (kIsWeb) return; // no-op on web
    await init();
    await _db!.insert(
      'users',
      {
        'username': username,
        'password': password,
        'token': token,
        'role': role,
        'name': name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> getUser(String username) async {
    if (kIsWeb) return null; // no-op on web
    await init();
    final List<Map<String, dynamic>> rows = await _db!.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  static Future<void> clearUsers() async {
    if (kIsWeb) return; // no-op on web
    await init();
    await _db!.delete('users');
  }

  // Retrieve the first stored user (used for auto-login)
  static Future<Map<String, dynamic>?> getFirstUser() async {
    if (kIsWeb) return null; // no-op on web
    await init();
    final List<Map<String, dynamic>> rows = await _db!.query('users', limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }
}
