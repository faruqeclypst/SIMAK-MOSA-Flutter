import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'pb_service.dart';

/// Membangun PDF Laporan Monitoring KBM hari ini:
/// statistik + tabel status tiap kelas, lalu dibuka lewat dialog cetak/simpan.
Future<void> cetakLaporanMonitoring(BuildContext context) async {
  final nav = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    final svc = PbService();
    final tgl = svc.tanggalHariIni();
    final hari = svc.hariIni();

    final kRes = await svc.pb
        .collection('kelas')
        .getList(page: 1, perPage: 100, sort: 'nama');
    final jRes = await svc.pb
        .collection('jurnal')
        .getList(
          page: 1,
          perPage: 500,
          filter: 'tanggal >= "$tgl 00:00:00" && tanggal <= "$tgl 23:59:59"',
        );
    final terisiIds = jRes.items.map((j) => j.getStringValue('kelas')).toSet();

    final baris = kRes.items
        .map(
          (k) => (
            nama: k.getStringValue('nama'),
            terisi: terisiIds.contains(k.id),
          ),
        )
        .toList();
    final jmlTerisi = baris.where((b) => b.terisi).length;

    final bytes = await _bangunPdf(
      hari: hari,
      tanggal: tgl,
      total: baris.length,
      terisi: jmlTerisi,
      baris: baris,
      pencetak: '${svc.nama} (${svc.peranLabel})',
    );

    nav.pop();
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'laporan-monitoring-$tgl.pdf',
    );
  } catch (_) {
    nav.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Gagal membuat PDF. Coba lagi.')),
    );
  }
}

Future<Uint8List> _bangunPdf({
  required String hari,
  required String tanggal,
  required int total,
  required int terisi,
  required List<({String nama, bool terisi})> baris,
  required String pencetak,
}) async {
  final doc = pw.Document();
  const hijau = PdfColor.fromInt(0xFF065F46);
  const merah = PdfColor.fromInt(0xFFDC2626);
  const abu = PdfColor.fromInt(0xFF6B7280);

  String fmtTgl(String iso) {
    const bulan = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final p = iso.split('-');
    if (p.length != 3) return iso;
    final b = int.tryParse(p[1]) ?? 0;
    final namaBulan = (b >= 1 && b <= 12) ? bulan[b] : p[1];
    return '${int.tryParse(p[2]) ?? p[2]} $namaBulan ${p[0]}';
  }

  pw.MemoryImage? logoImg;
  try {
    final assetData = await rootBundle.load('assets/images/logo.png');
    logoImg = pw.MemoryImage(assetData.buffer.asUint8List());
  } catch (_) {}

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SIMAK MOSA • SMAN Modal Bangsa',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: abu,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Laporan Monitoring KBM',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    '$hari, ${fmtTgl(tanggal)}',
                    style: const pw.TextStyle(fontSize: 11, color: abu),
                  ),
                ],
              ),
              if (logoImg != null)
                pw.Container(
                  width: 44,
                  height: 44,
                  child: pw.Image(logoImg),
                ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(thickness: 1.5),
        ],
      ),
      footer: (ctx) => pw.Column(
        children: [
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Dicetak oleh $pencetak',
                style: const pw.TextStyle(fontSize: 9, color: abu),
              ),
              pw.Text(
                'Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: abu),
              ),
            ],
          ),
        ],
      ),
      build: (_) => [
        pw.Row(
          children: [
            _kotakStat('Total Kelas', '$total', abu),
            pw.SizedBox(width: 12),
            _kotakStat('Terisi', '$terisi', hijau),
            pw.SizedBox(width: 12),
            _kotakStat('Kosong', '${total - terisi}', merah),
          ],
        ),
        pw.SizedBox(height: 20),
        pw.Text(
          'Status KBM per Kelas',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['No', 'Kelas', 'Status'],
          data: [
            for (var i = 0; i < baris.length; i++)
              [
                '${i + 1}',
                baris[i].nama,
                baris[i].terisi ? 'TERISI' : 'KOSONG',
              ],
          ],
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 11,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF1E7A5A),
          ),
          cellStyle: const pw.TextStyle(fontSize: 11),
          cellAlignments: {
            0: pw.Alignment.center,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.center,
          },
          columnWidths: {
            0: const pw.FixedColumnWidth(40),
            2: const pw.FixedColumnWidth(90),
          },
        ),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _kotakStat(String label, String angka, PdfColor warna) {
  return pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            angka,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: warna,
            ),
          ),
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromInt(0xFF6B7280),
            ),
          ),
        ],
      ),
    ),
  );
}
