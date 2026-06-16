f = 'lib/screens/reports/sales_analytics_screen.dart'
t = open(f).read()

# Remove problematic imports
t = t.replace("import 'dart:io';\n", "")
t = t.replace("import 'package:path_provider/path_provider.dart';\n", "")
t = t.replace("import 'package:share_plus/share_plus.dart';\n", "")
t = t.replace("import 'dart:convert';\n", "")
t = t.replace("import 'package:flutter/foundation.dart' show kIsWeb;\n", "")
t = t.replace("import 'dart:html' as html if (dart.library.io) 'dart:io';\n", "")

# Add only what we need
if 'services.dart' not in t:
    t = t.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';"
    )

# Replace try/catch with clipboard copy approach (works everywhere)
old_block = t[t.index('    try {'):t.index("    }\n  }\n\n  void _snack")+5]

new_block = """    final csvStr = buf.toString();
    await Clipboard.setData(ClipboardData(text: csvStr));
    if (mounted) _snack('CSV data copied to clipboard! Paste into any spreadsheet app.');
  }"""

t = t[:t.index('    try {')] + new_block + t[t.index("  void _snack"):]

open(f, 'w').write(t)
print('Done! CSV copies to clipboard.')
