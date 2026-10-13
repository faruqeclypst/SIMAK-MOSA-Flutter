import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

// Kutipan motivasi harian (berganti tiap hari) + Kabar Sekolah dari
// WordPress SMAN Modal Bangsa. Kalau API tidak bisa dijangkau,
// hanya kutipan yang tampil — space tetap terisi rapi.
class KabarSekolah extends StatefulWidget {
  const KabarSekolah({super.key});

  @override
  State<KabarSekolah> createState() => _KabarSekolahState();
}

const _kutipan = [
  ('Ilmu itu cahaya, adab itu wadahnya.', 'Pepatah Arab'),
  (
    'Sebaik-baik kalian adalah yang paling bermanfaat bagi sesama.',
    'HR. Ahmad',
  ),
  ('Menuntut ilmu itu wajib bagi setiap muslim.', 'HR. Ibnu Majah'),
  ('Kesuksesan adalah buah dari kedisiplinan yang dijaga tiap hari.', 'Anonim'),
  (
    'Jangan menunggu termotivasi. Mulailah, maka motivasi akan datang.',
    'Anonim',
  ),
  ('Guru yang baik menginspirasi, bukan sekadar menginstruksi.', 'Anonim'),
  ('Sedikit demi sedikit, lama-lama menjadi bukit.', 'Peribahasa'),
  ('Hari ini belajar satu hal baru, esok jadi lebih baik.', 'Anonim'),
  ('Disiplin adalah jembatan antara tujuan dan pencapaian.', 'Jim Rohn'),
  ('Ilmu tanpa amal ibarat pohon tanpa buah.', 'Pepatah Arab'),
];

class _Berita {
  final String judul;
  final String tanggal;
  final String link;
  final String gambar;
  _Berita(this.judul, this.tanggal, this.link, this.gambar);
}

class _KabarSekolahState extends State<KabarSekolah> {
  List<_Berita> _berita = [];
  bool _selesaiMuat = false;

  @override
  void initState() {
    super.initState();
    _muatBerita();
  }

  String _bersihkanHtml(String s) {
    return s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#8211;', '-')
        .replaceAll('&#8217;', "'")
        .trim();
  }

  String _fmtTanggal(String iso) {
    try {
      final d = DateTime.parse(iso);
      const bulan = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${d.day} ${bulan[d.month]} ${d.year}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _muatBerita() async {
    try {
      final res = await http
          .get(
            Uri.parse(
              'https://sman-modalbangsa.sch.id/wp-json/wp/v2/posts'
              '?per_page=6&_embed=wp:featuredmedia&_fields=id,date,link,title,_embedded',
            ),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw Exception('http ${res.statusCode}');
      final data = jsonDecode(res.body) as List;
      final list = <_Berita>[];
      for (final p in data) {
        String gambar = '';
        try {
          final media =
              (p['_embedded']?['wp:featuredmedia'] as List?)?.firstOrNull;
          gambar = media?['source_url']?.toString() ?? '';
        } catch (_) {}
        list.add(
          _Berita(
            _bersihkanHtml(p['title']?['rendered']?.toString() ?? ''),
            _fmtTanggal(p['date']?.toString() ?? ''),
            p['link']?.toString() ?? '',
            gambar,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _berita = list;
          _selesaiMuat = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _selesaiMuat = true);
    }
  }

  Future<void> _buka(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final hariKe = DateTime.now()
        .difference(DateTime(DateTime.now().year, 1, 1))
        .inDays;
    final q = _kutipan[hariKe % _kutipan.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kutipan harian
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF065F46), Color(0xFF00AA13)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.format_quote,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'KUTIPAN HARI INI',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '"${q.$1}"',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '— ${q.$2}',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),

        // Kabar sekolah dari web
        if (_berita.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            child: Row(
              children: [
                Text(
                  'Kabar Sekolah',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _buka('https://sman-modalbangsa.sch.id/'),
                  child: Text(
                    'Lihat Semua',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _berita.length,
              itemBuilder: (_, i) {
                final b = _berita[i];
                return GestureDetector(
                      onTap: () => _buka(b.link),
                      child: Container(
                        width: 220,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.line),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(18),
                              ),
                              child: b.gambar.isNotEmpty
                                  ? Image.network(
                                      b.gambar,
                                      height: 120,
                                      width: 220,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          _gambarPengganti(),
                                    )
                                  : _gambarPengganti(),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.judul,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 12,
                                        color: AppColors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        b.tanggal,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          color: AppColors.grey,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(
                                        Icons.arrow_forward,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: i * 80))
                    .slideX(begin: 0.1, end: 0);
              },
            ),
          ),
          const SizedBox(height: 8),
        ] else if (!_selesaiMuat)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _gambarPengganti() {
    return Container(
      height: 120,
      width: 220,
      color: AppColors.primarySoft,
      child: const Icon(
        Icons.newspaper_outlined,
        color: AppColors.primary,
        size: 36,
      ),
    );
  }
}
