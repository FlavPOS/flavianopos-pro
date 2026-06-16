#!/usr/bin/env python3
import os

HOME = os.path.expanduser("~")
FPATH = os.path.join(HOME, "myapp/lib/screens/reports/sales_analytics_screen.dart")

with open(FPATH, "r", encoding="utf-8") as f:
    lines = f.readlines()

# STEP 1: Remove all clipBehavior lines we added (undo bad fix)
new_lines = []
removed = 0
for line in lines:
    if "clipBehavior: Clip.hardEdge," in line.strip():
        removed += 1
        continue
    new_lines.append(line)

print(f"Step 1: Removed {removed} bad clipBehavior lines")

# STEP 2: Fix the REAL issue - wrap "return Column(" with SingleChildScrollView
# Only for the top-level return Column( in _buildByItem, _buildByCategory, _buildTrends
# These are Columns that are TabBarView children and get squeezed
final_lines = []
i = 0
fixes = 0
while i < len(new_lines):
    line = new_lines[i]
    stripped = line.strip()

    # Match "return Column(" at function level (indented ~4 spaces)
    if stripped == "return Column(":
        indent = line[:len(line) - len(line.lstrip())]

        # Look ahead: does this Column have _miniCard or _buildColToggles?
        # These are the tab builder Columns that overflow
        lookahead = "".join(new_lines[i:min(len(new_lines), i+15)])
        is_tab_column = any(k in lookahead for k in ["_miniCard", "_buildColToggles", "_trendView"])

        if is_tab_column:
            # Find matching closing ");" for this Column
            depth = 0
            end_idx = None
            for j in range(i, len(new_lines)):
                for ch in new_lines[j]:
                    if ch == '(':
                        depth += 1
                    elif ch == ')':
                        depth -= 1
                        if depth == 0:
                            end_idx = j
                            break
                if end_idx is not None:
                    break

            if end_idx is not None:
                # Replace "return Column(" with "return SingleChildScrollView( child: Column("
                # And add closing ");" for SingleChildScrollView before the Column's closing
                final_lines.append(f"{indent}return SingleChildScrollView(\n")
                final_lines.append(f"{indent}  child: Column(\n")
                fixes += 1
                print(f"  Line {i+1}: Wrapped Column with SingleChildScrollView")
                i += 1
                continue

    final_lines.append(line)
    i += 1

if removed > 0 or fixes > 0:
    with open(FPATH, "w", encoding="utf-8") as f:
        f.writelines(final_lines)
    print(f"\nDone! Removed {removed} bad lines, applied {fixes} scroll fixes.")
    print("Press R in Flutter terminal for hot restart!")
else:
    print("No changes needed.")
