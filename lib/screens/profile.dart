import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:path/path.dart' as path_lib;
import '../widgets/base_page.dart';
import '../services/supabase_service.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // User data
  String id = '';
  String kullaniciAdi = '';
  String ad = '';
  String soyad = '';
  String eposta = '';
  String? foto;
  String? dogumYeri;
  String? yasadigiSehir;
  DateTime? dogumTarihi;

  // User details
  String? meslek;
  int? yas;

  // Supabase data
  Map<String, dynamic>? supabaseProfile;
  Map<String, dynamic>? userDetails;
  final SupabaseService _supabaseService = SupabaseService();

  bool isLoading = true;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);

    await _loadFromSupabase();

    setState(() => isLoading = false);
  }

  Future<void> _loadFromSupabase() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser != null) {
        id = firebaseUser.uid;
        print('Firebase UID: $id'); // Debug log

        // Check Supabase session status
        final supabaseSession = Supabase.instance.client.auth.currentSession;
        print(
            'Supabase session: ${supabaseSession != null ? "Active" : "None"}');

        // Get user profile from Supabase by ID
        try {
          supabaseProfile = await _supabaseService.getUserProfileById(id);
          print('Supabase profile: $supabaseProfile'); // Debug log

          // Get user details (meslek ve yaş bilgileri)
          userDetails = await _supabaseService.getUserDetails(id);
          print('User details: $userDetails'); // Debug log
        } catch (e) {
          print('Error getting profile data: $e');
          supabaseProfile = null;
          userDetails = null;
        }

        if (supabaseProfile != null) {
          setState(() {
            kullaniciAdi = supabaseProfile!['kullanici_adi'] ?? '';
            ad = supabaseProfile!['ad'] ?? '';
            soyad = supabaseProfile!['soyad'] ?? '';
            eposta = supabaseProfile!['eposta'] ?? '';
            foto = supabaseProfile!['foto'];

            // Parse date if exists
            if (supabaseProfile!['dogum_tarihi'] != null) {
              try {
                dogumTarihi = DateTime.parse(supabaseProfile!['dogum_tarihi']);
              } catch (e) {
                print('Error parsing date: $e');
                dogumTarihi = null;
              }
            }

            dogumYeri = supabaseProfile!['dogum_yeri'];
            yasadigiSehir = supabaseProfile!['yasadigi_sehir'];

            // Set user details if available
            if (userDetails != null) {
              meslek = userDetails!['meslek'];
              yas = userDetails!['yas'];
            }
          });
        } else {
          // If no profile exists, use Firebase data as fallback
          setState(() {
            final nameParts = firebaseUser.displayName?.split(' ') ?? ['', ''];
            ad = nameParts.first;
            soyad = nameParts.length > 1 ? nameParts.last : '';
            kullaniciAdi = firebaseUser.displayName ??
                firebaseUser.email?.split('@')[0] ??
                '';
            eposta = firebaseUser.email ?? '';
            foto = firebaseUser.photoURL;
          });

          print('Creating new Supabase profile for user: $id'); // Debug log

          // Create profile in Supabase
          try {
            // Create a delay to ensure any prior operation completes
            await Future.delayed(Duration(milliseconds: 100));

            await _supabaseService.upsertUserProfile(
              id: id,
              kullaniciAdi: kullaniciAdi,
              ad: ad,
              soyad: soyad,
              eposta: eposta,
              foto: foto,
              dogumTarihi: null,
              dogumYeri: null,
              yasadigiSehir: null,
            );
            print('Supabase profile created successfully'); // Debug log

            // Create user details with default values
            await _supabaseService.upsertUserDetails(
              userId: id,
              meslek: null,
              yas: null,
            );
            print('User details created successfully'); // Debug log

            // Verify profile was created
            final verifyProfile = await _supabaseService.getUserProfileById(id);
            print('Verification of created profile: $verifyProfile');
          } catch (e) {
            print('Error creating Supabase profile: $e');
            // Show error message to user
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Profil oluşturulamadı: $e')),
              );
            }
          }
        }
      } else {
        print('No Firebase user found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lütfen giriş yapın')),
          );
          // Navigate back to login page
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
    } catch (e) {
      print('Error loading from Supabase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil yüklenemedi: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, // Fotoğrafı sıkıştır
      maxHeight: 800, // Fotoğrafı sıkıştır
      imageQuality: 85, // Kaliteyi biraz düşür
    );

    if (image == null) return;

    setState(() => isUploading = true);

    try {
      print('Selected image: ${image.path}');
      print('Image name: ${image.name}');

      // Read image as bytes
      final Uint8List bytes = await image.readAsBytes();
      print('Image size: ${bytes.length} bytes');

      final String fileExtension =
          path_lib.extension(image.name).replaceFirst('.', '');
      print('File extension: $fileExtension');

      // Upload to Supabase
      final String? newPhotoUrl = await _supabaseService.uploadProfilePhoto(
        userId: id,
        photoBytes: bytes,
        fileExtension: fileExtension.isEmpty
            ? 'jpg'
            : fileExtension, // Boş uzantı varsa jpg kullan
      );

      if (newPhotoUrl != null) {
        print('Photo uploaded successfully: $newPhotoUrl');

        // Update profile with new photo URL
        try {
          await _supabaseService.upsertUserProfile(
            id: id,
            kullaniciAdi: kullaniciAdi,
            ad: ad,
            soyad: soyad,
            eposta: eposta,
            foto: newPhotoUrl,
            dogumTarihi: dogumTarihi,
            dogumYeri: dogumYeri,
            yasadigiSehir: yasadigiSehir,
          );

          setState(() {
            foto = newPhotoUrl;
            isUploading = false;
          });

          // Başarı mesajı göster
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Profil fotoğrafı başarıyla güncellendi')),
            );

            // Drawer'ı güncellemek için sayfayı yeniden yükle
            _restartPage();
          }
        } catch (e) {
          print('Error updating profile with new photo: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Profil güncellenemedi: $e')),
            );
            setState(() => isUploading = false);
          }
        }
      } else {
        print('Failed to upload photo - null URL returned');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fotoğraf yüklenemedi')),
          );
          setState(() => isUploading = false);
        }
      }
    } catch (e) {
      print('Error in _pickAndUploadImage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil fotoğrafı yüklenemedi: $e')),
        );
        setState(() => isUploading = false);
      }
    }
  }

  Future<void> _editKullaniciAdi() async {
    final TextEditingController controller =
        TextEditingController(text: kullaniciAdi);
    final newKullaniciAdi = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Kullanıcı Adını Değiştir'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Yeni Kullanıcı Adı',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (newKullaniciAdi != null &&
        newKullaniciAdi.isNotEmpty &&
        newKullaniciAdi != kullaniciAdi) {
      setState(() => isLoading = true);

      try {
        await _supabaseService.upsertUserProfile(
          id: id,
          kullaniciAdi: newKullaniciAdi,
          ad: ad,
          soyad: soyad,
          eposta: eposta,
          foto: foto,
          dogumTarihi: dogumTarihi,
          dogumYeri: dogumYeri,
          yasadigiSehir: yasadigiSehir,
        );

        setState(() {
          kullaniciAdi = newKullaniciAdi;
          isLoading = false;
        });

        // Drawer'ı yenilemek için sayfayı yeniden yükle
        _restartPage();
      } catch (e) {
        print('Error updating kullaniciAdi: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kullanıcı adı güncellenemedi: $e')),
        );
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _editProfileField(String field) async {
    String title = '';
    String label = '';
    String initialValue = '';

    switch (field) {
      case 'ad':
        title = 'Adınızı Değiştir';
        label = 'Yeni Ad';
        initialValue = ad;
        break;
      case 'soyad':
        title = 'Soyadınızı Değiştir';
        label = 'Yeni Soyad';
        initialValue = soyad;
        break;
      case 'dogumYeri':
        title = 'Doğum Yerinizi Değiştir';
        label = 'Doğum Yeri';
        initialValue = dogumYeri ?? '';
        break;
      case 'yasadigiSehir':
        title = 'Yaşadığınız Şehri Değiştir';
        label = 'Şehir';
        initialValue = yasadigiSehir ?? '';
        break;
      case 'meslek':
        title = 'Mesleğinizi Değiştir';
        label = 'Meslek';
        initialValue = meslek ?? '';
        break;
      default:
        return;
    }

    final TextEditingController controller =
        TextEditingController(text: initialValue);
    final newValue = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (newValue != null && newValue.isNotEmpty && newValue != initialValue) {
      setState(() => isLoading = true);

      try {
        if (field == 'meslek') {
          // Meslek bilgisini güncelle
          await _supabaseService.upsertUserDetails(
            userId: id,
            meslek: newValue,
            yas: yas,
          );

          setState(() {
            meslek = newValue;
            isLoading = false;
          });
        } else {
          // Diğer profil bilgilerini güncelle
          Map<String, dynamic> updatedValues = {
            'ad': ad,
            'soyad': soyad,
            'dogumYeri': dogumYeri,
            'yasadigiSehir': yasadigiSehir,
          };

          updatedValues[field] = newValue;

          await _supabaseService.upsertUserProfile(
            id: id,
            kullaniciAdi: kullaniciAdi,
            ad: updatedValues['ad'],
            soyad: updatedValues['soyad'],
            eposta: eposta,
            foto: foto,
            dogumTarihi: dogumTarihi,
            dogumYeri: updatedValues['dogumYeri'],
            yasadigiSehir: updatedValues['yasadigiSehir'],
          );

          setState(() {
            switch (field) {
              case 'ad':
                ad = newValue;
                break;
              case 'soyad':
                soyad = newValue;
                break;
              case 'dogumYeri':
                dogumYeri = newValue;
                break;
              case 'yasadigiSehir':
                yasadigiSehir = newValue;
                break;
            }
            isLoading = false;
          });
        }

        // Ad veya soyad değiştiyse drawer'ı yenile
        if (field == 'ad' || field == 'soyad') {
          _restartPage();
        }
      } catch (e) {
        print('Error updating profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil güncellenemedi: $e')),
        );
        setState(() => isLoading = false);
      }
    }
  }

  // Yaş düzenleme fonksiyonu (sayı girişi için)
  Future<void> _editAge() async {
    final TextEditingController controller = TextEditingController(
      text: yas != null ? yas.toString() : '',
    );

    final newValue = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Yaşınızı Değiştir'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Yaş',
          ),
          keyboardType: TextInputType.number, // Sayısal klavye
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (newValue != null && newValue.isNotEmpty) {
      // Sayısal değer kontrolü
      int? newAge;
      try {
        newAge = int.parse(newValue);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lütfen geçerli bir yaş girin')),
          );
        }
        return;
      }

      // Makul yaş aralığı kontrolü
      if (newAge < 0 || newAge > 120) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Lütfen geçerli bir yaş girin (0-120)')),
          );
        }
        return;
      }

      if (newAge != yas) {
        setState(() => isLoading = true);

        try {
          await _supabaseService.upsertUserDetails(
            userId: id,
            meslek: meslek,
            yas: newAge,
          );

          setState(() {
            yas = newAge;
            isLoading = false;
          });
        } catch (e) {
          print('Error updating age: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Yaş güncellenemedi: $e')),
            );
          }
          setState(() => isLoading = false);
        }
      }
    }
  }

  // Sayfayı yeniden yükleyerek drawer'ı günceller
  void _restartPage() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ProfilePage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build content widget that will be passed to BasePage
    Widget content;

    if (isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      content = SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Photo
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: isUploading
                        ? const Center(child: CircularProgressIndicator())
                        : foto != null && foto!.isNotEmpty
                            ? Image.network(
                                foto!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                  Icons.person,
                                  size: 60,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 60,
                              ),
                  ),
                ),
                GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Username
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Kullanıcı Adı'),
              subtitle: Text(kullaniciAdi),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editKullaniciAdi,
              ),
            ),

            // First Name
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Ad'),
              subtitle: Text(ad),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editProfileField('ad'),
              ),
            ),

            // Last Name
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Soyad'),
              subtitle: Text(soyad),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editProfileField('soyad'),
              ),
            ),

            // Email
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('E-posta'),
              subtitle: Text(eposta),
              trailing: const Icon(Icons.lock), // Email cannot be edited
            ),

            // Meslek - NEW
            ListTile(
              leading: const Icon(Icons.work),
              title: const Text('Meslek'),
              subtitle: Text(meslek ?? 'Belirtilmemiş'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editProfileField('meslek'),
              ),
            ),

            // Yaş - NEW
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Yaş'),
              subtitle: Text(yas != null ? yas.toString() : 'Belirtilmemiş'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _editAge,
              ),
            ),

            // Birth Place
            ListTile(
              leading: const Icon(Icons.location_city),
              title: const Text('Doğum Yeri'),
              subtitle: Text(dogumYeri ?? 'Belirtilmemiş'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editProfileField('dogumYeri'),
              ),
            ),

            // Current City
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Yaşadığı Şehir'),
              subtitle: Text(yasadigiSehir ?? 'Belirtilmemiş'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editProfileField('yasadigiSehir'),
              ),
            ),

            // Birth Date (just displayed, no editing for now)
            if (dogumTarihi != null)
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Doğum Tarihi'),
                subtitle: Text(
                    '${dogumTarihi!.day}/${dogumTarihi!.month}/${dogumTarihi!.year}'),
              ),

            const SizedBox(height: 20),

            // Logout Button
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Çıkış Yap'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Use BasePage as the scaffold
    return BasePage(
      title: 'Profil',
      body: content,
      // Drawer açıldığında yeniden kullanıcı bilgilerini yükle
      onDrawerChanged: (bool isOpened) {
        if (isOpened) {
          print("Drawer açıldı, kullanıcı bilgileri yenileniyor");
        }
      },
    );
  }
}
