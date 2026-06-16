#!/usr/bin/env python3
import os

HOME = os.path.expanduser("~")
FPATH = os.path.join(HOME, "myapp/lib/screens/reports/sales_analytics_screen.dart")

with open(FPATH, "r", encoding="utf-8") as f:
    lines = f.readlines()

start_idx = None
for i in range(len(lines)):
    if "Colors.grey[50]" in lines[i]:
        block = "".join(lines[i:min(len(lines), i+20)])
        if "ListView.builder" in block and "FilterChip" in block:
            for j in range(i, max(0, i-5), -1):
                if "Container(" in lines[j]:
                    start_idx = j
                    break
            break

if start_idx is None:
    print("Already updated or not found.")
    exit(0)

depth = 0
end_idx = None
for i in range(start_idx, len(lines)):
    for ch in lines[i]:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                end_idx = i
                break
    if end_idx is not None:
        break

print(f"Found FilterChip block: lines {start_idx+1} to {end_idx+1}")

NEW_CODE = """          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() => _dateFilter = value);
                    if (value == 'Custom') _pickDateRange();
                  },
                  itemBuilder: (context) => _dateFilters.map((f) {
                    final sel = _dateFilter == f;
                    return PopupMenuItem<String>(
                      value: f,
                      child: Row(
                        children: [
                          if (sel) Icon(Icons.check, size: 16, color: Colors.teal[700]),
                          if (sel) const SizedBox(width: 8),
                          Text(f, style: TextStyle(
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            color: sel ? Colors.teal[700] : Colors.black87,
                          )),
                        ],
                      ),
                    );
                  }).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.teal[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.teal[700]),
                        const SizedBox(width: 6),
                        Text(_dateFilter, style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal[700],
                        )),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, size: 18, color: Colors.teal[700]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
"""

new_lines = lines[:start_idx] + [NEW_CODE] + lines[end_idx+1:]

with open(FPATH, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("FIXED: sales_analytics_screen.dart")
print("  Old: Horizontal FilterChip row")
print("  New: PopupMenuButton dropdown")
print("Now press r in Flutter terminal to hot reload!")
