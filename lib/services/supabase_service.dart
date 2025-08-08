import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Create or update user profile with all fields
  Future<void> upsertUserProfile({
    required String id,
    required String kullaniciAdi,
    required String ad,
    required String soyad,
    required String eposta,
    String? foto,
    DateTime? dogumTarihi,
    String? dogumYeri,
    String? yasadigiSehir,
  }) async {
    try {
      print('Attempting to upsert profile with ID: $id'); // Debug log
      
      final profileData = {
        'id': id,
        'kullanici_adi': kullaniciAdi,
        'ad': ad,
        'soyad': soyad,
        'eposta': eposta,
        'foto': foto,
        'dogum_tarihi': dogumTarihi?.toIso8601String(),
        'dogum_yeri': dogumYeri,
        'yasadigi_sehir': yasadigiSehir,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      print('Profile data: $profileData'); // Debug log
      
      final response = await _client.from('profiles').upsert(profileData);
      print('Upsert successful: $response'); // Debug log
    } catch (e) {
      print('Error upserting user profile: $e');
      if (e is PostgrestException) {
        print('PostgrestException details: ${e.code}, ${e.details}, ${e.hint}');
      }
      rethrow;
    }
  }

  // Get user profile by id
  Future<Map<String, dynamic>?> getUserProfileById(String id) async {
    try {
      print('Getting user profile by ID: $id'); // Debug log
      
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      
      print('Profile retrieved: $response'); // Debug log
      return response;
    } catch (e) {
      print('Error getting user profile by id: $e');
      if (e is PostgrestException) {
        print('PostgrestException details: ${e.code}, ${e.details}, ${e.hint}');
      }
      return null;
    }
  }

  // Get user profile by kullanici_adi
  Future<Map<String, dynamic>?> getUserProfileByUsername(String kullaniciAdi) async {
    try {
      print('Getting user profile by username: $kullaniciAdi'); // Debug log
      
      final response = await _client
          .from('profiles')
          .select()
          .eq('kullanici_adi', kullaniciAdi)
          .maybeSingle();
      
      print('Profile retrieved: $response'); // Debug log
      return response;
    } catch (e) {
      print('Error getting user profile by username: $e');
      if (e is PostgrestException) {
        print('PostgrestException details: ${e.code}, ${e.details}, ${e.hint}');
      }
      return null;
    }
  }

  // Get user profile by email
  Future<Map<String, dynamic>?> getUserProfileByEmail(String email) async {
    try {
      print('Getting user profile by email: $email'); // Debug log
      
      final response = await _client
          .from('profiles')
          .select()
          .eq('eposta', email)
          .maybeSingle();
      
      print('Profile retrieved: $response'); // Debug log
      return response;
    } catch (e) {
      print('Error getting user profile by email: $e');
      if (e is PostgrestException) {
        print('PostgrestException details: ${e.code}, ${e.details}, ${e.hint}');
      }
      return null;
    }
  }

  // Upload profile photo and return the URL
  Future<String?> uploadProfilePhoto({
    required String userId,
    required Uint8List photoBytes,
    required String fileExtension,
  }) async {
    try {
      print('Uploading profile photo for user: $userId'); // Debug log
      print('Photo size: ${photoBytes.length} bytes');
      print('File extension: $fileExtension');
      
      // Simplify the path to avoid folder structure issues
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$userId.$fileExtension';
      final path = 'profile_photos/$fileName';
      
      print('Storage path: $path');
      
      // First check if bucket exists
      try {
        final buckets = await _client.storage.listBuckets();
        print('Available buckets: ${buckets.map((b) => b.name).join(', ')}');
        
        final bucketExists = buckets.any((b) => b.name == 'profile_photos');
        if (!bucketExists) {
          print('Warning: profile_photos bucket not found');
        }
      } catch (e) {
        print('Error checking buckets: $e');
      }
      
      // Upload the file to Supabase Storage
      await _client.storage.from('profile_photos').uploadBinary(
            path,
            photoBytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExtension',
              upsert: true, // Enable upsert to overwrite existing files
            ),
          );
      
      // Get the public URL
      final photoUrl = _client.storage.from('profile_photos').getPublicUrl(path);
      
      print('Photo uploaded successfully, URL: $photoUrl'); // Debug log
      return photoUrl;
    } catch (e) {
      print('Error uploading profile photo: $e');
      if (e is StorageException) {
        print('StorageException details: ${e.statusCode}, ${e.message}, ${e.error}');
      }
      return null;
    }
  }
  
  // Delete profile photo
  Future<bool> deleteProfilePhoto(String userId, String fileExtension) async {
    try {
      print('Deleting profile photo for user: $userId'); // Debug log
      
      final fileName = '$userId.$fileExtension';
      final path = 'profile_photos/$userId/$fileName';
      
      await _client.storage.from('profile_photos').remove([path]);
      print('Photo deleted successfully'); // Debug log
      return true;
    } catch (e) {
      print('Error deleting profile photo: $e');
      if (e is StorageException) {
        print('StorageException details: ${e.statusCode}, ${e.message}, ${e.error}');
      }
      return false;
    }
  }

  // Get all profiles
  Future<List<Map<String, dynamic>>> getAllProfiles() async {
    try {
      print('Getting all profiles'); // Debug log
      
      final response = await _client
          .from('profiles')
          .select();
      
      print('Retrieved ${response.length} profiles'); // Debug log
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting profiles: $e');
      if (e is PostgrestException) {
        print('PostgrestException details: ${e.code}, ${e.details}, ${e.hint}');
      }
      return [];
    }
  }
  
  // USER DETAILS METHODS
  
  // Kullanıcının meslek ve yaş bilgilerini oluşturma veya güncelleme
  Future<void> upsertUserDetails({
    required String userId,
    String? meslek,
    int? yas,
  }) async {
    try {
      print('Attempting to upsert user details for ID: $userId'); // Debug log
      
      final userDetails = {
        'id': userId,
        'meslek': meslek,
        'yas': yas,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      print('User details data: $userDetails'); // Debug log
      
      final response = await _client.from('user_details').upsert(userDetails);
      print('Upsert user details successful: $response'); // Debug log
    } catch (e) {
      print('Error upserting user details: $e');
      if (e is PostgrestException) {
        print('PostgrestException details: ${e.code}, ${e.details}, ${e.hint}');
      }
      rethrow;
    }
  }
  
  // Kullanıcının meslek ve yaş bilgilerini getirme
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      print('Getting user details for ID: $userId'); // Debug log
      
      final response = await _client
          .from('user_details')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      print('User details retrieved: $response'); // Debug log
      return response;
    } catch (e) {
      print('Error getting user details: $e');
      if (e is PostgrestException) {
        print('PostgrestException details: ${e.code}, ${e.details}, ${e.hint}');
      }
      return null;
    }
  }
} 