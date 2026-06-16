#!/usr/bin/env python3
import os

HOME = os.path.expanduser("~")
FPATH = os.path.join(HOME, "myapp/lib/screens/reports/sales_analytics_screen.dart")

with open(FPATH, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
fixes = 0
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    # Find: "return SingleChildScrollView("
    # Next line: "child: Column("
    # Replace both with: "return Column("
    if "return SingleChildScrollView(" in stripped:
        if i + 1 < len(lines) and "child: Column(" in lines[i + 1].strip():
            indent = line[:len(line) - len(line.lstrip())]
            new_lines.append(f"{indent}return Column(\n")
            fixes += 1
            print(f"  Line {i+1}: Removed SingleChildScrollView wrapper")
            i += 2  # skip both lines
            continue

    new_lines.append(line)
    i += 1

if fixes > 0:
    with open(FPATH, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    print(f"\nUndone! Removed {fixes} bad SingleChildScrollView wrappers.")
    print("Press R in Flutter terminal for hot restart!")
else:
    print("Nothing to undo.")
