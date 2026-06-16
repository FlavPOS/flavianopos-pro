// lib/utils/web_download_stub.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> _shareFile(Uint8List bytes, String filename, String mimeType) async {
  final dir = await getTemporaryDirectory();
  final filePath = '${dir.path}/$filename';
  final file = File(filePath);
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(filePath, mimeType: mimeType)],
      subject: filename,
    ),
  );
}

void downloadPdf(Uint8List bytes, String filename) {
  _shareFile(bytes, filename, 'application/pdf');
}

void downloadExcel(Uint8List bytes, String filename) {
  _shareFile(bytes, filename,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
}

void downloadCsv(Uint8List bytes, String filename) {
  _shareFile(bytes, filename, 'text/csv');
}
