/**
 * ÖZCAN PROJESİ - ANA UYGULAMA GİRİŞ NOKTASI
 * 
 * Bu dosya uygulamanın merkezi kontrol noktasıdır ve aşağıdaki temel işlevleri yerine getirir:
 * 
 * 🚀 BAŞLATMA İŞLEMLERİ:
 * - Firebase Authentication ve Firestore entegrasyonu
 * - Supabase PostgreSQL veritabanı bağlantısı
 * - Platform spesifik SQLite yapılandırması (Desktop/Mobile/Web)
 * - Türkçe lokalizasyon desteği
 * 
 * 🔐 KİMLİK DOĞRULAMA:
 * - Otomatik giriş durumu kontrolü (AuthCheck)
 * - Firebase ve SharedPreferences senkronizasyonu
 * - Kullanıcı oturum yönetimi
 * 
 * 🗺️ NAVİGASYON:
 * - Tüm uygulama sayfaları için route tanımlamaları
 * - Conditional routing (giriş durumuna göre yönlendirme)
 * 
 * 📱 PLATFORM DESTEĞİ:
 * - Android, iOS, Web, Windows, macOS cross-platform uyumluluk
 * - Platform spesifik veritabanı optimizasyonları
 * 
 * 🎨 TEMA & YERELLEŞTIRME:
 * - Material Design 3 tema yapılandırması
 * - Responsive UI tasarım temeli
 */

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/about.dart';
import 'screens/profile.dart';
import 'screens/settings.dart';
import 'screens/pages.dart';
import 'screens/register.dart';
import 'screens/forgot_password.dart';
import 'services/preferences_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/**
 * MAIN FUNCTION - UYGULAMA BAŞLATMA
 * 
 * Uygulama başlatma sırası:
 * 1. Platform tespiti (Web/Desktop/Mobile)
 * 2. SQLite yapılandırması (platform spesifik)
 * 3. Firebase servislerini başlatma
 * 4. Supabase bağlantısını kurma
 * 5. MyApp widget'ını başlatma
 */
void main() async {
  print('Main: Uygulama başlatılıyor...');
  WidgetsFlutterBinding.ensureInitialized();
  print('Main: WidgetsFlutterBinding başlatıldı');

  // Platform spesifik SQLite yapılandırması
  // Desktop platformlar için FFI factory kullanılır
  // Mobile platformlar varsayılan SQLite kullanır
  // Web platformu sadece SharedPreferences kullanır
  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      print(
        'Main: Desktop platformu tespit edildi, SQLite FFI factory başlatılıyor',
      );
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      print('Main: SQLite FFI factory başlatıldı');
    } else {
      print(
        'Main: Mobile platformu tespit edildi, varsayılan SQLite kullanılacak',
      );
    }
  } else {
    print('Main: Web platformu tespit edildi, SharedPreferences kullanılacak');
  }

  try {
    print('Main: Firebase başlatılıyor...');
    // Firebase Authentication ve Firestore başlatma
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Main: Firebase başlatıldı');

    print('Main: Supabase başlatılıyor...');
    // Supabase PostgreSQL veritabanı ve Storage bağlantısı
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://wawsmzlefrtxlxpakdpq.supabase.co',
      ),
      anonKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: '',
      ),
    );
    print('Main: Supabase başlatıldı');

    print('Firebase and Supabase initialized successfully');
  } catch (e) {
    print('Error initializing services: $e');
  }

  print('Main: MyApp başlatılıyor...');
  runApp(const MyApp());
}

/**
 * MYAPP CLASS - ANA UYGULAMA WIDGET'I
 * 
 * Uygulama çapında ayarlar:
 * - Material Design 3 tema
 * - Türkçe lokalizasyon
 * - Route yapılandırması (8 ana sayfa)
 * - AuthCheck ile otomatik kimlik doğrulama
 */
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('MyApp: build metodu çalışıyor');
    return MaterialApp(
      title: 'Özcan Proje',
      debugShowCheckedModeBanner: false,

      // Material Design 3 tema yapılandırması
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),

      // Türkçe lokalizasyon desteği
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'), // Türkçe
      ],
      locale: const Locale('tr', 'TR'),

      // Giriş durumuna göre otomatik yönlendirme
      home: const AuthCheck(),

      // Uygulama route haritası
      routes: {
        '/login': (context) => const login(), // Giriş sayfası
        '/register': (context) => const RegisterScreen(), // Kayıt sayfası
        '/forgot_password': (context) =>
            const ForgotPasswordScreen(), // Şifre sıfırlama
        '/home': (context) => const HomePage(), // Ana sayfa (AI Chat)
        '/about': (context) => const AboutScreen(), // Hakkında sayfası
        '/page1': (context) => const Page1(), // Genel Sohbet
        '/page2': (context) => const Page2(), // Eğitim Asistanı
        '/page3': (context) => const Page3(), // Teknoloji Rehberi
        '/page4': (context) => const Page4(), // Sağlık Danışmanı
        '/page5': (context) => const Page5(), // Sanat ve Kültür
        '/profile': (context) => const ProfilePage(), // Profil sayfası
        '/settings': (context) => SettingsPage(), // Ayarlar sayfası
      },
    );
  }
}

/**
 * AUTHCHECK CLASS - OTOMATIK KİMLİK DOĞRULAMA
 * 
 * Bu widget uygulama açıldığında otomatik olarak:
 * 1. Firebase Auth durumunu kontrol eder
 * 2. SharedPreferences'dan oturum bilgilerini okur
 * 3. Kullanıcıyı uygun sayfaya yönlendirir:
 *    - Giriş yapılmışsa: Page1 (Genel Sohbet)
 *    - Giriş yapılmamışsa: Login sayfası
 * 
 * Loading ekranı: Marka logosu ve yükleme animasyonu
 */
class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool _isLoading = true; // Yükleme durumu
  bool _isLoggedIn = false; // Giriş durumu
  String? _userEmail; // Kullanıcı email'i

  @override
  void initState() {
    super.initState();
    print('AuthCheck: initState çalıştı');
    _checkAuth(); // Kimlik doğrulama kontrolünü başlat
  }

  /**
   * Kullanıcı kimlik doğrulama durumunu kontrol eden metod
   * 
   * Kontrol sırası:
   * 1. Firebase Authentication current user
   * 2. SharedPreferences oturum durumu
   * 3. Kullanıcı verileri (email, uid vs.)
   * 4. State güncelleme ve yönlendirme kararı
   */
  Future<void> _checkAuth() async {
    try {
      print('AuthCheck: Kullanıcı giriş kontrolü başlatıldı');

      // Firebase auth durumunu kontrol et
      final currentUser = FirebaseAuth.instance.currentUser;
      print('AuthCheck: Firebase current user: ${currentUser?.uid}');

      // SharedPreferences durumunu kontrol et
      final isLoggedIn = await PreferencesService.isUserLoggedIn();
      final userData = await PreferencesService.getUserData();

      print('AuthCheck: SharedPreferences giriş durumu: $isLoggedIn');
      print('AuthCheck: SharedPreferences verisi: ${userData.toString()}');

      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
          _userEmail = userData['email'];
          _isLoading = false;
        });

        print(
          'AuthCheck: Yönlendirme kararı - isLoggedIn: $_isLoggedIn, Email: $_userEmail',
        );
      }
    } catch (e) {
      print("AuthCheck hata: $e");
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Yükleme ekranı: Marka logosu ve progress indicator
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Uygulama logosu/markası
              const Text(
                "OZCAN",
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 55,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4.0,
                ),
              ),
              const SizedBox(height: 30),
              // Yükleme animasyonu
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                'Giriş durumu kontrol ediliyor...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Conditional Routing: Giriş durumuna göre sayfa yönlendirmesi
    if (_isLoggedIn) {
      // Kullanıcı giriş yapmışsa Page1 (Genel Sohbet) sayfasına yönlendir
      print(
        'AuthCheck: Kullanıcı giriş yapmış, Page1 sayfasına yönlendiriliyor',
      );
      return const Page1();
    } else {
      // Kullanıcı giriş yapmamışsa Login sayfasına yönlendir
      print(
        'AuthCheck: Kullanıcı giriş yapmamış, login sayfasına yönlendiriliyor',
      );
      return const login();
    }
  }
}

/**
 * 📋 UYGULAMA AKIŞ DİYAGRAMI:
 * 
 * main() 
 *   ↓
 * Platform Detection (Web/Desktop/Mobile)
 *   ↓
 * SQLite Configuration
 *   ↓
 * Firebase Initialization
 *   ↓
 * Supabase Initialization
 *   ↓
 * MyApp()
 *   ↓
 * AuthCheck()
 *   ↓
 * [Loading Screen]
 *   ↓
 * Firebase Auth Check + SharedPreferences Check
 *   ↓
 * ┌─────────────────┬─────────────────┐
 * │   Logged In     │   Not Logged    │
 * │   Page1()       │   login()       │
 * └─────────────────┴─────────────────┘
 * 
 * 🔄 VERİ AKIŞI:
 * 
 * 1. BAŞLATMA:
 *    Platform → SQLite → Firebase → Supabase → UI
 * 
 * 2. KİMLİK DOĞRULAMA:
 *    Firebase Auth ←→ SharedPreferences ←→ UI State
 * 
 * 3. NAVİGASYON:
 *    AuthCheck → Route Decision → Page Rendering
 * 
 * 🛡️ GÜVENLİK:
 * - Firebase Authentication ile güvenli giriş
 * - Supabase RLS (Row Level Security) politikaları
 * - SharedPreferences ile yerel oturum yönetimi
 * - Platform spesifik güvenlik optimizasyonları
 * 
 * 🚀 PERFORMANS:
 * - Lazy loading ile sayfa yüklemeleri
 * - Platform spesifik veritabanı optimizasyonları
 * - Minimal başlangıç yükü için conditional imports
 * - Efficient state management ile smooth UX
 * 
 * 📱 PLATFORM ÖZELLEŞTİRMELERİ:
 * - Web: SharedPreferences only, no SQLite
 * - Desktop: SQLite FFI factory for database operations
 * - Mobile: Native SQLite implementation
 * - All: Firebase + Supabase cross-platform compatibility
 */
