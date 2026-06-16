// lib/utils/web_download.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void _download(Uint8List bytes, String filename, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url);
  anchor.download = filename;
  anchor.click();
  html.Url.revokeObjectUrl(url);
}

void downloadPdf(Uint8List bytes, String filename) {
  _download(bytes, filename, 'application/pdf');
}

void downloadExcel(Uint8List bytes, String filename) {
  _download(bytes, filename,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
}

void downloadCsv(Uint8List bytes, String filename) {
  _download(bytes, filename, 'text/csv');
}
