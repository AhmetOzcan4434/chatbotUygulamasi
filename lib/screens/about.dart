import 'package:flutter/material.dart';
import '../widgets/base_page.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BasePage(
      title: 'Hakkında',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Özcan Projesi',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bu proje, Flutter kullanılarak geliştirilmiş bir mobil uygulama projesidir. '
              'Firebase ve Supabase entegrasyonu ile kullanıcı yönetimi ve veri saklama işlemlerini gerçekleştirir.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              '📌 Özellikler',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Kullanıcı girişi (Firebase Authentication).\n'
              '• Google ile giriş yapma.\n'
              '• Firestore ve Supabase veritabanı entegrasyonu.\n'
              '• SQLite ve SharedPreferences kullanımı.\n'
              '• Özelleştirilmiş DrawerMenu ve AppBar.\n',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              '👨‍💻 Geliştirici Bilgileri',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Geliştirici: Ahmet Özcan\n\n\n•Detaylı bilgi readme dosyasında bulunmaktadır.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
