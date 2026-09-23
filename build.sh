#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
APP="$ROOT/build/Rolecraft.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -module-cache-path "$ROOT/build/module-cache" -o "$APP/Contents/MacOS/Rolecraft" "$ROOT/Sources/Core.swift" "$ROOT/Sources/PDF.swift" "$ROOT/Sources/main.swift" -framework AppKit -framework WebKit -framework PDFKit -framework Vision -framework Security -framework CoreText
cp -R "$ROOT/Resources/." "$APP/Contents/Resources/"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
printf APPL\?\?\?\? > "$APP/Contents/PkgInfo"
codesign --force --deep --sign - "$APP"
printf '%s\n' "$APP"
