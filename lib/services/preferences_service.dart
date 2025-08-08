import 'package:shared_preferences/shared_preferences.dart';

// PreferencesService sınıfı, kullanıcıya ait temel bilgileri SharedPreferences ile saklar ve yönetir.
class PreferencesService {
  static const String keyUid = 'uid';
  static const String keyEmail = 'email';
  static const String keyName = 'name';
  static const String keySurname = 'surname';

  // Kullanıcı verilerini SharedPreferences ile kaydeder
  static Future<void> saveUserData({
    required String uid,
    required String email,
    required String name,
    required String surname,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyUid, uid);
    await prefs.setString(keyEmail, email);
    await prefs.setString(keyName, name);
    await prefs.setString(keySurname, surname);

    // Log kaydedilen bilgileri
    print(
        'SharedPreferences: Kullanıcı bilgileri kaydedildi - UID: $uid, Email: $email');
  }

  // SharedPreferences'tan kullanıcı verilerini okur
  static Future<Map<String, String?>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, String?> userData = {
      'uid': prefs.getString(keyUid),
      'email': prefs.getString(keyEmail),
      'name': prefs.getString(keyName),
      'surname': prefs.getString(keySurname),
    };

    print(
        'SharedPreferences: Kullanıcı bilgileri okundu - UID: ${userData['uid']}, Email: ${userData['email']}');
    return userData;
  }

  // SharedPreferences'taki kullanıcı verilerini temizler
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyUid);
    await prefs.remove(keyEmail);
    await prefs.remove(keyName);
    await prefs.remove(keySurname);
    print('SharedPreferences: Kullanıcı bilgileri temizlendi');
  }

  // Kullanıcının giriş yapıp yapmadığını kontrol eder
  static Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final hasUid = prefs.containsKey(keyUid);
    final uid = prefs.getString(keyUid);
    print(
        'SharedPreferences: isUserLoggedIn çağrıldı - hasUid: $hasUid, UID: $uid');
    return hasUid && uid != null && uid.isNotEmpty;
  }
}
