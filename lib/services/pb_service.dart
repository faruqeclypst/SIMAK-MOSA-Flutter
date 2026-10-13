import 'package:characters/characters.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Akses terpusat ke backend PocketBase SIMAK-MOSA.
/// Base URL menunjuk ke instance pb-simak di VPS.
class PbService {
  static const baseUrl = 'https://pb-simak.alfaruqasri.my.id';

  static final PbService _instance = PbService._internal();
  factory PbService() => _instance;
  PbService._internal();

  late final PocketBase pb;
  bool _ready = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final store = AsyncAuthStore(
      save: (String data) async => prefs.setString('pb_auth', data),
      initial: prefs.getString('pb_auth'),
      clear: () async => prefs.remove('pb_auth'),
    );
    pb = PocketBase(baseUrl, authStore: store);
    _ready = true;
    if (pb.authStore.isValid) {
      try {
        await pb.collection('users').authRefresh();
      } catch (_) {
        pb.authStore.clear();
      }
    }
  }

  bool get isLoggedIn => _ready && pb.authStore.isValid;

  /// Record user yang sedang login (null kalau belum login).
  RecordModel? get me => pb.authStore.record;

  String get nama =>
      me?.getStringValue('nama_lengkap').trim().isNotEmpty == true
      ? me!.getStringValue('nama_lengkap')
      : (me?.getStringValue('name') ?? 'Guru');

  String get username => me?.getStringValue('username') ?? '';
  String get mapel => me?.getStringValue('mapel') ?? '';
  String get peran => me?.getStringValue('peran') ?? 'guru';
  String get kodeGuru => me?.getStringValue('kode_guru') ?? '';
  bool get isAdmin => peran == 'admin';
  bool get isGuru => peran == 'guru';
  bool get isKurikulum => peran == 'kurikulum';
  bool get isAsrama => peran == 'asrama';
  bool get isWaka => peran == 'waka';
  bool get isSatpam => peran == 'satpam';
  bool get isPiket => peran == 'piket';

  static const peranLabels = {
    'admin': 'Administrator',
    'guru': 'Guru',
    'kurikulum': 'Kurikulum',
    'asrama': 'Asrama',
    'waka': 'Wakil Kepala',
    'satpam': 'Satpam (PKD)',
    'piket': 'Guru Piket',
  };

  String get peranLabel => peranLabels[peran] ?? peran;

  /// Hak akses modul tulis (selain admin).
  bool get canKelolaPiket => isAdmin || isPiket;
  bool get canKelolaAsrama => isAdmin || isAsrama;
  bool get canKelolaKeterlambatan => isAdmin || isSatpam;
  bool get canKelolaBerhalangan => isAdmin || isKurikulum || isPiket;
  bool get canKelolaPengumuman => isAdmin;
  bool get canLihatMonitoring =>
      isAdmin || isWaka || isKurikulum || isPiket || isAsrama;

  String get inisial {
    final n = nama.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  /// URL foto profil (string kosong kalau belum ada).
  String avatarUrl() {
    final m = me;
    if (m == null) return '';
    final file = m.getStringValue('avatar');
    if (file.isEmpty) return '';
    return pb.files.getURL(m, file).toString();
  }

  Future<void> login(String identity, String password) async {
    await pb.collection('users').authWithPassword(identity, password);
  }

  Future<void> logout() async {
    pb.authStore.clear();
  }

  /// Refresh data user dari server (mis. setelah edit profil).
  Future<void> refreshMe() async {
    if (!isLoggedIn) return;
    try {
      await pb.collection('users').authRefresh();
    } catch (_) {}
  }

  String hariIni() {
    const hari = [
      '',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return hari[DateTime.now().weekday];
  }

  String tanggalHariIni() {
    final d = DateTime.now();
    final tgl =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return tgl;
  }

  /// Waktu UTC format PocketBase ("2026-10-13 12:34:56").
  /// Dipakai untuk chat_baca.terakhir agar perbandingan string
  /// dengan created (UTC) valid.
  String waktuUtc() {
    final n = DateTime.now().toUtc();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${p(n.month)}-${p(n.day)} '
        '${p(n.hour)}:${p(n.minute)}:${p(n.second)}';
  }
}
