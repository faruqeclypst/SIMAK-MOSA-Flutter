import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/kompres_foto.dart';
import '../services/pb_service.dart';
import '../theme/app_theme.dart';
import 'pengaturan_screen.dart';
import 'login_screen.dart';

// Profil guru: foto, nama, username, mapel, peran + edit & pengaturan.
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  bool _uploading = false;

  Future<void> _gantiFoto() async {
    final xfile = await ambilFotoKompres(ImageSource.gallery);
    if (xfile == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await xfile.readAsBytes();
      final pb = PbService().pb;
      final me = PbService().me!;
      await pb
          .collection('users')
          .update(
            me.id,
            files: [
              http.MultipartFile.fromBytes(
                'avatar',
                bytes,
                filename: 'avatar.jpg',
              ),
            ],
          );
      await PbService().refreshMe();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil diperbarui.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengunggah foto. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _keluar() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await PbService().logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            child: const Text('Keluar', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = PbService();
    final avatar = svc.avatarUrl();

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.primarySoft,
                      backgroundImage: avatar.isNotEmpty
                          ? NetworkImage(avatar)
                          : null,
                      child: avatar.isEmpty
                          ? Text(
                              svc.inisial,
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 36,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _uploading ? null : _gantiFoto,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: _uploading
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  svc.nama,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    svc.peranLabel.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.primaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _InfoTile(label: 'Username', value: svc.username),
          _InfoTile(
            label: 'Email',
            value: svc.me?.getStringValue('email') ?? '-',
          ),
          _InfoTile(
            label: 'Mata Pelajaran Diampu',
            value: svc.mapel.isEmpty ? '-' : svc.mapel,
          ),
          if (svc.kodeGuru.isNotEmpty)
            _InfoTile(label: 'Kode Guru', value: svc.kodeGuru),
          const SizedBox(height: 8),
          _MenuItem(
            icon: Icons.edit_outlined,
            label: 'Edit Profil',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilScreen()),
              );
              if (mounted) setState(() {});
            },
          ),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: 'Pengaturan',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PengaturanScreen()),
              );
            },
          ),
          _MenuItem(
            icon: Icons.logout,
            label: 'Keluar',
            warna: AppColors.red,
            onTap: _keluar,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.greyLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color warna;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.warna = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: warna),
        title: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: warna,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
        onTap: onTap,
      ),
    );
  }
}

// Form edit profil: nama lengkap, username, mapel, kode guru.
class EditProfilScreen extends StatefulWidget {
  const EditProfilScreen({super.key});

  @override
  State<EditProfilScreen> createState() => _EditProfilScreenState();
}

class _EditProfilScreenState extends State<EditProfilScreen> {
  late final TextEditingController _nama;
  late final TextEditingController _username;
  late final TextEditingController _mapel;
  late final TextEditingController _kode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final svc = PbService();
    _nama = TextEditingController(text: svc.nama);
    _username = TextEditingController(text: svc.username);
    _mapel = TextEditingController(text: svc.mapel);
    _kode = TextEditingController(text: svc.kodeGuru);
  }

  @override
  void dispose() {
    _nama.dispose();
    _username.dispose();
    _mapel.dispose();
    _kode.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_nama.text.trim().isEmpty || _username.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan username wajib diisi.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final svc = PbService();
      await svc.pb
          .collection('users')
          .update(
            svc.me!.id,
            body: {
              'nama_lengkap': _nama.text.trim(),
              'username': _username.text.trim(),
              'mapel': _mapel.text.trim(),
              'kode_guru': _kode.text.trim(),
            },
          );
      await svc.refreshMe();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profil diperbarui.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan. Username mungkin sudah dipakai.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nama,
            decoration: const InputDecoration(labelText: 'Nama Lengkap'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _mapel,
            decoration: const InputDecoration(
              labelText: 'Mata Pelajaran Diampu',
              hintText: 'mis. Informatika',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _kode,
            decoration: const InputDecoration(
              labelText: 'Kode Guru (inisial)',
              hintText: 'mis. PA',
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _simpan,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
