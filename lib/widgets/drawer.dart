import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../services/supabase_service.dart';

class DrawerMenu extends StatefulWidget {
  const DrawerMenu({super.key});

  @override
  State<DrawerMenu> createState() => _DrawerMenuState();
}

class _DrawerMenuState extends State<DrawerMenu> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _isLoading = true;
  
  // Kullanıcı bilgileri
  String _userName = '';
  String _userEmail = '';
  String? _userPhotoUrl;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Drawer her gösterildiğinde çağrılabilir
    _loadUserData();
  }
  
  // Drawer açıldığında manuel olarak çağrılabilecek fonksiyon
  void refreshUserData() {
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Firebase'den temel bilgileri al
        String email = user.email ?? '';
        
        // Supabase'den kullanıcı profilini al
        final profile = await _supabaseService.getUserProfileById(user.uid);
        
        setState(() {
          if (profile != null) {
            _userName = '${profile['ad']} ${profile['soyad']}';
            _userEmail = profile['eposta'];
            _userPhotoUrl = profile['foto'];
          } else {
            // Supabase profili yoksa Firebase bilgilerini kullan
            _userName = user.displayName ?? 'Kullanıcı';
            _userEmail = email;
            _userPhotoUrl = user.photoURL;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _userName = 'Misafir Kullanıcı';
          _userEmail = '';
          _userPhotoUrl = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Kullanıcı bilgileri yüklenirken hata: $e');
      setState(() {
        _userName = 'Kullanıcı';
        _userEmail = '';
        _userPhotoUrl = null;
        _isLoading = false;
      });
    }
  }

  void _navigate(BuildContext ctx, String route) {
    Navigator.pop(ctx);
    if (ModalRoute.of(ctx)?.settings.name != route) {
      Navigator.pushReplacementNamed(ctx, route);
    }
  }

  void _logout(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Çıkış'),
        content: const Text('Çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              try {
                print('Çıkış işlemi başlatılıyor...');
                
                // Loading dialog göster
                showDialog(
                  context: ctx,
                  barrierDismissible: false,
                  builder: (_) => const AlertDialog(
                    content: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Çıkış yapılıyor...'),
                      ],
                    ),
                  ),
                );
                
                // Firebase sign out
                print('Firebase\'den çıkış yapılıyor...');
                await FirebaseAuth.instance.signOut();
                print('Firebase çıkış başarılı');
                
                // Clear shared prefs
                print('SharedPreferences temizleniyor...');
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                print('SharedPreferences temizlendi');
                
                // Clear SQLite if needed
                try {
                  print('SQLite veritabanı temizleniyor...');
                  final db = await openDatabase(join(await getDatabasesPath(), 'app.db'));
                  await db.delete('profile');
                  await db.close();
                  print('SQLite veritabanı temizlendi');
                } catch (dbError) {
                  print('SQLite temizleme hatası (normal olabilir): $dbError');
                }
                
                // Loading dialog'u kapat
                Navigator.pop(ctx);
                // Çıkış dialog'unu kapat
                Navigator.pop(ctx);
                
                print('Login sayfasına yönlendiriliyor...');
                // Login sayfasına git ve tüm sayfaları temizle
                Navigator.pushNamedAndRemoveUntil(ctx, '/login', (_) => false);
                
                // Başarı mesajı göster
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Başarıyla çıkış yapıldı'),
                    backgroundColor: Colors.green,
                  ),
                );
                
                print('Çıkış işlemi tamamlandı');
                
              } catch (e) {
                print('Çıkış işlemi sırasında hata: $e');
                
                // Loading dialog'u kapat (varsa)
                try {
                  Navigator.pop(ctx);
                } catch (_) {}
                
                // Çıkış dialog'unu kapat
                Navigator.pop(ctx);
                
                // Hata mesajı göster
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Çıkış sırasında hata oluştu: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
                
                // Basit çıkış denemesi
                try {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushNamedAndRemoveUntil(ctx, '/login', (_) => false);
                } catch (fallbackError) {
                  print('Basit çıkış da başarısız: $fallbackError');
                }
              }
            },
            child: const Text('Evet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(children: [
        UserAccountsDrawerHeader(
          accountName: Text(_userName),
          accountEmail: Text(_userEmail),
          currentAccountPicture: _isLoading
              ? const CircularProgressIndicator()
              : _userPhotoUrl != null && _userPhotoUrl!.isNotEmpty
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(_userPhotoUrl!),
                      onBackgroundImageError: (_, __) => const Icon(Icons.error),
                    )
                  : const CircleAvatar(
                      child: Icon(Icons.person, size: 50),
                    ),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.chat, color: Colors.blue),
          title: const Text('Genel Sohbet'),
          onTap: () => _navigate(context, '/page1'),
        ),
        ListTile(
          leading: const Icon(Icons.school, color: Colors.green),
          title: const Text('Eğitim Asistanı'),
          onTap: () => _navigate(context, '/page2'),
        ),
        ListTile(
          leading: const Icon(Icons.computer, color: Colors.orange),
          title: const Text('Teknoloji Rehberi'),
          onTap: () => _navigate(context, '/page3'),
        ),
        ListTile(
          leading: const Icon(Icons.health_and_safety, color: Colors.purple),
          title: const Text('Sağlık Danışmanı'),
          onTap: () => _navigate(context, '/page4'),
        ),
        ListTile(
          leading: const Icon(Icons.palette, color: Colors.red),
          title: const Text('Sanat ve Kültür'),
          onTap: () => _navigate(context, '/page5'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('Profil'),
          onTap: () => _navigate(context, '/profile'),
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Ayarlar'),
          onTap: () => _navigate(context, '/settings'),
        ),
        ListTile(
          leading: const Icon(Icons.exit_to_app),
          title: const Text('Çıkış'),
          onTap: () => _logout(context),
        ),
      ]),
    );
  }
}
