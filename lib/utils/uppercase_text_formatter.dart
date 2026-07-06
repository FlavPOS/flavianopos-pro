// lib/utils/uppercase_text_formatter.dart
import 'package:flutter/services.dart';

/// Automatically converts text to uppercase as user types
/// Used for Branch Code, SKU, and other identifier fields
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
