// DATA CONTOH untuk preview. Belum terhubung ke PocketBase.
// Nanti diganti dengan repository yang baca dari PocketBase.

class MockData {
  static const namaGuru = 'Pak Andi';
  static const inisialGuru = 'PA';
  static const mapelGuru = 'Matematika';

  static const kelasTerisi = 15;
  static const kelasKosong = 3;

  // 18 kelas sesuai struktur asli: X-1..X-6, XI-1..XI-6, XII-1..XII-6
  static const List<String> semuaKelas = [
    'X-1',
    'X-2',
    'X-3',
    'X-4',
    'X-5',
    'X-6',
    'XI-1',
    'XI-2',
    'XI-3',
    'XI-4',
    'XI-5',
    'XI-6',
    'XII-1',
    'XII-2',
    'XII-3',
    'XII-4',
    'XII-5',
    'XII-6',
  ];

  // Status monitoring KBM hari ini (contoh)
  static const Map<String, bool> statusKelas = {
    'X-1': true,
    'X-2': true,
    'X-3': false,
    'X-4': true,
    'X-5': true,
    'X-6': true,
    'XI-1': true,
    'XI-2': true,
    'XI-3': true,
    'XI-4': true,
    'XI-5': false,
    'XI-6': true,
    'XII-1': true,
    'XII-2': true,
    'XII-3': true,
    'XII-4': false,
    'XII-5': true,
    'XII-6': true,
  };

  static const List<Map<String, String>> jadwalHariIni = [
    {
      'jam': '07:30 - 09:00',
      'mapel': 'Matematika',
      'kelas': 'XII IPA 2',
      'ruang': 'Ruang C201',
    },
    {
      'jam': '09:30 - 11:00',
      'mapel': 'Matematika',
      'kelas': 'XI IPA 1',
      'ruang': 'Ruang B104',
    },
    {
      'jam': '13:00 - 14:30',
      'mapel': 'Matematika',
      'kelas': 'X-3',
      'ruang': 'Ruang A207',
    },
  ];

  // Contoh daftar siswa satu kelas (disederhanakan dari 36 untuk preview)
  static const List<String> siswaContoh = [
    'Ahmad Fauzi',
    'Siti Aisyah',
    'Budi Santoso',
    'Dewi Lestari',
    'Rizky Pratama',
    'Putri Maharani',
    'Andi Wijaya',
    'Nina Kurnia',
    'Fajar Ramadhan',
    'Intan Permata',
    'Yoga Saputra',
    'Maya Anggraini',
  ];

  // Catatan izin/piket/asrama hari ini yang muncul otomatis sebagai badge
  static const Map<String, String> badgeIzin = {
    'Budi Santoso': 'Izin piket: izin ke UKS jam ke-2',
    'Maya Anggraini': 'Asrama: sakit, istirahat di asrama',
  };

  static const List<Map<String, String>> riwayatJurnal = [
    {
      'tanggal': 'Senin, 13 Okt 2026',
      'kelas': 'XII IPA 2',
      'jam': 'Jam ke-1, 2',
      'materi': 'Limit fungsi aljabar',
      'absensi': '30 hadir, 1 sakit, 1 izin',
      'catatan': 'Aman',
    },
    {
      'tanggal': 'Senin, 13 Okt 2026',
      'kelas': 'XI IPA 1',
      'jam': 'Jam ke-3, 4',
      'materi': 'Persamaan kuadrat',
      'absensi': '31 hadir, 1 alpa',
      'catatan': 'Satu siswa alpa tanpa keterangan',
    },
    {
      'tanggal': 'Jumat, 10 Okt 2026',
      'kelas': 'X-3',
      'jam': 'Jam ke-5, 6',
      'materi': 'Himpunan',
      'absensi': '32 hadir',
      'catatan': 'Aman',
    },
  ];

  static const List<Map<String, String>> aktivitas = [
    {
      'judul': 'Jurnal Kelas XII IPA 2 telah disubmit',
      'sub': 'Hari ini, 09:15 - Disetujui',
    },
    {
      'judul': 'Izin sakit: Budi Santoso telah disetujui',
      'sub': 'Kemarin, 14:30 - Izin 1 hari',
    },
    {
      'judul': 'Jadwal piket minggu ini diperbarui',
      'sub': 'Kemarin, 09:10 - Oleh guru piket',
    },
  ];

  static const List<Map<String, String>> notifikasi = [
    {
      'judul': '3 siswa mengajukan izin',
      'sub': 'Menunggu persetujuan - 20 menit lalu',
    },
    {'judul': 'Jurnal XI IPA 1 disetujui kurikulum', 'sub': '1 jam lalu'},
    {'judul': 'Pengingat: isi jurnal sebelum 15:00', 'sub': '2 jam lalu'},
  ];
}
