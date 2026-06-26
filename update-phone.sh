#!/bin/bash
APP_ID="1:339216262642:android:30e70624d1a1cb33f5f76b"
NOTES="${1:-New build from Firebase Studio}"

echo ""
echo "🔨 Building release APK... (this takes 3-5 minutes)"
echo ""
flutter build apk --release --dart-define=ENABLE_DEBUG_TOOLS=true

if [ ! -f build/app/outputs/flutter-apk/app-release.apk ]; then
  echo "❌ Build failed! APK not found."
  exit 1
fi

echo ""
echo "☁️ Uploading to Firebase App Distribution..."
echo ""
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app "$APP_ID" \
  --release-notes "$NOTES" \
  --groups "myphone"

echo ""
echo "✅ DONE! Check your phone notification 📱🔔"
echo ""
