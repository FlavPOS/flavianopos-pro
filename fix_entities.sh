#!/bin/bash
count=0
find lib/ -name "*.dart" | while read file; do
  perl -pi -e 's/\x26gt;/\x3e/g; s/\x26lt;/\x3c/g; s/\x26amp;/\x26/g' "$file"
  count=$((count+1))
  echo "Fixed: $file"
done
echo "All .dart files processed!"

