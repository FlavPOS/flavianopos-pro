#!/usr/bin/env python3
import os, re

HOME = os.path.expanduser("~")
FILES = [
    HOME + "/myapp/lib/screens/reports/sales_analytics_screen.dart",
    HOME + "/myapp/lib/screens/reports/sales_history_screen.dart",
    HOME + "/myapp/lib/screens/branches/branch_detail_screen.dart",
    HOME + "/myapp/lib/screens/dashboard_screen.dart",
]

for fpath in FILES:
    if not os.path.exists(fpath):
        print(f"SKIP: {fpath}")
        continue
    with open(fpath, "r") as f:
        original = f.read()
    content = original
    fname = os.path.basename(fpath)
    fixes = []

    # FIX 1: height: 34 -> 42 near filter chips
    lines = content.split("\n")
    new_lines = []
    for idx, line in enumerate(lines):
        if "height: 34" in line:
            ctx = "\n".join(lines[max(0,idx-15):min(len(lines),idx+15)])
            if any(k in ctx for k in ["FilterChip","ChoiceChip","Filter","ListView","filter"]):
                line = line.replace("height: 34", "height: 42")
                fixes.append(f"  L{idx+1}: height 34->42")
        if "height: 30" in line or "height: 32" in line:
            ctx = "\n".join(lines[max(0,idx-15):min(len(lines),idx+15)])
            if any(k in ctx for k in ["FilterChip","ChoiceChip","Filter","ListView","filter"]):
                line = line.replace("height: 30", "height: 42").replace("height: 32", "height: 42")
                fixes.append(f"  L{idx+1}: height->42")
        new_lines.append(line)
    content = "\n".join(new_lines)

    if content != original:
        with open(fpath, "w") as f:
            f.write(content)
        print(f"✅ FIXED: {fname}")
        for fx in fixes:
            print(fx)
    else:
        print(f"ℹ️  OK (no change): {fname}")

print("\n🎉 Done! Run: flutter run -d chrome")
