import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:ozcan_project/widgets/custom_app_bar.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'database_service.dart';
import 'preferences_service.dart';
import 'supabase_service.dart';

class AuthService {
  // Firebase services
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final SupabaseService _supabaseService = SupabaseService();

  // GitHub OAuth configuration
  static const String _githubClientId = String.fromEnvironment(
    'GITHUB_CLIENT_ID',
    defaultValue: '',
  );
  static const String _githubClientSecret = String.fromEnvironment(
    'GITHUB_CLIENT_SECRET',
    defaultValue: '',
  );
  static const String _redirectUri = String.fromEnvironment(
    'GITHUB_REDIRECT_URI',
    defaultValue: 'https://deneme-c8433.firebaseapp.com/__/auth/handler',
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Email & Password Register
  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String surname,
    DateTime? birthDate,
    String? birthPlace,
    String? currentCity,
  }) async {
    try {
      // Create user with email and password
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save additional data to Firestore
      if (credential.user != null) {
        await _firestore
            .collection('bilgiler_firebase')
            .doc(credential.user!.uid)
            .set({
              'name': name,
              'surname': surname,
              'email': email,
              'Doğum Tarihi': birthDate != null
                  ? Timestamp.fromDate(birthDate)
                  : null,
              'Doğum Yeri': birthPlace,
              'Yaşadığın il': currentCity,
              'createdAt': FieldValue.serverTimestamp(),
            });

        // Save basic info to SharedPreferences
        await PreferencesService.saveUserData(
          uid: credential.user!.uid,
          email: email,
          name: name,
          surname: surname,
        );

        // Save profile data to SQLite
        await DatabaseService.saveUserProfile(
          id: credential.user!.uid,
          name: name,
          surname: surname,
          email: email,
          birthDate: birthDate?.toIso8601String(),
          birthPlace: birthPlace,
          currentCity: currentCity,
        );

        // Save to Supabase with all available profile data
        await _supabaseService.upsertUserProfile(
          id: credential.user!.uid,
          kullaniciAdi: '$name $surname',
          ad: name,
          soyad: surname,
          eposta: email,
          foto: null,
          dogumTarihi: birthDate,
          dogumYeri: birthPlace,
          yasadigiSehir: currentCity,
        );
      }

      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Email & Password Login
  Future<UserCredential> loginWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        print(
          "AuthService: Kullanıcı giriş yaptı - UID: ${credential.user!.uid}, Email: $email",
        );

        // Veri çekme ve kaydetme
        await _fetchAndSaveUserData(credential.user!.uid);

        // Doğrudan SharedPreferences'a da kaydedelim (yedek)
        await PreferencesService.saveUserData(
          uid: credential.user!.uid,
          email: email,
          name: "", // Firestore'dan doldurulacak
          surname: "", // Firestore'dan doldurulacak
        );

        // Kontrol edelim
        final isLoggedIn = await PreferencesService.isUserLoggedIn();
        print(
          "AuthService: Giriş sonrası SharedPreferences durumu: $isLoggedIn",
        );
      }

      return credential;
    } catch (e) {
      print("AuthService: Giriş hatası - $e");
      rethrow;
    }
  }

  // Google Sign In
  Future<UserCredential> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Sign in aborted by user',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Check if this is a new user
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        // Save new user data to Firestore
        await _firestore
            .collection('bilgiler_firebase')
            .doc(userCredential.user!.uid)
            .set({
              'name': userCredential.user!.displayName?.split(' ').first ?? '',
              'surname':
                  userCredential.user!.displayName?.split(' ').last ?? '',
              'email': userCredential.user!.email ?? '',
              'Doğum Tarihi': null,
              'Doğum Yeri': '',
              'Yaşadığın il': '',
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      if (userCredential.user != null) {
        await _fetchAndSaveUserData(userCredential.user!.uid);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // GitHub Sign In - Android için güncellenmiş versiyon
  Future<UserCredential> signInWithGitHub(BuildContext context) async {
    try {
      if (kIsWeb) {
        // Web için popup kullan
        GithubAuthProvider githubProvider = GithubAuthProvider();
        githubProvider.addScope('user:email');
        return await _auth.signInWithPopup(githubProvider);
      } else {
        // Mobile için WebView kullan
        return await _signInWithGitHubMobile(context);
      }
    } catch (e) {
      _showErrorDialog(context, 'GitHub ile giriş başarısız: ${e.toString()}');
      rethrow;
    }
  }

  // Mobile GitHub authentication
  Future<UserCredential> _signInWithGitHubMobile(BuildContext context) async {
    // GitHub OAuth URL'ini oluştur
    final state = DateTime.now().millisecondsSinceEpoch.toString();
    final authUrl =
        'https://github.com/login/oauth/authorize'
        '?client_id=$_githubClientId'
        '&redirect_uri=$_redirectUri'
        '&scope=user:email'
        '&state=$state';

    // WebView'ı aç ve callback bekle
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => GitHubAuthWebView(authUrl: authUrl),
      ),
    );

    if (code == null) {
      throw FirebaseAuthException(
        code: 'sign_in_cancelled',
        message: 'GitHub sign-in was cancelled',
      );
    }

    // Callback'ten gelen kodu kullanarak access token al
    final accessToken = await _exchangeCodeForToken(code);

    // GitHub kullanıcı bilgilerini al
    final userInfo = await _getGitHubUserInfo(accessToken);

    // Anonymous authentication ile kullanıcı oluştur ve GitHub bilgilerini kaydet
    return await _createUserWithGitHubInfo(userInfo);
  }

  // GitHub code'unu access token ile değiştir
  Future<String> _exchangeCodeForToken(String code) async {
    final response = await http.post(
      Uri.parse('https://github.com/login/oauth/access_token'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'client_id': _githubClientId,
        'client_secret': _githubClientSecret,
        'code': code,
        'redirect_uri': _redirectUri,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final accessToken = data['access_token'];
      if (accessToken == null) {
        throw Exception('Access token alınamadı: ${data['error_description']}');
      }
      return accessToken;
    } else {
      throw Exception('GitHub token exchange failed: ${response.statusCode}');
    }
  }

  // GitHub kullanıcı bilgilerini al
  Future<Map<String, dynamic>> _getGitHubUserInfo(String accessToken) async {
    final response = await http.get(
      Uri.parse('https://api.github.com/user'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/vnd.github.v3+json',
      },
    );

    if (response.statusCode == 200) {
      final userInfo = json.decode(response.body);

      // Email bilgisini ayrıca al (private olabilir)
      final emailResponse = await http.get(
        Uri.parse('https://api.github.com/user/emails'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (emailResponse.statusCode == 200) {
        final emails = json.decode(emailResponse.body) as List;
        final primaryEmail = emails.firstWhere(
          (email) => email['primary'] == true,
          orElse: () => emails.isNotEmpty ? emails[0] : null,
        );
        if (primaryEmail != null) {
          userInfo['email'] = primaryEmail['email'];
        }
      }

      return userInfo;
    } else {
      throw Exception(
        'GitHub kullanıcı bilgileri alınamadı: ${response.statusCode}',
      );
    }
  }

  // GitHub bilgileri ile kullanıcı oluştur
  Future<UserCredential> _createUserWithGitHubInfo(
    Map<String, dynamic> userInfo,
  ) async {
    final email = userInfo['email'] ?? '';
    final name = userInfo['name'] ?? userInfo['login'] ?? '';
    final avatarUrl = userInfo['avatar_url'];

    // Email ile mevcut kullanıcı var mı kontrol et
    UserCredential userCredential;

    try {
      // Önce email ile anonymous auth oluştur
      userCredential = await _auth.signInAnonymously();

      // Sonra kullanıcı bilgilerini güncelle
      if (email.isNotEmpty) {
        await userCredential.user?.updateEmail(email);
      }
      if (name.isNotEmpty) {
        await userCredential.user?.updateDisplayName(name);
      }
      if (avatarUrl != null) {
        await userCredential.user?.updatePhotoURL(avatarUrl);
      }
    } catch (e) {
      print('Anonymous auth error: $e');
      rethrow;
    }

    // Firestore'a kullanıcı bilgilerini kaydet
    if (userCredential.user != null) {
      final nameParts = name.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

      await _firestore
          .collection('bilgiler_firebase')
          .doc(userCredential.user!.uid)
          .set({
            'name': firstName,
            'surname': lastName,
            'email': email,
            'github_id': userInfo['id'],
            'github_username': userInfo['login'],
            'avatar_url': avatarUrl,
            'Doğum Tarihi': null,
            'Doğum Yeri': '',
            'Yaşadığın il': '',
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Diğer servislere de kaydet
      await _fetchAndSaveUserData(userCredential.user!.uid);
    }

    return userCredential;
  }

  // Error dialog göster
  void _showErrorDialog(BuildContext context, String message) {
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('GitHub Giriş Hatası'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    }
  }

  // Fetch user data and save to local storage
  Future<void> _fetchAndSaveUserData(String uid) async {
    try {
      final userDoc = await _firestore
          .collection('bilgiler_firebase')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;

        // Save to SharedPreferences
        await PreferencesService.saveUserData(
          uid: uid,
          email: userData['email'] ?? '',
          name: userData['name'] ?? '',
          surname: userData['surname'] ?? '',
        );

        // Save to SQLite
        await DatabaseService.saveUserProfile(
          id: uid,
          name: userData['name'] ?? '',
          surname: userData['surname'] ?? '',
          email: userData['email'] ?? '',
          birthDate: userData['Doğum Tarihi']?.toDate()?.toIso8601String(),
          birthPlace: userData['Doğum Yeri'],
          currentCity: userData['Yaşadığın il'],
        );

        // For Supabase, create a username from name and surname
        final name = userData['name'] ?? '';
        final surname = userData['surname'] ?? '';
        final username = '$name $surname';
        final email = userData['email'] ?? '';
        DateTime? birthDate;
        if (userData['Doğum Tarihi'] != null) {
          birthDate = userData['Doğum Tarihi'].toDate();
        }

        // Check if user exists in Supabase by ID
        final supabaseProfile = await _supabaseService.getUserProfileById(uid);
        if (supabaseProfile == null) {
          // Create new profile with all available data
          await _supabaseService.upsertUserProfile(
            id: uid,
            kullaniciAdi: username,
            ad: name,
            soyad: surname,
            eposta: email,
            foto: null,
            dogumTarihi: birthDate,
            dogumYeri: userData['Doğum Yeri'],
            yasadigiSehir: userData['Yaşadığın il'],
          );
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    print("AuthService: Çıkış yapılıyor");
    await _auth.signOut();
    await _googleSignIn.signOut();
    await PreferencesService.clearUserData();
    await DatabaseService.clearUserProfile();

    // Çıkış sonrası kontrol
    final isLoggedIn = await PreferencesService.isUserLoggedIn();
    print("AuthService: Çıkış sonrası SharedPreferences durumu: $isLoggedIn");
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}

// GitHub Authentication WebView
class GitHubAuthWebView extends StatefulWidget {
  final String authUrl;

  const GitHubAuthWebView({Key? key, required this.authUrl}) : super(key: key);

  @override
  State<GitHubAuthWebView> createState() => _GitHubAuthWebViewState();
}

class _GitHubAuthWebViewState extends State<GitHubAuthWebView> {
  late final WebViewController controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100) {
              setState(() {
                isLoading = false;
              });
            }
          },
          onPageStarted: (String url) {
            print('GitHub Auth: Page started loading: $url');
          },
          onPageFinished: (String url) {
            print('GitHub Auth: Page finished loading: $url');

            // Callback URL'ini kontrol et
            if (url.contains('deneme-c8433.firebaseapp.com/__/auth/handler') ||
                url.contains('localhost') ||
                url.contains('callback')) {
              final uri = Uri.parse(url);
              final code = uri.queryParameters['code'];
              final error = uri.queryParameters['error'];

              if (code != null) {
                print('GitHub Auth: Authorization code received: $code');
                Navigator.pop(context, code);
              } else if (error != null) {
                print('GitHub Auth: Error received: $error');
                Navigator.pop(context, null);
              }
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('GitHub Auth: Web resource error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "GitHub Girişi"),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
