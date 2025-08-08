import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  static Database? _database;
  static bool _isInitialized = false;

  static Future<void> _initializeFactory() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      // Web platformunda SQLite desteklenmediği için SharedPreferences kullanılacak
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Masaüstü platformlarda SQLite FFI başlatılır
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _isInitialized = true;
  }

  static Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
          'SQLite is not supported on web platform, use web-specific methods');
    }

    await _initializeFactory();

    if (_database != null) {
      return _database!;
    }
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite is not supported on web platform');
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Profil tablosu oluşturuluyor
        await db.execute('''
          CREATE TABLE profile(
            id TEXT PRIMARY KEY,
            name TEXT,
            surname TEXT,
            email TEXT,
            birthDate TEXT,
            birthPlace TEXT,
            currentCity TEXT
          )
        ''');
      },
    );
  }

  static Future<void> _saveUserProfileWeb({
    required String id,
    required String name,
    required String surname,
    required String email,
    String? birthDate,
    String? birthPlace,
    String? currentCity,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final profileData = {
      'id': id,
      'name': name,
      'surname': surname,
      'email': email,
      'birthDate': birthDate,
      'birthPlace': birthPlace,
      'currentCity': currentCity,
    };

    final profileJson = jsonEncode(profileData);
    await prefs.setString('user_profile_$id', profileJson);

    final existingIds = prefs.getStringList('profile_ids') ?? [];
    if (!existingIds.contains(id)) {
      existingIds.add(id);
      await prefs.setStringList('profile_ids', existingIds);
    }
  }

  static Future<void> saveUserProfile({
    required String id,
    required String name,
    required String surname,
    required String email,
    String? birthDate,
    String? birthPlace,
    String? currentCity,
  }) async {
    if (kIsWeb) {
      return _saveUserProfileWeb(
        id: id,
        name: name,
        surname: surname,
        email: email,
        birthDate: birthDate,
        birthPlace: birthPlace,
        currentCity: currentCity,
      );
    }

    final db = await database;

    final profileData = {
      'id': id,
      'name': name,
      'surname': surname,
      'email': email,
      'birthDate': birthDate,
      'birthPlace': birthPlace,
      'currentCity': currentCity,
    };

    await db.insert(
      'profile',
      profileData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, dynamic>?> _getUserProfileWeb(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString('user_profile_$id');

    if (profileJson != null) {
      return jsonDecode(profileJson) as Map<String, dynamic>;
    }

    return null;
  }

  static Future<Map<String, dynamic>?> getUserProfile(String id) async {
    if (kIsWeb) {
      return _getUserProfileWeb(id);
    }

    final db = await database;
    final results = await db.query(
      'profile',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  static Future<void> _clearUserProfileWeb() async {
    final prefs = await SharedPreferences.getInstance();
    final profileIds = prefs.getStringList('profile_ids') ?? [];

    for (final id in profileIds) {
      await prefs.remove('user_profile_$id');
    }
    await prefs.remove('profile_ids');
  }

  static Future<void> clearUserProfile() async {
    if (kIsWeb) {
      return _clearUserProfileWeb();
    }

    final db = await database;
    await db.delete('profile');
  }

  // Web için tüm profilleri getirme
  static Future<List<Map<String, dynamic>>> _getAllProfilesWeb() async {
    final prefs = await SharedPreferences.getInstance();
    final profileIds = prefs.getStringList('profile_ids') ?? [];
    final profiles = <Map<String, dynamic>>[];

    for (final id in profileIds) {
      final profileJson = prefs.getString('user_profile_$id');
      if (profileJson != null) {
        final profileData = jsonDecode(profileJson) as Map<String, dynamic>;
        profiles.add(profileData);
      }
    }

    return profiles;
  }

  // Test fonksiyonu - Tüm profilleri listele
  static Future<List<Map<String, dynamic>>> getAllProfiles() async {
    if (kIsWeb) {
      return _getAllProfilesWeb();
    }

    final db = await database;
    final results = await db.query('profile');
    return results;
  }
}
