import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';

// Pencarian kelas & siswa via PocketBase.
class SearchResultScreen extends StatefulWidget {
  const SearchResultScreen({super.key});

  @override
  State<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  String _query = '';
  List<RecordModel> _kelas = [];
  List<RecordModel> _siswa = [];
  bool _mencari = false;

  Future<void> _cari(String q) async {
    setState(() {
      _query = q;
      _mencari = true;
    });
    if (q.trim().isEmpty) {
      setState(() {
        _kelas = [];
        _siswa = [];
        _mencari = false;
      });
      return;
    }
    try {
      final pb = PbService().pb;
      final k = await pb
          .collection('kelas')
          .getList(page: 1, perPage: 20, filter: 'nama ~ "$q"');
      final s = await pb
          .collection('siswa')
          .getList(
            page: 1,
            perPage: 30,
            filter: 'nama ~ "$q"',
            expand: 'kelas',
          );
      setState(() {
        _kelas = k.items;
        _siswa = s.items;
        _mencari = false;
      });
    } catch (_) {
      setState(() => _mencari = false);
    }
  }

  String _namaKelas(RecordModel s) {
    final n = s.getStringValue('expand.kelas.nama');
    return n.isEmpty ? '-' : n;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pencarian')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              autofocus: true,
              onChanged: _cari,
              decoration: InputDecoration(
                hintText: 'Cari kelas, siswa...',
                prefixIcon: const Icon(Icons.search, color: AppColors.grey),
                filled: true,
                fillColor: const Color(0xFFF1F1F1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? Center(
                    child: Text(
                      'Ketik untuk mencari kelas atau siswa.',
                      style: GoogleFonts.plusJakartaSans(color: AppColors.grey),
                    ),
                  )
                : _mencari
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      if (_kelas.isNotEmpty) ...[
                        Text(
                          'Kelas',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._kelas.map(
                          (k) => ListTile(
                            leading: const Icon(
                              Icons.class_outlined,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              k.getStringValue('nama'),
                              style: GoogleFonts.plusJakartaSans(),
                            ),
                            subtitle: Text(
                              '${k.getStringValue('tingkat')} • ${k.getStringValue('fase')}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.grey,
                              ),
                            ),
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_siswa.isNotEmpty) ...[
                        Text(
                          'Siswa',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._siswa.map(
                          (s) => ListTile(
                            leading: const Icon(
                              Icons.person_outlined,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              s.getStringValue('nama'),
                              style: GoogleFonts.plusJakartaSans(),
                            ),
                            subtitle: Text(
                              'Kelas ${_namaKelas(s)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.grey,
                              ),
                            ),
                            onTap: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                      if (_kelas.isEmpty && _siswa.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Center(
                            child: Text(
                              'Tidak ditemukan.',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.grey,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
