import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';

class login extends StatefulWidget {
  const login({super.key});

  @override
  State<login> createState() => _loginState();
}

class _loginState extends State<login> {
  final email_controller = TextEditingController();
  final password_controller = TextEditingController();
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  Future<void> _signInWithEmailPassword() async {
    final email = email_controller.text.trim();
    final password = password_controller.text.trim();
    
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-posta ve şifre alanları boş bırakılamaz')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      await _authService.loginWithEmailPassword(email, password);
      
      // Giriş durumunu kontrol edelim
      final userData = await PreferencesService.getUserData();
      final isLoggedIn = await PreferencesService.isUserLoggedIn();
      print('Login sayfası: Giriş yapıldı - UID: ${userData['uid']}, Email: ${userData['email']}, isLoggedIn: $isLoggedIn');
      
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/page1');
    } on FirebaseAuthException catch (e) {
      String message = 'Giriş yapılırken bir hata oluştu';
      
      if (e.code == 'user-not-found') {
        message = 'Bu e-posta adresi ile kayıtlı kullanıcı bulunamadı';
      } else if (e.code == 'wrong-password') {
        message = 'Hatalı şifre';
      } else if (e.code == 'invalid-email') {
        message = 'Geçersiz e-posta adresi';
      } else if (e.code == 'user-disabled') {
        message = 'Bu kullanıcı hesabı devre dışı bırakılmış';
      } else if (e.code == 'too-many-requests') {
        message = 'Çok fazla başarısız giriş denemesi. Lütfen daha sonra tekrar deneyin';
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    
    try {
      await _authService.signInWithGoogle(context);
      
      // Giriş durumunu kontrol edelim
      final userData = await PreferencesService.getUserData();
      final isLoggedIn = await PreferencesService.isUserLoggedIn();
      print('Login sayfası: Google ile giriş yapıldı - UID: ${userData['uid']}, Email: ${userData['email']}, isLoggedIn: $isLoggedIn');
      
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/page1');
    } on FirebaseAuthException catch (e) {
      String message = 'Google ile giriş yapılırken bir hata oluştu';
      
      if (e.code == 'account-exists-with-different-credential') {
        message = 'Bu e-posta adresi zaten başka bir giriş yöntemi ile ilişkilendirilmiş';
      } else if (e.code == 'invalid-credential') {
        message = 'Giriş bilgileri geçersiz';
      } else if (e.code == 'user-disabled') {
        message = 'Bu kullanıcı hesabı devre dışı bırakılmış';
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google ile giriş başarısız: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGitHub() async {
    setState(() => _isLoading = true);
    
    try {
      await _authService.signInWithGitHub(context);
      
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/page1');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      
      String message = 'GitHub ile giriş başarısız';
      
      if (e.code == 'account-exists-with-different-credential') {
        message = 'Bu e-posta adresi farklı bir yöntemle kayıt edilmiş.';
      } else if (e.code == 'invalid-credential') {
        message = 'Geçersiz kimlik bilgileri.';
      } else if (e.code == 'operation-not-allowed') {
        message = 'GitHub girişi etkinleştirilmemiş.';
      } else if (e.code == 'user-disabled') {
        message = 'Kullanıcı hesabı devre dışı bırakılmış.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    email_controller.dispose();
    password_controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue, Colors.lightBlueAccent],
          ),
          // image: DecorationImage(
          //   image: AssetImage("assets/arkaplan.jpg"),
          //   fit: BoxFit.cover,
          // ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                const Text(
                  "OZCAN",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 55,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4.0,
                  ),
                ),
                const SizedBox(height: 30),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Text(
                          "Giriş Yap",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: email_controller,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white70,
                            hintText: "e-posta@gmail.com",
                            labelText: "E-posta",
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: password_controller,
                          onSubmitted: (_) => _signInWithEmailPassword(),
                          obscureText: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white70,
                            hintText: "********",
                            labelText: "Şifre",
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signInWithEmailPassword,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text(
                                    "Giriş Yap",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pushNamed(context, '/forgot_password'),
                            child: const Text(
                              "Şifremi Unuttum",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text("veya"),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _socialLoginButton(
                              onPressed: _signInWithGoogle,
                              icon: const Icon(Icons.g_mobiledata, size: 30),
                              label: "Google",
                            ),
                            _socialLoginButton(
                              onPressed: _signInWithGitHub,
                              icon: const Icon(Icons.code, size: 30),
                              label: "GitHub",
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    // Navigate to register page
                    Navigator.pushNamed(context, '/register');
                  },
                  child: const Text(
                    "Hesabınız yok mu? Kayıt Olun",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _socialLoginButton({
    required VoidCallback onPressed,
    required Widget icon,
    required String label,
  }) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: icon,
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
    );
  }
}
