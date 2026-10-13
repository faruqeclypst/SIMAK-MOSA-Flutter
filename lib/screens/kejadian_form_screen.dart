import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/kompres_foto.dart';
import '../services/pb_service.dart';
import '../theme/app_theme.dart';

// Cap instan ala IG: langsung buka kamera, lalu isi detail seperti status WA.
Future<void> bukaCapInstan(BuildContext context) async {
  final foto = await ambilFotoKompres(ImageSource.camera);
  if (foto == null) return; // pengguna batal
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => KejadianFormScreen(fotoAwal: foto)),
  );
}

// Form Cap on Spot: foto cepat + kategori + deskripsi kejadian.
class KejadianFormScreen extends StatefulWidget {
  final XFile? fotoAwal;
  const KejadianFormScreen({super.key, this.fotoAwal});

  @override
  State<KejadianFormScreen> createState() => _KejadianFormScreenState();
}

class _KejadianFormScreenState extends State<KejadianFormScreen> {
  final _judulCtrl = TextEditingController();
  final _desCtrl = TextEditingController();
  String _kategori = 'Peristiwa';
  XFile? _foto;
  bool _saving = false;
  static const _daftarKategori = [
    'Pelanggaran',
    'Anomali',
    'Peristiwa',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _foto = widget.fotoAwal;
  }

  @override
  void dispose() {
    _judulCtrl.dispose();
    _desCtrl.dispose();
    super.dispose();
  }

  Future<void> _ambilFoto(ImageSource src) async {
    try {
      final f = await ambilFotoKompres(src);
      if (f != null && mounted) setState(() => _foto = f);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa mengakses kamera/galeri.')),
        );
      }
    }
  }

  void _pilihSumberFoto() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                'Ambil foto',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _ambilFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                'Pilih dari galeri',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _ambilFoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _simpan() async {
    if (_judulCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Isi judul kejadian dulu.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final svc = PbService();
      final files = <http.MultipartFile>[];
      if (_foto != null) {
        if (kIsWeb) {
          final bytes = await _foto!.readAsBytes();
          files.add(
            http.MultipartFile.fromBytes('foto', bytes, filename: _foto!.name),
          );
        } else {
          files.add(await http.MultipartFile.fromPath('foto', _foto!.path));
        }
      }
      await svc.pb
          .collection('kejadian')
          .create(
            body: {
              'judul': _judulCtrl.text.trim(),
              'deskripsi': _desCtrl.text.trim(),
              'kategori': _kategori,
              'pelapor': svc.me!.id,
              'tanggal': '${svc.tanggalHariIni()} 07:00:00',
            },
            files: files,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kejadian tercatat. Terima kasih!')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan. Coba lagi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cap Kejadian')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GestureDetector(
            onTap: _pilihSumberFoto,
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: _foto == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_a_photo_outlined,
                          size: 44,
                          color: AppColors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ketuk untuk ambil foto (opsional)',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: kIsWeb
                          ? Image.network(
                              _foto!.path,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : Image.file(
                              File(_foto!.path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kategori',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _daftarKategori.map((k) {
              final aktif = _kategori == k;
              return ChoiceChip(
                label: Text(k),
                selected: aktif,
                onSelected: (_) => setState(() => _kategori = k),
                selectedColor: AppColors.primary,
                labelStyle: GoogleFonts.plusJakartaSans(
                  color: aktif ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Judul Kejadian',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _judulCtrl,
            decoration: const InputDecoration(
              hintText: 'mis. Siswa merokok di kantin',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Deskripsi (opsional)',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _desCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Ceritakan singkat apa yang terjadi...',
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _saving ? null : _simpan,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.bolt_outlined),
            label: Text(_saving ? 'Menyimpan...' : 'Cap Sekarang'),
          ),
        ],
      ),
    );
  }
}
