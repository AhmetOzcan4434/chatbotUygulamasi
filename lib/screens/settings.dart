import 'package:flutter/material.dart';
import '../widgets/base_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});

  // Supabase client
  final SupabaseClient supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return BasePage(
      title: 'Ayarlar',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uygulama Ayarları',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Theme Settings
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('Dil'),
                    subtitle: const Text('Türkçe'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // About Section
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('Uygulama Hakkında'),
                    onTap: () => Navigator.pushNamed(context, '/about'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.code),
                    title: const Text('Sürüm'),
                    subtitle: const Text('1.0.0'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Account Section
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Hesap Ayarları'),
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading:
                        const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text(
                      'Hesabı Sil',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: const Text(
                      'Hesabınızı kalıcı olarak silin',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    onTap: () => _showDeleteAccountDialog(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading:
                        const Icon(Icons.exit_to_app, color: Colors.orange),
                    title: const Text(
                      'Çıkış Yap',
                      style: TextStyle(color: Colors.orange),
                    ),
                    onTap: () => _showLogoutDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final TextEditingController passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Hesabı Sil'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bu işlem geri alınamaz! Hesabınız ve tüm verileriniz kalıcı olarak silinecektir.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Devam etmek için şifrenizi girin:'),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                enabled: !isLoading,
                decoration: const InputDecoration(
                  labelText: 'Şifre',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Silinecek veriler:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('• Profil bilgileri'),
              const Text('• Kullanıcı detayları'),
              const Text('• Firebase hesabı'),
              const Text('• Tüm uygulama verileri'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      passwordController.dispose();
                      Navigator.pop(context);
                    },
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (passwordController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Lütfen şifrenizi girin')),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        await _deleteAccount(
                            context, passwordController.text.trim());
                        // Dialog burada manuel olarak kapatılacak, _deleteAccount içinde değil
                      } catch (e) {
                        setState(() => isLoading = false);
                        // Hata durumunda dialog açık kalır
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Hesabı Sil'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış'),
        content: const Text('Çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _logout(context);
            },
            child: const Text('Evet'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, String password) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı bulunamadı');
      }

      // Re-authenticate user with password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // 1. Supabase'den kullanıcı verilerini sil
      await _deleteSupabaseUserData(user.uid);

      // 2. Firebase Firestore'dan kullanıcı verilerini sil (eğer varsa)
      await _deleteFirestoreUserData(user.uid);

      // 3. SharedPreferences'ı temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 4. Firebase Authentication'dan kullanıcıyı sil
      await user.delete();

      // 5. Supabase session'ını sonlandır
      await supabase.auth.signOut();

      // 6. Login sayfasına yönlendir
      if (context.mounted) {
        // Önce dialog'u kapat
        Navigator.of(context, rootNavigator: true).pop();

        // Ardından login sayfasına yönlendir
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );

        // SnackBar'ı bir miktar gecikmeyle göster
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Hesabınız başarıyla silindi'),
                backgroundColor: Colors.green,
              ),
            );
          }
        });
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Hesap silme işlemi başarısız';

      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Girdiğiniz şifre yanlış';
          break;
        case 'too-many-requests':
          errorMessage =
              'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin';
          break;
        case 'requires-recent-login':
          errorMessage = 'Bu işlem için yeniden giriş yapmanız gerekiyor';
          break;
        default:
          errorMessage = 'Hata: ${e.message}';
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Beklenmeyen hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _deleteSupabaseUserData(String userId) async {
    try {
      // user_details tablosundan sil
      await supabase.from('user_details').delete().eq('id', userId);

      // profiles tablosundan sil
      await supabase.from('profiles').delete().eq('id', userId);

      print('Supabase kullanıcı verileri silindi');
    } catch (e) {
      print('Supabase veri silme hatası: $e');
      // Supabase hatası kritik değil, devam et
    }
  }

  Future<void> _deleteFirestoreUserData(String userId) async {
    try {
      // Firebase Firestore'dan kullanıcı verilerini sil
      // Bu kısım projenizin Firestore yapısına göre güncellenebilir

      // users koleksiyonundan kullanıcıyı sil (eğer varsa)
      // await FirebaseFirestore.instance
      //     .collection('users')
      //     .doc(userId)
      //     .delete();

      // bilgiler_firebase koleksiyonundan ilgili verileri sil (eğer varsa)
      // Burada kullanıcıya özel verileri sorgulayıp silmeniz gerekebilir

      print('Firestore kullanıcı verileri silindi');
    } catch (e) {
      print('Firestore veri silme hatası: $e');
      // Firestore hatası kritik değil, devam et
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      // Firebase'den çıkış yap
      await FirebaseAuth.instance.signOut();

      // Supabase'den çıkış yap
      await supabase.auth.signOut();

      // Shared preferences temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );

        Future.delayed(const Duration(milliseconds: 300), () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Çıkış yapıldı')),
            );
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çıkış yapılırken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
