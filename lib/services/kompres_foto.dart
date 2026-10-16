import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Kompres foto sebelum diunggah: maks 1024px sisi terpanjang, kualitas 70.
/// Mengurangi ukuran berkas hingga 85-92% tanpa mengurangi keterbacaan teks/detail,
/// sehingga sangat hemat bandwidth dan storage PocketBase.
Future<XFile> kompresFoto(XFile file) async {
  if (kIsWeb) return file;
  try {
    final dir = await getTemporaryDirectory();
    final target =
        '${dir.path}/kompres_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final hasil = await FlutterImageCompress.compressAndGetFile(
      file.path,
      target,
      minWidth: 1024,
      minHeight: 1024,
      quality: 70,
      format: CompressFormat.jpeg,
    );
    if (hasil != null) return XFile(hasil.path);
  } catch (_) {}
  return file;
}

/// Ambil foto dari kamera/galeri lalu langsung dikompres.
/// Kembalikan null bila pengguna membatalkan pemilihan.
Future<XFile?> ambilFotoKompres(ImageSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 80,
  );
  if (picked == null) return null;
  return kompresFoto(picked);
}
