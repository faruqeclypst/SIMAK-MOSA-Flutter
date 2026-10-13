import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pocketbase/pocketbase.dart';

import '../services/pb_service.dart';
import '../theme/app_theme.dart';

// Banner pengumuman terbaru di beranda.
// Tujuan: pengumuman admin langsung terlihat tanpa harus buka tab Notifikasi.
// Ketuk untuk buka/tutup isi, "Lihat semua" pindah ke tab Notifikasi.
class PengumumanBanner extends StatefulWidget {
  final VoidCallback onLihatSemua;

  const PengumumanBanner({super.key, required this.onLihatSemua});

  @override
  State<PengumumanBanner> createState() => _PengumumanBannerState();
}

class _PengumumanBannerState extends State<PengumumanBanner> {
  RecordModel? _terbaru;
  bool _buka = false;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final res = await PbService().pb
          .collection('pengumuman')
          .getList(page: 1, perPage: 1, sort: '-tanggal,-created');
      if (mounted && res.items.isNotEmpty) {
        setState(() => _terbaru = res.items.first);
      }
    } catch (_) {}
  }

  String _fmtTanggal(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      const bulan = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
      ];
      return '${d.day} ${bulan[d.month]} ${d.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _terbaru;
    if (n == null) return const SizedBox.shrink();
    final judul = n.getStringValue('judul');
    final isi = n.getStringValue('isi');
    return GestureDetector(
      onTap: () => setState(() => _buka = !_buka),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          border: Border.all(color: const Color(0xFFFDE68A)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: Color(0xFFB45309),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PENGUMUMAN',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                      Text(
                        judul,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: _buka ? null : 1,
                        overflow: _buka ? null : TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  _buka
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.grey,
                ),
              ],
            ),
            if (_buka) ...[
              const SizedBox(height: 8),
              Text(
                isi,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmtTanggal(n.getStringValue('tanggal')),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.grey,
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onLihatSemua,
                    child: Text(
                      'Lihat semua',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
