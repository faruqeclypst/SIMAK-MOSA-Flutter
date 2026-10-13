import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Empty state konsisten: ikon dalam lingkaran warna, judul, subjudul,
/// dan tombol aksi opsional.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final Color warna;
  final Color warnaSoft;
  final String judul;
  final String subjudul;
  final String? aksiLabel;
  final VoidCallback? onAksi;

  const EmptyState({
    super.key,
    required this.icon,
    required this.warna,
    required this.warnaSoft,
    required this.judul,
    required this.subjudul,
    this.aksiLabel,
    this.onAksi,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: warnaSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: warna),
            ),
            const SizedBox(height: 18),
            Text(
              judul,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subjudul,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.grey,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            if (aksiLabel != null && onAksi != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAksi,
                icon: const Icon(Icons.add, size: 20),
                label: Text(aksiLabel!),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }
}
