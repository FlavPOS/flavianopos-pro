#!/usr/bin/env python3
import os

HOME = os.path.expanduser("~")
FPATH = os.path.join(HOME, "myapp/lib/screens/inventory/stock_adjustment_screen.dart")

with open(FPATH, "r", encoding="utf-8") as f:
    lines = f.readlines()

# Find the Wrap( line after "Reason for Adjustment"
wrap_start = None
for i, line in enumerate(lines):
    if "Wrap(" in line.strip() and i > 290:
        wrap_start = i
        break

# Find closing of Wrap block
depth = 0
wrap_end = None
for i in range(wrap_start, len(lines)):
    for ch in lines[i]:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                wrap_end = i
                break
    if wrap_end is not None:
        break

print(f"Found Wrap block: lines {wrap_start+1} to {wrap_end+1}")

NEW_CODE = """            DropdownButtonFormField<String>(
              value: _commonReasons.contains(_reasonController.text) ? _reasonController.text : null,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.assignment, color: Colors.blue[700]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              hint: const Text('Select reason...', style: TextStyle(fontSize: 13)),
              isExpanded: true,
              items: _commonReasons.map((reason) {
                return DropdownMenuItem<String>(
                  value: reason,
                  child: Text(reason, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _reasonController.text = value);
                }
              },
            ),
"""

new_lines = lines[:wrap_start] + [NEW_CODE] + lines[wrap_end+1:]

with open(FPATH, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("DONE! Replaced Wrap chips with DropdownButtonFormField")
print("Press R in Flutter terminal!")
