import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

// Kompres foto sebelum diunggah: maks 1280px sisi terpanjang, kualitas 75.
// Semua unggahan foto di aplikasi WAJIB lewat sini agar hemat kuota & storage.
Future<XFile> kompresFoto(XFile file) async {
  if (kIsWeb) return file;
  try {
    final dir = await getTemporaryDirectory();
    final target =
        '${dir.path}/kompres_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final hasil = await FlutterImageCompress.compressAndGetFile(
      file.path,
      target,
      minWidth: 1280,
      minHeight: 1280,
      quality: 75,
      format: CompressFormat.jpeg,
    );
    if (hasil != null) return XFile(hasil.path);
  } catch (_) {}
  return file;
}

/// Ambil foto dari kamera/galeri lalu langsung dikompres.
/// Kembalikan null bila pengguna batal.
Future<XFile?> ambilFotoKompres(ImageSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1920,
    maxHeight: 1920,
  );
  if (picked == null) return null;
  return kompresFoto(picked);
}
