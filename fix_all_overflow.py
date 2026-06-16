#!/usr/bin/env python3
import os

HOME = os.path.expanduser("~")
FPATH = os.path.join(HOME, "myapp/lib/screens/reports/sales_analytics_screen.dart")

with open(FPATH, "r", encoding="utf-8") as f:
    lines = f.readlines()

fixes = 0
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    # Find: "return Column(" or "child: Column("
    if stripped in ["return Column(", "child: Column("] or stripped.startswith("return Column(") or stripped.startswith("child: Column("):
        # Check next 30 lines for "Expanded(" — means this Column has flex children
        lookahead = "".join(lines[i:min(len(lines), i+30)])
        has_expanded = "Expanded(" in lookahead

        # Check if clipBehavior already added
        next_line = lines[i+1].strip() if i+1 < len(lines) else ""
        already_has_clip = "clipBehavior" in next_line

        if has_expanded and not already_has_clip:
            indent = line[:len(line) - len(line.lstrip())]
            new_lines.append(line)
            new_lines.append(f"{indent}  clipBehavior: Clip.hardEdge,\n")
            fixes += 1
            print(f"  Line {i+1}: Added clipBehavior: Clip.hardEdge to Column")
            i += 1
            continue

    new_lines.append(line)
    i += 1

if fixes > 0:
    with open(FPATH, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
    print(f"\nFIXED {fixes} Column(s) with clipBehavior!")
    print("This prevents ALL yellow/black overflow stripes.")
    print("\nNow press R in Flutter terminal for hot restart!")
else:
    print("No changes needed - all Columns already have clipBehavior.")
