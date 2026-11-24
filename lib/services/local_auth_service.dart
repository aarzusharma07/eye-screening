import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class LocalAuthService {
  static Database? _db;

  static Future<void> init() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'eye_screening_auth.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL
          )
        ''');
        // Insert a default demo user
        await db.insert('users', {'username': 'doctor', 'password': 'password'});
        await db.insert('users', {'username': 'nurse', 'password': 'password'});
      },
    );
  }

  static Future<bool> register(String username, String password) async {
    try {
      await _db!.insert('users', {'username': username, 'password': password});
      return true;
    } catch (e) {
      // Username already exists or other error
      return false;
    }
  }

  static Future<bool> login(String username, String password) async {
    final List<Map<String, dynamic>> result = await _db!.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    return result.isNotEmpty;
  }
}
