f = 'lib/screens/reports/sales_analytics_screen.dart'
t = open(f).read()

# Remove dart:io, path_provider, share_plus imports
t = t.replace("import 'dart:io';\n", "")
t = t.replace("import 'package:path_provider/path_provider.dart';\n", "")
t = t.replace("import 'package:share_plus/share_plus.dart';\n", "")

# Add web-compatible imports
if 'dart:convert' not in t:
    t = t.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'dart:convert';\nimport 'package:flutter/foundation.dart' show kIsWeb;\nimport 'dart:html' as html if (dart.library.io) 'dart:io';"
    )

# Replace the try/catch block in _exportCSV with universal download
old_try = """    try {
      final dir = await getApplicationDocumentsDirectory();
      final tabNames = ['by_item', 'by_category', 'trends'];
      final fileName = 'sales_${tabNames[tab]}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles([XFile(file.path)], subject: 'Sales Report CSV');
    } catch (e) {
      if (mounted) _snack('Error: $e');
    }"""

new_try = """    final csvStr = buf.toString();
    final tabNames = ['by_item', 'by_category', 'trends'];
    final fileName = 'sales_${tabNames[tab]}_${DateTime.now().millisecondsSinceEpoch}.csv';
    try {
      final bytes = utf8.encode(csvStr);
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      _snack('CSV downloaded: $fileName');
    } catch (e) {
      _snack('Error: $e');
    }"""

t = t.replace(old_try, new_try)

open(f, 'w').write(t)
print('Done! Web-compatible CSV download.')
