#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
command -v flutter >/dev/null || { echo "Flutter nao encontrado no PATH."; exit 1; }
BACKUP="$(mktemp -d)"
cp -R lib "$BACKUP/lib"
cp pubspec.yaml "$BACKUP/pubspec.yaml"
[ -f .env ] && cp .env "$BACKUP/.env" || true
[ -f .env.example ] && cp .env.example "$BACKUP/.env.example" || true
[ -f android/app/src/main/AndroidManifest.xml ] && cp android/app/src/main/AndroidManifest.xml "$BACKUP/AndroidManifest.xml" || true
mkdir -p "$BACKUP/icons"
if [ -d android/app/src/main/res ]; then
  for d in android/app/src/main/res/mipmap*; do [ -d "$d" ] && cp -R "$d" "$BACKUP/icons/"; done
fi
rm -rf android
flutter create --platforms=android --org io.mvcode --project-name mv_biblioteca_webview .
rm -rf lib && cp -R "$BACKUP/lib" lib
cp "$BACKUP/pubspec.yaml" pubspec.yaml
[ -f "$BACKUP/.env" ] && cp "$BACKUP/.env" .env || true
[ -f "$BACKUP/.env.example" ] && cp "$BACKUP/.env.example" .env.example || true
[ -f "$BACKUP/AndroidManifest.xml" ] && cp "$BACKUP/AndroidManifest.xml" android/app/src/main/AndroidManifest.xml || true
if [ -d "$BACKUP/icons" ]; then
  for d in "$BACKUP"/icons/mipmap*; do
    [ -d "$d" ] || continue
    mkdir -p "android/app/src/main/res/$(basename "$d")"
    cp -R "$d"/* "android/app/src/main/res/$(basename "$d")/"
  done
fi
flutter clean
flutter pub get
echo "OK. Agora execute: flutter run"
