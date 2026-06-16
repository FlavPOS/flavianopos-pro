// lib/utils/download_helper_io.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String> saveFileBytes(String fileName, List<int> bytes) async {
  final dir = await getTemporaryDirectory();
  final filePath = '${dir.path}/$fileName';
  final file = File(filePath);
  await file.writeAsBytes(bytes);

  String mimeType = 'application/octet-stream';
  if (fileName.endsWith('.pdf')) {
    mimeType = 'application/pdf';
  } else if (fileName.endsWith('.xlsx')) {
    mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  } else if (fileName.endsWith('.csv')) {
    mimeType = 'text/csv';
  }

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(filePath, mimeType: mimeType)],
      subject: fileName,
    ),
  );

  return filePath;
}
