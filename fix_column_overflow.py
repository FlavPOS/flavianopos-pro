#!/usr/bin/env python3
import os

HOME = os.path.expanduser("~")
FPATH = os.path.join(HOME, "myapp/lib/screens/reports/sales_analytics_screen.dart")

with open(FPATH, "r", encoding="utf-8") as f:
    lines = f.readlines()

fixes = 0
new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    # Find: width: contentW,
    # Next line: child: Column(
    # Add: height: constraints.maxHeight,
    if "width: contentW," in line.strip():
        if i + 1 < len(lines) and "child: Column(" in lines[i + 1]:
            indent = line[:len(line) - len(line.lstrip())]
            new_lines.append(f"{indent}height: constraints.maxHeight,\n")
            fixes += 1
            print(f"  Line {i+1}: Added height: constraints.maxHeight")

with open(FPATH, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

if fixes > 0:
    print(f"\nFIXED {fixes} SizedBox(es) - Column overflow resolved!")
else:
    print("No changes needed.")
print("Now press R in Flutter terminal for hot restart!")
