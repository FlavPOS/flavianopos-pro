#!/bin/bash
for f in $(find lib/ -name "*.dart"); do
  sed -i 's/&gt;/>/g; s/&lt;/</g; s/&amp;/&/g' "$f"
done
echo "All done!"

